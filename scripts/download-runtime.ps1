# Download llama.cpp CUDA 13.3 Windows binaries + cudart into this project folder.
# Never uses winget. Never writes outside PROJECT_ROOT.

param(
    [string]$Tag = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'env.ps1')

if ($Tag) { $env:LLAMA_TAG = $Tag }
$tag = $env:LLAMA_TAG

$base = "https://github.com/ggml-org/llama.cpp/releases/download/$tag"
$binZipName = "llama-$tag-bin-win-cuda-13.3-x64.zip"
$cudartZipName = "cudart-llama-bin-win-cuda-13.3-x64.zip"

$dlDir = Join-Path $env:PROJECT_ROOT 'cache\downloads'
$binZip = Join-Path $dlDir $binZipName
$cudartZip = Join-Path $dlDir $cudartZipName
$dest = $env:LLAMA_BIN

function Invoke-ResumeDownload {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$OutFile
    )
    Write-Host "GET $Url"
    Write-Host " -> $OutFile"
    & curl.exe -L --fail --retry 5 --retry-all-errors -C - --output $OutFile $Url
    if ($LASTEXITCODE -ne 0) {
        throw "curl failed ($LASTEXITCODE) for $Url"
    }
}

Invoke-ResumeDownload -Url "$base/$binZipName" -OutFile $binZip
Invoke-ResumeDownload -Url "$base/$cudartZipName" -OutFile $cudartZip

Write-Host "Extracting into $dest"
if (-not (Test-Path -LiteralPath $dest)) {
    New-Item -ItemType Directory -Path $dest | Out-Null
}

& tar.exe -xf $binZip -C $dest
if ($LASTEXITCODE -ne 0) { throw "tar extract failed for $binZipName" }
& tar.exe -xf $cudartZip -C $dest
if ($LASTEXITCODE -ne 0) { throw "tar extract failed for $cudartZipName" }

$server = Get-ChildItem -LiteralPath $dest -Recurse -Filter 'llama-server.exe' | Select-Object -First 1
if (-not $server) {
    throw "llama-server.exe not found after extract"
}

$tagFile = Join-Path $dest 'VERSION.txt'
@"
tag=$tag
bin=$binZipName
cudart=$cudartZipName
server=$($server.FullName)
"@ | Set-Content -LiteralPath $tagFile -Encoding utf8

Write-Host "Runtime ready: $($server.FullName)"
