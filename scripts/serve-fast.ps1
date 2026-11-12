# Tuned path for RTX 5070: flash-attn, quantized KV, Gemma 4 MTP.
# MTP is kept only if it actually wins the bench. Disable with -NoMtp.

param(
    [int]$Ctx = 8192,
    [int]$Port = 8080,
    [int]$DraftN = 2,
    [switch]$NoMtp,
    [switch]$Ngram
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'env.ps1')
. (Join-Path $PSScriptRoot 'common.ps1')

$exe = Get-LlamaExe 'llama-server.exe'
$args = Get-DefaultServerArgs -Mode fast -Ctx $Ctx -Port $Port -DraftN $DraftN -NoMtp:$NoMtp -Ngram:$Ngram

Write-Host "Fast server: $exe"
Write-Host ($args -join ' ')
& $exe @args
