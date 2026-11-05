# rocm-stack

A suite of shell scripts for **Debian** to install **ROCm**, **ComfyUI**, and **llama.cpp** on `gfx1151` (Strix Halo APUs) and `gfx1201` (Radeon 9070 XT / R9700) targets.

The scripts are designed to be run in order: install the ROCm base, then bring up each application. Both ComfyUI and llama.cpp are managed as long-running services via [PM2](https://pm2.keymetrics.io/) so they can be started, stopped, logged, and kept alive.

> **Note:** This README was written by AI. The scripts themselves were hand-written and tested.

---

## Repository layout

| File | Purpose |
|------|---------|
| `rocm.sh` | Installs / checks the ROCm base (the shared dependency). |
| `comfyui.sh` | Clones, builds, and runs **ComfyUI** (ROCm torch backend). |
| `llamacpp.sh` | Clones, builds, and runs **llama.cpp** `llama-server`. |
| `daemon.sh` | PM2 helpers shared by the app scripts (`--start`, `--stop`, `--logs`). |
| `options.sh-example` | Template for your local `options.sh` (versions, GPU target, env vars). |
| `models.ini-example` | Template for llama.cpp's `models.ini` (model presets). |
| `config.json-example` | Template for llama.cpp's `config.json` (webui / MCP settings). |

> `options.sh`, `models.ini`, and `config.json` are git-ignored — they are your personal, local configuration.

---

## Prerequisites

- **Debian** (the ROCm repo target in the scripts is `debian13`).
- **`root`** (or `sudo`) for `apt` operations and writing to `/opt`.
- **`git`**, `wget`, `cmake`, `python3`, `node`/`npm` available (most are pulled in by the scripts automatically).
- An AMD GPU supported by ROCm (`gfx1151` or `gfx1201`).

---

## Step 0 — Create your `options.sh`

Every script sources `./options.sh-example` **and** `./options.sh`. The example is a starting point with a 5-second pause and a reminder comment, so make a real copy and edit it:

```bash
cp options.sh-example options.sh
```

Then edit `options.sh` and set the values for your hardware:

```bash
# 10.0 or 10.1
export ROCM_VERSION="10.1"

# gfx1201 = Radeon 9070 XT and R9700
# gfx1151 = Strix Halo APUs
export AMD_GPU="gfx1151"

export HSA_OVERRIDE_GFX_VERSION=11.5.1
```

Key variables:

| Variable | Meaning |
|----------|---------|
| `ROCM_VERSION` | ROCm release to install (`10.0` or `10.1`). |
| `AMD_GPU` | GPU target: `gfx1151` (Strix Halo APUs) or `gfx1201` (Radeon 9070 XT / R9700). |
| `HSA_OVERRIDE_GFX_VERSION` | GFX override string matching your target (e.g. `11.5.1`). |
| `LD_LIBRARY_PATH` | Points at `/opt/rocm/core-${ROCM_VERSION}/lib` so the runtime finds ROCm libs. |
| `HIPCXX` / `HIP_PATH` | Locate the HIP compiler / runtime via `hipconfig`. |

> **Remove the `sleep 5` / reminder line** in your `options.sh` once it's set up.

---

## Step 1 — Install ROCm (the shared base)

```bash
./rocm.sh --install
```

This:
1. Adds the official **ROCm 10.x** apt repo (`amdrocm-stable`, `debian13`) with its GPG key.
2. Installs `amdrocm-core-sdk${ROCM_VERSION}-${AMD_GPU}`, `amdrocm-core-dev${ROCM_VERSION}-${AMD_GPU}`, and `amdrocm${ROCM_VERSION}-${AMD_GPU}`.

Verify the install:

```bash
./rocm.sh --check
```

`--check` exits `0` if `/opt/rocm/core-${ROCM_VERSION}` exists, and tells you to run `./rocm.sh --install` if not. **Both `comfyui.sh` and `llamacpp.sh` run this check first** and abort if ROCm isn't present, so do this step before anything else.

---

## Step 2 — ComfyUI

```bash
./comfyui.sh
```

First run:
1. Confirms ROCm is installed (`./rocm.sh --check`).
2. Clones [`Comfy-Org/ComfyUI`](https://github.com/Comfy-Org/ComfyUI) (skipped if the `ComfyUI/` dir already exists).
3. Creates a fresh Python `venv` (`venv/`) and installs the **ROCm builds of PyTorch** (`torch`, `torchvision`, `torchaudio` from the AMD `whl-next` index) plus `requirements.txt`.
4. Starts the ComfyUI server.

It runs on **port 8188** with these flags:

```
--listen --port 8188 --gpu-only --disable-smart-memory --disable-mmap --enable-manager --user-directory user
```

### Updating

```bash
./comfyui.sh --update
```

Pulls the latest ComfyUI, rebuilds the venv, and refreshes the ROCm torch packages, then exits (doesn't start the server).

### Running as a daemon (PM2)

```bash
./comfyui.sh --start   # start + tail logs
./comfyui.sh --stop    # stop
./comfyui.sh --logs    # view logs
```

`daemon.sh` installs PM2 automatically if it isn't present (installs `nodejs`, `npm`, `n`, and `pm2`, then runs `pm2 startup` + `pm2 save --force` so it survives reboots).

---

## Step 3 — llama.cpp

```bash
./llamacpp.sh
```

First run:
1. Confirms ROCm is installed.
2. Installs the build dependencies (compiler toolchain, Vulkan, HIP, `ninja`, `python3`, etc.).
3. Clones [`ggml-org/llama.cpp`](https://github.com/ggml-org/llama.cpp).
4. Builds the webui (`tools/ui` → `npm install && npm run build`).
5. Configures CMake for **ROCm/HIP** (`-DGGML_HIP=ON`, `-DAMD_GPU_TARGETS=${AMD_GPU}`) and compiles with 8 parallel jobs.
6. Creates `models.ini` and `config.json` from the `-example` templates if they don't already exist.
7. Starts `llama-server`.

It runs on **port 9931**:

```
llama-server --host 0.0.0.0 --port 9931 \
    --webui-mcp-proxy \
    --webui-config-file "config.json" \
    --models-preset "models.ini" \
    --models-max 1 \
    --device "${USE_DEVICE}" \
    --spec-draft-device "${MTP_DEVICE}"
```

### Choosing the backend

By default it runs on **ROCm**. To run on **Vulkan** instead:

```bash
./llamacpp.sh --vulkan
```

### Updating / rebuilding

```bash
./llamacpp.sh --update    # pull + rebuild
./llamacpp.sh --rebuild   # rebuild from source
```

Both stop after building (they don't start the server).

### Running as a daemon (PM2)

```bash
./llamacpp.sh --start
./llamacpp.sh --stop
./llamacpp.sh --logs
```

---

## Models & configuration (llama.cpp)

### `models.ini`

Copied from `models.ini-example` on first run. It defines **global settings** and **per-model presets**:

```ini
[*]                       # applied to all routed models
n-gpu-layers = -1
ctx-size = 262144
cache-type-k = q4_1
cache-type-v = q4_1
flash-attn = on
...

[qwen3.8-27b]             # a named preset
model = models/...gguf
mmproj = models/mmproj-...gguf
spec-type = draft-mtp
load-on-startup = false
```

Edit `models.ini` to point at your own `.gguf` files and to set which model loads on startup (`load-on-startup = true`).

### `config.json`

Copied from `config.json-example` on first run. It controls the webui / MCP behaviour (MCP server endpoint, agentic turn limits, code block display, etc.). Edit to taste.

---

## Quick reference

| Command | What it does |
|---------|--------------|
| `./rocm.sh --install` | Install the ROCm base. |
| `./rocm.sh --check` | Verify ROCm is installed (exit 0 = OK). |
| `./comfyui.sh` | Install (first time) + run ComfyUI on port 8188. |
| `./comfyui.sh --update` | Update ComfyUI + ROCm torch, no server start. |
| `./comfyui.sh --start` / `--stop` / `--logs` | PM2 daemon control. |
| `./llamacpp.sh` | Install (first time) + run llama-server on port 9931. |
| `./llamacpp.sh --vulkan` | Run llama.cpp on Vulkan instead of ROCm. |
| `./llamacpp.sh --update` / `--rebuild` | Update / rebuild, no server start. |
| `./llamacpp.sh --start` / `--stop` / `--logs` | PM2 daemon control. |

---

## Notes

- **Order matters.** Always run `./rocm.sh --install` first; the app scripts depend on it and will abort if `./rocm.sh --check` fails.
- **PM2** is installed automatically on the first `--start`. It is registered to start on boot (`pm2 startup`).
- The `ComfyUI/`, `llama.cpp/` directories and your `options.sh` / `models.ini` / `config.json` are git-ignored, so they won't show up as changes in `git status`.
- If you switch GPU targets (e.g. from `gfx1151` to `gfx1201`), update `AMD_GPU` in `options.sh` and re-run `./rocm.sh --install`, then `--update`/`--rebuild` the apps.
