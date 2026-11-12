# llama-bench: prompt processing vs generation.
# MTP is a server-side speculative path, so llama-bench measures the
# dense decode ceiling (FA + q8 KV). Serve-fast is what adds MTP.

param(
    [ValidateSet('baseline', 'fast')]
    [string]$Mode = 'fast',
    [int]$Ctx = 8192
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'env.ps1')
. (Join-Path $PSScriptRoot 'common.ps1')

$exe = Get-LlamaExe 'llama-bench.exe'
$model = Get-ModelPath $env:MODEL_FILE
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$out = Join-Path $env:BENCH_DIR "llama-bench-$Mode-$stamp.txt"

$args = @(
    '-m', $model,
    '-ngl', '99',
    '-t', '8',
    '-p', '512',
    '-n', '256'
)

if ($Mode -eq 'fast') {
    $args += @(
        '-fa', 'on',
        '-ctk', 'q8_0',
        '-ctv', 'q8_0'
    )
} else {
    $args += @(
        '-fa', 'off'
    )
}

Write-Host "Bench $Mode : $exe"
Write-Host ($args -join ' ')
Write-Host "Log: $out"

& $exe @args 2>&1 | Tee-Object -FilePath $out
if ($LASTEXITCODE -ne 0) {
    throw "llama-bench failed ($LASTEXITCODE)"
}
