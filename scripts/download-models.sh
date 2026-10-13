#!/usr/bin/env bash
# Download ComfyUI weights into ./data/models. Run on the host, not in the container.
set -euo pipefail

usage() {
	cat >&2 <<'EOF'
usage: download-models.sh [klein|wan|all]

  klein  FLUX.2 [klein] 4B FP8 image (~13 GB) — default
  wan    Wan 2.2 TI2V 5B video (~18 GB)
  all    both sets
EOF
}

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
		echo "re-check size on Hugging Face and update scripts/download-models.sh" >&2
		exit 1
	fi
}

fetch_klein() {
	echo "=== FLUX.2 [klein] 4B ==="
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
}

fetch_wan() {
	echo "=== Wan 2.2 TI2V 5B ==="
	fetch \
		"https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_ti2v_5B_fp16.safetensors" \
		"$models/diffusion_models/wan2.2_ti2v_5B_fp16.safetensors" \
		9999658848
	fetch \
		"https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
		"$models/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
		6735906897
	fetch \
		"https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan2.2_vae.safetensors" \
		"$models/vae/wan2.2_vae.safetensors" \
		1409400960
}

target="${1:-klein}"
case "$target" in
	klein) fetch_klein ;;
	wan) fetch_wan ;;
	all) fetch_klein; fetch_wan ;;
	-h | --help) usage; exit 0 ;;
	*) usage; exit 1 ;;
esac

echo "weights ready under $models"
