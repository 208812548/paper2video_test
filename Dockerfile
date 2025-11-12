# syntax=docker/dockerfile:1
FROM nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

ARG HTTP_PROXY_OPT=""
ARG HTTPS_PROXY_OPT=""
ARG NO_PROXY_OPT=""

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.10 \
    python3.10-venv \
    python3-pip \
    build-essential \
    ffmpeg \
    poppler-utils \
    git \
    curl \
    wget \
    ca-certificates \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxrender1 \
    libxext6 \
    libopenjp2-7 \
    libtiff5 \
    libjpeg-dev \
    pkg-config \
    unzip \
    xz-utils \
    tar \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY third_party/tectonic/tectonic-0.15.0-x86_64-unknown-linux-gnu.tar.gz /tmp/tectonic.tar.gz

RUN set -eux; \
    mkdir -p /tmp/tectonic; \
    tar -xzf /tmp/tectonic.tar.gz -C /tmp/tectonic; \
    install -m 0755 /tmp/tectonic/tectonic /usr/local/bin/tectonic; \
    /usr/local/bin/tectonic --version; \
    rm -rf /tmp/tectonic /tmp/tectonic.tar.gz

ENV VIRTUAL_ENV=/opt/venv
RUN python3.10 -m venv "${VIRTUAL_ENV}" && \
    "${VIRTUAL_ENV}/bin/pip" install --upgrade pip setuptools wheel
ENV PATH="${VIRTUAL_ENV}/bin:/root/.local/bin:/root/.cargo/bin:${PATH}" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PLAYWRIGHT_BROWSERS_PATH=/root/.cache/ms-playwright \
    PIP_NO_CACHE_DIR=1

WORKDIR /workspace

COPY src/requirements.txt /tmp/requirements.txt
RUN pip install --upgrade pip
RUN python - <<'PY'
from pathlib import Path
req = Path("/tmp/requirements.txt")
text = req.read_text()
text = text.replace("torch==2.7.0", "torch==2.6.0+cu124")
text = text.replace("torchvision==0.22.0", "torchvision==0.21.0+cu124")
req.write_text(text)
PY
RUN pip install --no-cache-dir --index-url https://download.pytorch.org/whl/cu124 \
    torch==2.6.0+cu124 torchvision==0.21.0+cu124
RUN pip install --no-cache-dir --extra-index-url https://download.pytorch.org/whl/cu124 \
    -r /tmp/requirements.txt
RUN python -m playwright install chromium

COPY . /workspace

RUN printf '%s\n' '#!/bin/bash' \
    'set -euo pipefail' \
    'if [[ "${1:-}" == "run-pipeline" ]]; then' \
    '  shift || true' \
    '  declare -a args=("$@")' \
    '  contains_arg() {' \
    '    local needle="$1"' \
    '    shift' \
    '    for token in "$@"; do' \
    '      if [[ "$token" == "$needle" ]]; then' \
    '        return 0' \
    '      fi' \
    '    done' \
    '    return 1' \
    '  }' \
    '  if [[ "${#args[@]}" -eq 0 ]]; then' \
    '    if [[ -z "${PAPER_LATEX_ROOT:-}" ]]; then' \
    '      echo "PAPER_LATEX_ROOT must be set or passed via --paper_latex_root when using run-pipeline." >&2' \
    '      exit 1' \
    '    fi' \
    '    args+=(--paper_latex_root "${PAPER_LATEX_ROOT}")' \
    '    args+=(--result_dir "${RESULT_DIR:-/workspace/output}")' \
    '    args+=(--ref_img "${REF_IMG:-/workspace/assets/demo/zeyu.png}")' \
    '    args+=(--ref_audio "${REF_AUDIO:-/workspace/assets/demo/zeyu.wav}")' \
    '    if [[ -n "${STAGE:-}" ]]; then' \
    '      args+=(--stage "${STAGE}")' \
    '    fi' \
  '  else' \
    '    if [[ -n "${PAPER_LATEX_ROOT:-}" ]] && ! contains_arg "--paper_latex_root" "${args[@]}"; then' \
    '      args+=(--paper_latex_root "${PAPER_LATEX_ROOT}")' \
    '    fi' \
    '    if [[ -n "${RESULT_DIR:-}" ]] && ! contains_arg "--result_dir" "${args[@]}"; then' \
    '      args+=(--result_dir "${RESULT_DIR}")' \
    '    fi' \
    '    if [[ -n "${REF_IMG:-}" ]] && ! contains_arg "--ref_img" "${args[@]}"; then' \
    '      args+=(--ref_img "${REF_IMG}")' \
    '    fi' \
    '    if [[ -n "${REF_AUDIO:-}" ]] && ! contains_arg "--ref_audio" "${args[@]}"; then' \
    '      args+=(--ref_audio "${REF_AUDIO}")' \
    '    fi' \
    '    if [[ -n "${STAGE:-}" ]] && ! contains_arg "--stage" "${args[@]}"; then' \
    '      args+=(--stage "${STAGE}")' \
    '    fi' \
    '  fi' \
    '  cd /workspace/src' \
    '  exec python pipeline_light.py "${args[@]}"' \
    'else' \
    '  exec "$@"' \
    'fi' > /usr/local/bin/paper2video-entrypoint.sh && \
    chmod +x /usr/local/bin/paper2video-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/paper2video-entrypoint.sh"]
CMD ["bash"]
