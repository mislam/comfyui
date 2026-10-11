#!/bin/bash
set -euo pipefail

mkdir -p \
	/data/models/diffusion_models \
	/data/models/text_encoders \
	/data/models/vae \
	/data/input \
	/data/output \
	/data/temp \
	/data/user

cd /opt/ComfyUI

exec python main.py \
	--listen 0.0.0.0 \
	--port 8188 \
	--disable-auto-launch \
	--disable-all-custom-nodes \
	--offline \
	--vram-headroom "${VRAM_HEADROOM:-2.5}" \
	--base-directory /data
