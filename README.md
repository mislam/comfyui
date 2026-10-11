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

Default download script: **FLUX.2 [klein] 4B distilled, FP8 weights** (Apache 2.0). Text-to-image and image edit from reference images. FP8 checkpoints are smallest on disk; on GPUs without strong FP8 compute, ComfyUI may run much of the graph in BF16 and spill to host RAM when VRAM is tight.

Other options omitted here on purpose:

| Option                    | Why it is not in this folder                           |
| ------------------------- | ------------------------------------------------------ |
| FLUX.2 [klein] 9B         | Distilled peak is about 19 GB. Non-commercial license. |
| FLUX.2 [dev]              | 32B. Does not fit typical consumer GPUs.               |
| FLUX.1 [dev] full weights | About 23 GB on disk, and a different, older graph.     |
| Qwen-Image full weights   | Needs a 24 GB card for the unquantized file.           |

On the server (~13 GB: 3.8 GB diffusion, 8.0 GB text encoder, 0.3 GB VAE):

```bash
cd ~/comfyui   # or your clone path
bash scripts/download-models.sh
```

ComfyUI reads `data/models/` live. No container recreate needed after files are in place.

### First image

1. Workflow templates → **Flux.2 [Klein] 4B: Text to Image**.
2. On the **distilled** loader, set the diffusion model to `flux-2-klein-4b-fp8.safetensors`.
   The template’s default name is the larger BF16 file, which this script does not download.
3. Text encoder `qwen_3_4b.safetensors`, VAE `flux2-vae.safetensors`.
4. Distilled settings are **4 steps**, **CFG 1**. A negative prompt has no effect at CFG 1.
5. Queue the distilled graph. PNGs land in `data/output/`.

The same weights drive the **Flux.2 [Klein] 4B** distilled image-edit template. Put a reference in
`data/input/` (or upload it in the UI) when you want a variation of an image you already have.

Example prompt:

```text
a ceramic cup on a wooden table, soft morning light, centered, plain background
```

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
