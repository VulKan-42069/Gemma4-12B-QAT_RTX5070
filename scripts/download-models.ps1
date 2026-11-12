# Download Gemma 4 12B QAT GGUF + MTP drafter into models\.
# Direct HTTPS into this folder. No `llama-server -hf`. No C: hub cache.

param(
    [switch]$SkipMtp
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'env.ps1')

$repo = 'https://huggingface.co/unsloth/gemma-4-12B-it-qat-GGUF/resolve/main'
$models = $env:MODELS_DIR

$files = @(
    @{
        Name = $env:MODEL_FILE
        Url  = "$repo/$($env:MODEL_FILE)"
    }
)

if (-not $SkipMtp) {
    $files += @{
        Name = $env:MTP_FILE
        Url  = "$repo/MTP/$($env:MTP_FILE)"
    }
    # Keep Q8 around as an optional extra; b10821 failed to load it.
    $files += @{
        Name = 'mtp-gemma-4-12B-it-Q8_0.gguf'
        Url  = "$repo/MTP/mtp-gemma-4-12B-it-Q8_0.gguf"
    }
}

foreach ($f in $files) {
    $out = Join-Path $models $f.Name
    Write-Host "GET $($f.Url)"
    Write-Host " -> $out"
    & curl.exe -L --fail --retry 5 --retry-all-errors -C - --output $out $f.Url
    if ($LASTEXITCODE -ne 0) {
        throw "curl failed ($LASTEXITCODE) for $($f.Url)"
    }
    $item = Get-Item -LiteralPath $out
    Write-Host ("OK {0:N2} GB  {1}" -f ($item.Length / 1GB), $item.Name)
}

Write-Host "Models ready in $models"
