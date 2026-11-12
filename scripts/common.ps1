# Shared helpers. Always dot-source env.ps1 first.

function Get-LlamaExe {
    param(
        [Parameter(Mandatory = $true)][string]$Name
    )
    $root = $env:LLAMA_BIN
    if (-not (Test-Path -LiteralPath $root)) {
        throw "llama.cpp runtime folder missing: $root  (run scripts\download-runtime.ps1)"
    }
    $hit = Get-ChildItem -LiteralPath $root -Recurse -Filter $Name -File -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $hit) {
        throw "$Name not found under $root  (run scripts\download-runtime.ps1)"
    }
    return $hit.FullName
}

function Get-ModelPath {
    param(
        [Parameter(Mandatory = $true)][string]$FileName
    )
    $path = Join-Path $env:MODELS_DIR $FileName
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Model missing: $path  (run scripts\download-models.ps1)"
    }
    return $path
}

function Get-DefaultServerArgs {
    param(
        [ValidateSet('baseline', 'fast')]
        [string]$Mode = 'fast',
        [int]$Ctx = 8192,
        [int]$Port = 8080,
        [int]$DraftN = 2,
        [switch]$NoMtp,
        [switch]$Ngram
    )

    $model = Get-ModelPath $env:MODEL_FILE
    $args = @(
        '-m', $model,
        '-ngl', '99',
        '-c', "$Ctx",
        '-t', '8',
        '--host', '127.0.0.1',
        '--port', "$Port",
        '--alias', $env:ALIAS,
        '--temp', '1.0',
        '--top-p', '0.95',
        '--top-k', '64',
        '--parallel', '1',
        '--jinja'
    )

    if ($Mode -eq 'fast') {
        $args += @(
            '-fa', 'on',
            '-ctk', 'q8_0',
            '-ctv', 'q8_0',
            '-b', '2048',
            '-ub', '512'
        )
        if (-not $NoMtp) {
            $mtp = Get-ModelPath $env:MTP_FILE
            $specType = if ($Ngram) { 'draft-mtp,ngram-mod' } else { 'draft-mtp' }
            $args += @(
                '-md', $mtp,
                '-ngld', '99',
                '--spec-type', $specType,
                '--spec-draft-n-max', "$DraftN"
            )
        }
    }

    return $args
}
