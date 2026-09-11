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
ENV PATH="/usr/local/bin:/root/.local/bin:/root/.cargo/bin:$PATH"

# 1. Habilita repositorios universe/multiverse e instala dependencias do sistema
RUN sed -i 's/main restricted/main restricted universe multiverse/g' /etc/apt/sources.list && \
    apt-get update && apt-get install -y --no-install-recommends \
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

# 2. Instala o uv e copia para /usr/local/bin
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    (cp /root/.local/bin/uv* /usr/local/bin/ 2>/dev/null || cp /root/.cargo/bin/uv* /usr/local/bin/ 2>/dev/null || true)

# 3. Cria o ambiente virtual com Python 3.14 (com pip, setuptools e wheel pré-instalados)
ARG PYTHON_VERSION=3.14
RUN uv venv /homeassistant/.venv --python ${PYTHON_VERSION} --seed

# 4. Instala a versao solicitada do Home Assistant usando uv pip
ARG HA_VERSION=latest
RUN if [ "$HA_VERSION" = "latest" ]; then \
        uv pip install --python /homeassistant/.venv homeassistant; \
    else \
        uv pip install --python /homeassistant/.venv homeassistant==${HA_VERSION}; \
    fi

WORKDIR /config
EXPOSE 8123

CMD ["/homeassistant/.venv/bin/python3", "-m", "homeassistant", "-c", "/config"]
