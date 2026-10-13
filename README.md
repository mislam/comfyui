# ComfyUI (Docker)

Docker Compose setup for [ComfyUI](https://github.com/Comfy-Org/ComfyUI) on a Linux host with an NVIDIA GPU. The app runs in one container; checkpoints, uploads, and PNGs live under `./data` on the host (nothing is installed into the host Python environment).

## Prerequisites

- Docker Engine with Compose v2
- NVIDIA driver and [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)
- Disk and VRAM for the models you use ([Model](#model))

On cards with limited VRAM, you can raise `VRAM_HEADROOM` so dynamic VRAM leaves room for the OS and other GPU processes ([Sharing the GPU](#sharing-the-gpu)).

## Quick start

On the machine that will run ComfyUI:

```bash
git clone git@github.com:mislam/comfyui.git
cd comfyui
mkdir -p data
docker compose up -d --build
```

The UI is published on **localhost only** (`127.0.0.1:8188` in `compose.yaml`). To use it from another machine, forward the port over SSH:

```bash
ssh -L 8188:127.0.0.1:8188 user@your-server
```

Open `http://127.0.0.1:8188`.

The first build pulls the PyTorch CUDA base image and clones ComfyUI `v0.39.2`. Later starts reuse the image. Model directories start empty; add weights when you want them ([below](#model)).

Downloads from the ComfyUI page land where **your browser** runs. Put weight files on the **server** under `data/models/` (use the download script on the host).

### Sync to a remote host

To copy the project without sending `data/` (keep weights on the server):

```bash
rsync -a --exclude data ./ user@your-server:~/comfyui/
```

On the server:

```bash
cd ~/comfyui
mkdir -p data
docker compose up -d --build
```

If `data/` was created as root, fix ownership: `sudo chown -R "$USER" data`.

## Container behavior

| Setting | Role |
| -------- | ----- |
| `./data` → `/data` | Models, input, output, temp, user state |
| `--base-directory /data` | ComfyUI paths rooted on the volume |
| `--offline` | UI does not reach the internet; fetch models on the host |
| `--disable-all-custom-nodes` | Stock ComfyUI only (no custom node packs) |
| `--vram-headroom` | Extra VRAM kept free for dynamic VRAM (env var, default `2.5`) |
| `PUID` / `PGID` | Container user for files under `data/` (default `1000`) |

Defaults are built into `compose.yaml`; no `.env` file is required. Optional overrides: copy [`.env.example`](.env.example) to `.env` or set variables in the shell.

`--lowvram` has no effect while dynamic VRAM is enabled.

## Model

Download weights on the **host** (not inside the container). ComfyUI reads `data/models/` live; no container recreate needed after files are in place.

```bash
cd ~/comfyui   # or your clone path
bash scripts/download-models.sh          # FLUX Klein image (~13 GB)
bash scripts/download-models.sh wan      # Wan 2.2 TI2V 5B video (~18 GB)
bash scripts/download-models.sh all      # both
```

### FLUX.2 [klein] 4B image (default)

Apache 2.0. Text-to-image and image edit. FP8 on disk; on GPUs without strong FP8 compute, ComfyUI may run much of the graph in BF16 and spill to host RAM when VRAM is tight.

| File | Folder |
| ---- | ------ |
| `flux-2-klein-4b-fp8.safetensors` | `data/models/diffusion_models/` |
| `qwen_3_4b.safetensors` | `data/models/text_encoders/` |
| `flux2-vae.safetensors` | `data/models/vae/` |

**First image**

1. Workflow templates → **Flux.2 [Klein] 4B: Text to Image** (distilled), or fix loaders on the non-distilled template.
2. Diffusion: `flux-2-klein-4b-fp8.safetensors` (not `flux-2-klein-base-4b.safetensors`).
3. Text encoder `qwen_3_4b.safetensors`, VAE `flux2-vae.safetensors`.
4. **4 steps**, **CFG 1**. PNGs land in `data/output/`.

Image-edit template: same three files; reference in `data/input/` or upload in the UI.

### Wan 2.2 TI2V 5B video (optional)

Text-to-video and image-to-video ([Comfy docs](https://docs.comfy.org/tutorials/video/wan/wan2_2)). Uses the **5B** hybrid diffusion model and **Wan 2.2** VAE (not `wan_2.1_vae`, which is for 14B workflows).

| File | Folder |
| ---- | ------ |
| `wan2.2_ti2v_5B_fp16.safetensors` | `data/models/diffusion_models/` |
| `umt5_xxl_fp8_e4m3fn_scaled.safetensors` | `data/models/text_encoders/` |
| `wan2.2_vae.safetensors` | `data/models/vae/` |

**First clip**

1. Workflow → Browse templates → **Video** → **Wan 2.2 5B** (or “Wan2.2 5B video generation”).
2. Load diffusion `wan2.2_ti2v_5B_fp16.safetensors`, CLIP/text encoder `umt5_xxl_fp8_e4m3fn_scaled.safetensors`, VAE `wan2.2_vae.safetensors`.
3. Text-to-video: run with prompt only. Image-to-video: enable the **Load image** node (often **Ctrl+B** on that node).
4. Lower **resolution** and **frame count** on a 12 GB card, especially if another GPU workload is running. Clips land in `data/output/`.

### Not included

| Option | Why |
| ------ | --- |
| FLUX.2 [klein] 9B / [dev], FLUX.1 [dev] | Size, license, or VRAM |
| Wan 2.2 **14B** T2V/I2V | Two large diffusion files + `wan_2.1_vae`; needs much more VRAM |
| Qwen-Image full weights | 24 GB class hardware |

## Sharing the GPU

If another job (second container, desktop app, inference worker) uses the same GPU, ComfyUI and that job time-share the card. After a run, check `nvidia-smi` on the host.

If the other workload gets OOM-killed or restarted during generation, raise `VRAM_HEADROOM` (try `3` or `3.5` in `.env` — see `.env.example`) and recreate:

```bash
docker compose up -d
```

If generation fails for lack of memory, lower the template resolution (for example 1024 → 768) before raising headroom further. Very high headroom pushes more through system RAM and slows each image.

## Stop

```bash
docker compose down
```

Removes the container. `data/` (weights and PNGs) stays. The image stays until `docker image rm comfyui`.

## License

This repository (Docker/Compose wiring and scripts) is offered as-is. [ComfyUI](https://github.com/Comfy-Org/ComfyUI) and each model checkpoint have their own licenses; accept those on Hugging Face before downloading weights.
