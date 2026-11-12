# Default-ish llama.cpp path: full GPU offload, no flash-attn, no quantized KV, no MTP.
# Used as the TPS comparison baseline.

param(
    [int]$Ctx = 8192,
    [int]$Port = 8080
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'env.ps1')
. (Join-Path $PSScriptRoot 'common.ps1')

$exe = Get-LlamaExe 'llama-server.exe'
$args = Get-DefaultServerArgs -Mode baseline -Ctx $Ctx -Port $Port

Write-Host "Baseline server: $exe"
Write-Host ($args -join ' ')
& $exe @args
