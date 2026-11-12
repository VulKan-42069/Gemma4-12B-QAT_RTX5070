# Hit a running llama-server and record prompt / decode tok/s from its timings.
# llama-bench cannot measure MTP; this is the MTP-aware path.

param(
    [string]$Url = 'http://127.0.0.1:8080',
    [int]$NPredict = 256,
    [int]$Rounds = 3,
    [string]$Label = 'server',
    [ValidateSet('short', 'code-edit')]
    [string]$PromptKind = 'short'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'env.ps1')

$promptShort = @'
Write a short, concrete explanation of how flash attention reduces memory traffic during transformer decode. Use plain language. Do not use a title.
'@

$promptCodeEdit = @'
You are editing an existing PowerShell launcher. Apply the requested change and output the FULL updated script. Copy unchanged lines exactly.

Requested change: add a -Verbose switch that prints the resolved llama-server.exe path before launching.

```powershell
param(
    [int]$Ctx = 8192,
    [int]$Port = 8080,
    [int]$DraftN = 2,
    [switch]$NoMtp
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'env.ps1')
. (Join-Path $PSScriptRoot 'common.ps1')

$exe = Get-LlamaExe 'llama-server.exe'
$args = Get-DefaultServerArgs -Mode fast -Ctx $Ctx -Port $Port -DraftN $DraftN -NoMtp:$NoMtp

Write-Host "Fast server: $exe"
Write-Host ($args -join ' ')
& $exe @args
```
'@

$prompt = if ($PromptKind -eq 'code-edit') { $promptCodeEdit } else { $promptShort }

$body = @{
    model            = $env:ALIAS
    messages         = @(
        @{ role = 'user'; content = $prompt }
    )
    temperature      = 1.0
    top_p            = 0.95
    top_k            = 64
    max_tokens       = $NPredict
    stream           = $false
    chat_template_kwargs = @{ enable_thinking = $false }
} | ConvertTo-Json -Depth 6

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$out = Join-Path $env:BENCH_DIR "server-$Label-$stamp.txt"

$health = $null
for ($i = 0; $i -lt 60; $i++) {
    try {
        $health = Invoke-RestMethod -Uri "$Url/health" -TimeoutSec 2
        break
    } catch {
        Start-Sleep -Seconds 2
    }
}
if (-not $health) {
    throw "llama-server did not become healthy at $Url/health"
}

$lines = @()
$pp = New-Object System.Collections.Generic.List[double]
$tg = New-Object System.Collections.Generic.List[double]

for ($r = 1; $r -le $Rounds; $r++) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $resp = Invoke-RestMethod -Method Post -Uri "$Url/v1/chat/completions" -ContentType 'application/json' -Body $body -TimeoutSec 300
    $sw.Stop()
    $timings = $resp.timings
    $ppSec = [double]$timings.prompt_per_second
    $tgSec = [double]$timings.predicted_per_second
    $pp.Add($ppSec) | Out-Null
    $tg.Add($tgSec) | Out-Null
    $row = "round=$r wall_s={0:N2} prompt_n=$($timings.prompt_n) pp={1:N2} predicted_n=$($timings.predicted_n) tg={2:N2} draft_n=$($timings.draft_n) draft_accepted=$($timings.draft_n_accepted)" -f ($sw.Elapsed.TotalSeconds), $ppSec, $tgSec
    Write-Host $row
    $lines += $row
}

function Get-Mean([double[]]$xs) {
    if ($xs.Count -eq 0) { return 0 }
    ($xs | Measure-Object -Average).Average
}

$summary = "aggregate pp={0:N2} tg={1:N2} rounds=$Rounds" -f (Get-Mean $pp.ToArray()), (Get-Mean $tg.ToArray())
Write-Host $summary
$lines += $summary
$lines | Set-Content -LiteralPath $out -Encoding utf8
Write-Host "Log: $out"
