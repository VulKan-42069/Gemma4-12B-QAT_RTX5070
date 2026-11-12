# Gemma 4 12B QAT · Fast Local Inference on an RTX 5070

![llama.cpp](https://img.shields.io/badge/llama.cpp-b10821-3b82f6)
![CUDA](https://img.shields.io/badge/CUDA-13.3-10b981)
![GPU](https://img.shields.io/badge/GPU-RTX%205070%20(12GB)-8b5cf6)
![Format](https://img.shields.io/badge/format-GGUF-ef4444)
![Quant](https://img.shields.io/badge/quant-UD--Q4_K_XL%20QAT-f59e0b)
![MTP](https://img.shields.io/badge/MTP-Q4_0%20n%3D2-22c55e)

A practical, fully-tuned setup for running **Google Gemma 4 12B IT QAT** locally on an **NVIDIA GeForce RTX 5070 (12 GB, Blackwell)** using **llama.cpp b10821 (CUDA 13.3)** and Unsloth's **UD-Q4_K_XL** QAT GGUF, plus Gemma 4 **MTP**.

**Idle 8192-context result on this GPU:**

| Path | tok/s |
|---|---|
| Dense decode (no MTP) | ~70 |
| Short chat with MTP | **~124** |
| Long UI generation with MTP | **~146** |
| Prompt processing (pp512) | **~3,450** |

This repo is meant to be read as a guide: not just *what* changed, but *why*. Every flag, quant choice, and tradeoff is explained below.

All artifacts stay inside this project folder. Nothing is written to the system drive.

## Table of Contents

1. [Why llama.cpp (not Ollama)](#why-llamacpp-not-ollama)
2. [Hardware requirements](#hardware-requirements)
3. [Model and quantization choice](#model-and-quantization-choice)
4. [Setup](#setup)
5. [Performance tuning](#performance-tuning)
6. [Performance results](#performance-results)
7. [What we tried that did not win](#what-we-tried-that-did-not-win)
8. [Findings and takeaways](#findings-and-takeaways)
9. [Data locality](#data-locality)
10. [Credits](#credits)

## Why llama.cpp (not Ollama)

Ollama is a convenient wrapper around llama.cpp, but it freezes the recipe:

- You cannot pin Unsloth's QAT-recovered `UD-Q4_K_XL` plus the matching MTP drafter with custom `--spec-type draft-mtp` knobs.
- You cannot keep caches, GGUFs, and CUDA JIT files inside one project folder.
- Gemma 4's vision `mmproj` split is the same class of packaging pain that already blocked Qwen3.5 in Ollama.

Running llama.cpp directly gives you:

- Current CUDA kernels for Blackwell (compute capability 12.0)
- Full control over flash attention, quantized KV cache, MTP, context, and sampling
- An OpenAI-compatible `llama-server` at `http://127.0.0.1:8080/v1`

## Hardware requirements

| Component | Minimum | This setup |
|---|---|---|
| GPU | NVIDIA with enough VRAM for 4-bit 12B + MTP | **RTX 5070, 12 GB GDDR7, SM 12.0** |
| Driver | Recent Game Ready / Studio | 591.86, CUDA runtime 13.1 |
| RAM | Enough to host the GGUF on disk | Not the bottleneck when fully offloaded |
| Disk | ~8 GB for the GGUFs, plus ~1 GB runtime | All data confined to this project folder |

A dense 12B QAT 4-bit (6.26 GiB on disk) plus a 0.24 GiB MTP head fits in 12 GB with an 8192 quantized KV cache. Measured VRAM with the daily driver: **7913 MiB / 12227 MiB**.

Windows as the display GPU burns ~0.5-2 GB when idle. Close extra GPU apps before serving. Default context is **8192**. Drop to 4096 only if something else is sitting on the card. Do not start at 128k context on this card.

## Model and quantization choice

| File | Size | Role |
|---|---|---|
| `gemma-4-12B-it-qat-UD-Q4_K_XL.gguf` | 6.26 GiB | Target. Unsloth dynamic 4-bit recovered from Google QAT. |
| `mtp-gemma-4-12B-it-Q4_0.gguf` | 0.24 GiB | **Default MTP assistant.** Daily driver. |
| `mtp-gemma-4-12B-it-Q8_0.gguf` | 0.43 GiB | Optional. Fails on b10821; loads on b10822 but chat is slower. |
| Official `Q4_0` QAT GGUF | ~7.0 GB | Avoid. Naive Q4_0 conversion of QAT is less accurate and slightly larger. |

**Why UD-Q4_K_XL:** Google trained this checkpoint quantization-aware. Unsloth's dynamic quant matches that lattice far better than a naive llama.cpp `Q4_0` dump (12B top-1 ~89% vs ~74% in Unsloth's KLD tables) and is ~200 MB smaller.

**Why not Q8 on the 12B weights:** 12B at 8-bit is ~14 GB. It will not stay on a 12 GB card. Partial CPU offload destroys decode TPS.

**Why MTP Q4, not MTP Q8:** On llama.cpp b10821 the Unsloth Q8 assistant crashed at load (`invalid vector subscript`). On b10822 it loads, but short-chat TPS dropped. The Q4_0 assistant is the measured 124 / 146 path.

**Why MTP here, unlike Qwen3.5-9B on this same GPU:** A separate 2B draft model did not help Qwen3.5-9B because that run was already ~80% of the bandwidth ceiling and the draft added its own weight traffic. Gemma 4 ships a dedicated MTP head trained for this QAT checkpoint. llama.cpp verifies several predicted tokens in one target forward (`--spec-type draft-mtp`). That is the entire 70 -> 124 t/s jump.

## Setup

Everything below is launched from this folder. Scripts force caches onto `cache\`.

```powershell
# 1. llama.cpp CUDA 13.3 Windows binaries (b10821)
.\scripts\download-runtime.ps1

# 2. QAT target + MTP drafter
.\scripts\download-models.ps1

# 3. Serve (tuned). Default: 8192 ctx, FA on, q8 KV, MTP Q4, draft-n 2.
.\scripts\serve-fast.ps1
```

Then open http://127.0.0.1:8080 or hit `http://127.0.0.1:8080/v1`.

Useful variants:

```powershell
.\scripts\serve-fast.ps1                  # daily driver (~124-146 t/s)
.\scripts\serve-fast.ps1 -Ctx 4096        # if VRAM is already eaten
.\scripts\serve-fast.ps1 -NoMtp           # dense decode only (~70 t/s)
.\scripts\serve-fast.ps1 -Ngram           # MTP + ngram-mod; code-copy spikes, chat does not
.\scripts\serve-baseline.ps1              # FA off, f16 KV, no MTP
.\scripts\run-server.ps1                  # alias of serve-fast.ps1
```

MTP-aware chat bench against a running server:

```powershell
.\scripts\bench-server.ps1 -Label fast-mtp
.\scripts\bench-server.ps1 -Label code -PromptKind code-edit
```

Dense decode bench (no MTP; MTP is server-side):

```powershell
.\scripts\bench.ps1 -Mode baseline
.\scripts\bench.ps1 -Mode fast
```

Sampling follows Google's Gemma 4 defaults: `temperature=1.0`, `top_p=0.95`, `top_k=64`.

Disable thinking:

```powershell
# extra arg if you launch llama-server by hand
--chat-template-kwargs "{\"enable_thinking\":false}"
```

## Performance tuning

These are the flags `serve-fast.ps1` actually passes, and why:

| Flag | Purpose | Why on this 5070 |
|---|---|---|
| `-ngl 99` | Offload every layer | CPU bridge is the #1 TPS killer |
| `-fa on` | Flash attention | Prompt-processing win + cheaper KV. Idle pp512 3159 -> 3449 |
| `-ctk q8_0 -ctv q8_0` | Quantized KV cache | Same VRAM holds 8192 ctx with MTP |
| `-c 8192` | Context | Fits with MTP on an idle 12 GB 5070 (~7.9 GB used). 128k will OOM |
| `-t 8` | Threads | Too many threads slow GPU inference |
| `-b 2048 -ub 512` | Batch / ubatch | Prompt processing batching |
| `-md` + `-ngld 99` + `--spec-type draft-mtp` | Gemma 4 MTP | The actual TPS multiplier: 70 -> 124 t/s |
| `--spec-draft-n-max 2` | Draft depth | n=4 did not beat n=2 on this 5070 |
| `--jinja` | Chat template | Gemma 4 roles + thinking control |
| `--temp 1.0 --top-p 0.95 --top-k 64` | Sampling | Google defaults |
| `--alias Gemma-4-12B-QAT` | Server model id | What clients see in `/v1/models` |

If VRAM is the wall, drop `-c` to 4096 or `-ctv q4_0` before touching the weights. Never RAM-offload the 12B if you care about tokens/s.

## Performance results

Measured on this RTX 5070 (driver 591.86, llama.cpp **b10821** CUDA 13.3), Gemma 4 12B QAT `UD-Q4_K_XL`. GPU idle (~580 MiB display, 2% util) unless noted.

**Server path (the number that matters):**

| Recipe | Ctx | Decode tok/s | Notes |
|---|---|---|---|
| Fast, no MTP (`-fa on -ctk/-ctv q8_0`) | 8192 | **70.2** | Dense decode ceiling on this card |
| Fast + MTP Q4, `--spec-draft-n-max 2` | 8192 | **123.9** | ~1.77x. Draft accept ~58% |
| Fast + MTP Q4, n=2 | 4096 | 124.3 | Same speed. Ctx does not buy tok/s |
| Fast + MTP Q4, n=4 | 4096 | 123.6 | No gain. Keep n=2 |

VRAM with 8192 + MTP Q4 on b10821: **7913 MiB / 12227 MiB**.

Long llama.cpp-webui generations on the same 8192 + MTP recipe have reached **~146 t/s** (example: 7,518 tokens in 51 s). That is not a contradiction of the 124 t/s short-turn average. MTP acceptance is content-dependent: a long, structured completion lets the drafter stay locked in, so the same flags run hotter than a 200-token chat bench.

**`llama-bench` idle (no MTP):**

| Metric | Baseline (`-fa off`) | Fast (`-fa on`, q8 KV) |
|---|---|---|
| Prompt processing (pp512) | 3159 ± 69 t/s | **3449 ± 90 t/s** |
| Generation (tg256) | 71.9 ± 0.2 t/s | **72.4 ± 0.1 t/s** |

First `llama-bench` pass (GPU ~65% busy from other apps) was 39 t/s / 1289 pp. That was contention, not the model. Idle numbers above match the no-MTP server (~70 t/s).

Naive bandwidth ceiling for 6.26 GiB weights on ~672 GB/s is about 100 tok/s without MTP. At 72 t/s dense you are ~70% of that roof. MTP beats the roof because several tokens ride on one target forward.

Raw logs live in `benches\`.

## What we tried that did not win

These were run on the same GPU after the daily driver was already at 124 / 146. None of them replace `.\scripts\serve-fast.ps1` for chat.

| Experiment | Short chat t/s | Code-edit t/s | Verdict |
|---|---|---|---|
| MTP Q4 only (b10821) | 117–124 | **154** | **Daily driver. Keep this.** |
| MTP Q4 + `ngram-mod` | 119 | 246 first turn, then cache-hit 500–1000 | Chat unchanged. Spikes only when the model reprints the prompt. Opt-in: `-Ngram`. |
| llama.cpp b10822 + MTP **Q8** | **114** | 154 | Q8 loads on b10822, uses more VRAM (~8.5 GB), chat is slower. Do not switch. |

Ngram-mod first-turn 246 t/s is real: the model is mostly reprinting the script you pasted. Rounds 2–3 of that bench were KV-cache copies of the same completion, so 500–1000 t/s is not a chat number.

There is no remaining flag that turns 146 into 200 on this 12 GB 5070 without a smaller model or a fatter memory bus.

## Findings and takeaways

These were verified directly on the RTX 5070:

- **MTP is the whole speed story on this card.** Idle 8192 ctx, same FA + q8 KV: **70 t/s** without MTP, **124 t/s** short-turn average with Unsloth's Q4 assistant, and **~146 t/s** on long UI generations. That is the opposite of Qwen3.5-9B on this GPU, where a separate 2B draft model did nothing.
- **8192 vs 4096 does not change decode TPS.** MTP was 123.9 t/s at 8k and 124.3 t/s at 4k. 8k just spends ~300 extra MiB.
- **Use the Q4 MTP file, not Q8.** On b10821, Q8 failed with `invalid vector subscript`. On b10822 it loads, but short-chat TPS dropped 117 -> 114. Stay on Q4 + b10821.
- **Ngram-mod is not a free chat upgrade.** Stacked on MTP it left short-chat TPS flat (~119 vs ~117) and spiked only when the prompt was "reprint this script with a tiny change." Opt-in via `-Ngram`, not the default.
- **`--spec-draft-n-max 2` is enough.** n=4 drafted more tokens and accepted a similar count. TPS did not move.
- **Flash attention is a prompt-processing win on an idle card, not a decode win.** Idle pp512: 3159 -> 3449. Idle tg256: 71.9 -> 72.4. Serve-fast still keeps FA on for KV headroom.
- **Close games / other AI apps first.** A contended first pass printed 39 t/s. Idle `llama-bench` is 72 t/s, matching the no-MTP server.
- **Thinking mode changes time-to-answer, not raw tok/s.** Launchers pass Google sampling (`temp 1.0 / top_p 0.95 / top_k 64`). Disable thinking with `--chat-template-kwargs "{\"enable_thinking\":false}"`.
- **This card is done.** Dense decode is already ~70% of the bandwidth roof. MTP already cheated past that roof. Next real jump is a smaller model or a fatter GPU.

## Data locality

`scripts\env.ps1` redirects:

- `HF_HOME`, `HF_HUB_CACHE`, `HUGGINGFACE_HUB_CACHE`
- `LLAMA_CACHE`
- `TEMP` / `TMP` / `TMPDIR`
- `CUDA_CACHE_PATH`
- `PIP_CACHE_DIR`, `XDG_CACHE_HOME`

into `cache\` under this project. Downloads use `curl -o` into `models\` and `llama.cpp\`. Do not use `llama-server -hf ...` or `winget install llama.cpp`; those dump files onto the user profile.

Installed toolchains (Git, CMake, Visual Studio, the CUDA toolkit) stay on their install drives. They are read, never used as output.

Layout:

```
Gemma4-12B-QAT_RTX5070\
  llama.cpp\            b10821 CUDA 13.3 binaries + cudart (daily driver)
  llama.cpp-b10822\     optional newer binary used only for the Q8 MTP experiment
  models\               UD-Q4_K_XL target + MTP GGUFs
  scripts\              env, download, serve, bench
  cache\                HF / llama / CUDA / TEMP (local only)
  logs\                 server stdout/stderr
  benches\              llama-bench + server TPS logs
  README.md
```

## Credits

- [llama.cpp](https://github.com/ggml-org/llama.cpp) by ggml-org (b10821 daily driver, b10822 Q8 experiment)
- [Gemma 4 12B IT QAT GGUF](https://huggingface.co/unsloth/gemma-4-12B-it-qat-GGUF) by Unsloth
- Gemma 4 by Google DeepMind
