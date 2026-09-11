# ==============================================================================
# Dockerfile: Home Assistant Latest / Dynamic Version para QNAP ARM (Kernel 32K)
# ==============================================================================
FROM arm32v7/ubuntu:22.04

LABEL maintainer="QNAP 32K Home Assistant Auto-Builder"
LABEL description="Home Assistant compativel com QNAP 32K Page Size (Universal)"

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Sao_Paulo
ENV DISABLE_JEMALLOC=True
ENV PYTHONUNBUFFERED=1
ENV PATH="/root/.local/bin:/root/.cargo/bin:$PATH"

# 1. Instala dependencias do sistema Ubuntu 22.04 (inclui glibc e libstdc++6 compativeis com 32k)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    tzdata \
    ffmpeg \
    libturbojpeg0 \
    libpcap0.8 \
    libasound2 \
    libv4l-0 \
    build-essential \
    libffi-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# 2. Instala o uv (gerenciador ultrarrapido de Python)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# 3. Cria o ambiente virtual com a versao de Python necessária (3.14)
ARG PYTHON_VERSION=3.14
RUN uv venv /homeassistant/.venv --python ${PYTHON_VERSION}

# 4. Instala a versao solicitada do Home Assistant (ou a mais recente se for 'latest')
ARG HA_VERSION=latest
RUN if [ "$HA_VERSION" = "latest" ]; then \
        /homeassistant/.venv/bin/pip install --no-cache-dir homeassistant; \
    else \
        /homeassistant/.venv/bin/pip install --no-cache-dir homeassistant==${HA_VERSION}; \
    fi

WORKDIR /config
EXPOSE 8123

CMD ["/homeassistant/.venv/bin/python3", "-m", "homeassistant", "-c", "/config"]
