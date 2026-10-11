#!/usr/bin/env bash
# Download FLUX.2 [klein] 4B weights into ./data/models. Run on the host, not in the container.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
models="$root/data/models"
mkdir -p "$models/diffusion_models" "$models/text_encoders" "$models/vae" \
	"$root/data/input" "$root/data/output"

fetch() {
	local url="$1" dest="$2" bytes="$3"
	if [[ -f "$dest" ]] && [[ "$(stat -c%s "$dest")" == "$bytes" ]]; then
		echo "ok $(basename "$dest")"
		return
	fi
	echo "downloading $(basename "$dest")"
	curl -fL --retry 5 --retry-all-errors --retry-delay 2 -C - -o "${dest}.partial" "$url"
	mv "${dest}.partial" "$dest"
	local got
	got="$(stat -c%s "$dest")"
	if [[ "$got" != "$bytes" ]]; then
		rm -f "$dest"
		echo "size mismatch for $(basename "$dest"): got ${got}, want ${bytes}" >&2
		exit 1
	fi
}

# Byte sizes from Hugging Face model tree (re-check if a fetch fails).
fetch \
	"https://huggingface.co/black-forest-labs/FLUX.2-klein-4b-fp8/resolve/main/flux-2-klein-4b-fp8.safetensors" \
	"$models/diffusion_models/flux-2-klein-4b-fp8.safetensors" \
	4070624520

fetch \
	"https://huggingface.co/Comfy-Org/vae-text-encorder-for-flux-klein-4b/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors" \
	"$models/text_encoders/qwen_3_4b.safetensors" \
	8044982048

fetch \
	"https://huggingface.co/Comfy-Org/vae-text-encorder-for-flux-klein-4b/resolve/main/split_files/vae/flux2-vae.safetensors" \
	"$models/vae/flux2-vae.safetensors" \
	336211292

echo "weights ready under $models"
