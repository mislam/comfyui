# ComfyUI on NVIDIA GPUs (pinned ComfyUI release).
# Keep the PyTorch CUDA build from the base image; do not pip-install torch from requirements.txt.
FROM pytorch/pytorch:2.9.1-cuda12.8-cudnn9-runtime

ARG COMFYUI_REF=v0.39.2

ENV DEBIAN_FRONTEND=noninteractive \
	PIP_DISABLE_PIP_VERSION_CHECK=1 \
	PYTHONDONTWRITEBYTECODE=1 \
	PYTHONUNBUFFERED=1

RUN apt-get update -qq \
	&& apt-get install -qq --no-install-recommends \
		ca-certificates \
		git \
		libgl1 \
		libglib2.0-0 \
	&& apt-get clean -qq \
	&& rm -rf /var/lib/apt/lists/*

WORKDIR /opt/ComfyUI

RUN git clone --depth 1 --branch ${COMFYUI_REF} https://github.com/Comfy-Org/ComfyUI.git .

# requirements.txt lists torch unpinned. Installing it would replace the CUDA build.
RUN grep -Ev '^(torch|torchvision|torchaudio)$' requirements.txt \
	| pip install --no-cache-dir -r /dev/stdin

COPY entrypoint.sh /entrypoint.sh

EXPOSE 8188

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
