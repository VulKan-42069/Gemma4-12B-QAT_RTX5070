# Isolate every cache this project might touch into this folder.
# Dot-source before any download, extract, or llama.cpp launch.
# Installed toolchains (Git, CMake, VS, CUDA) stay where they are; generated data does not.

$ErrorActionPreference = 'Stop'

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

$script:CacheRoot = Join-Path $ProjectRoot 'cache'
$script:Dirs = @(
    (Join-Path $ProjectRoot 'models'),
    (Join-Path $ProjectRoot 'llama.cpp'),
    (Join-Path $ProjectRoot 'logs'),
    (Join-Path $ProjectRoot 'benches'),
    (Join-Path $CacheRoot 'hf'),
    (Join-Path $CacheRoot 'hf\hub'),
    (Join-Path $CacheRoot 'llama'),
    (Join-Path $CacheRoot 'tmp'),
    (Join-Path $CacheRoot 'cuda'),
    (Join-Path $CacheRoot 'pip'),
    (Join-Path $CacheRoot 'xdg'),
    (Join-Path $CacheRoot 'downloads')
)

foreach ($d in $script:Dirs) {
    if (-not (Test-Path -LiteralPath $d)) {
        New-Item -ItemType Directory -Path $d | Out-Null
    }
}

$env:PROJECT_ROOT = $ProjectRoot

# Hugging Face
$env:HF_HOME = Join-Path $CacheRoot 'hf'
$env:HUGGINGFACE_HUB_CACHE = Join-Path $CacheRoot 'hf\hub'
$env:HF_HUB_CACHE = Join-Path $CacheRoot 'hf\hub'
$env:TRANSFORMERS_CACHE = Join-Path $CacheRoot 'hf\transformers'
$env:HF_HUB_DISABLE_SYMLINKS = '1'
$env:HF_HUB_OFFLINE = $env:HF_HUB_OFFLINE

# llama.cpp
$env:LLAMA_CACHE = Join-Path $CacheRoot 'llama'

# Generic caches
$env:XDG_CACHE_HOME = Join-Path $CacheRoot 'xdg'
$env:PIP_CACHE_DIR = Join-Path $CacheRoot 'pip'
$env:PIP_DISABLE_PIP_VERSION_CHECK = '1'

# CUDA kernel JIT cache
$env:CUDA_CACHE_PATH = Join-Path $CacheRoot 'cuda'
$env:CUDA_CACHE_MAXSIZE = '2147483648'

# Temp for curl/tar/cl/nvcc spawned by *this* process
$tmp = Join-Path $CacheRoot 'tmp'
$env:TEMP = $tmp
$env:TMP = $tmp
$env:TMPDIR = $tmp

# Do not let huggingface-cli / llama -hf dump into the user profile.
$env:XDG_CONFIG_HOME = Join-Path $CacheRoot 'xdg'

$env:LLAMA_BIN = Join-Path $ProjectRoot 'llama.cpp'
$env:MODELS_DIR = Join-Path $ProjectRoot 'models'
$env:LOGS_DIR = Join-Path $ProjectRoot 'logs'
$env:BENCH_DIR = Join-Path $ProjectRoot 'benches'

# Pinned artifacts
$env:LLAMA_TAG = 'b10821'
$env:MODEL_FILE = 'gemma-4-12B-it-qat-UD-Q4_K_XL.gguf'
# Q8_0 MTP failed to load on llama.cpp b10821 (invalid vector subscript).
# Unsloth Q4_0 assistant loads and is the measured fast path.
$env:MTP_FILE = 'mtp-gemma-4-12B-it-Q4_0.gguf'
$env:ALIAS = 'Gemma-4-12B-QAT'
