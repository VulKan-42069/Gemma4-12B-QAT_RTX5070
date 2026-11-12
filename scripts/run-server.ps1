# Default launcher. Same as serve-fast.ps1.

param(
    [int]$Ctx = 8192,
    [int]$Port = 8080,
    [int]$DraftN = 2,
    [switch]$NoMtp,
    [switch]$Ngram
)

$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'serve-fast.ps1') -Ctx $Ctx -Port $Port -DraftN $DraftN -NoMtp:$NoMtp -Ngram:$Ngram
