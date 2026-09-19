# ==============================================================================
# Home Assistant Container para QNAP NAS ARMv7 (Compatível com Páginas de 32 KB)
# Base: Ubuntu 22.04 (Jammy) - Resolve GLIBCXX_3.4.29 e mantém suporte a 32K
# ==============================================================================
FROM ubuntu:22.04

# Variáveis de ambiente fundamentais
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    DISABLE_JEMALLOC=true \
    PATH="/homeassistant/.venv/bin:/usr/local/bin:$PATH" \
    LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"

# 1. Instalar dependências base do sistema e adicionar PPA deadsnakes (Python 3.13)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    software-properties-common \
    && add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y --no-install-recommends \
    # Python 3.13 oficial pré-compilado para armhf
    python3.13 \
    python3.13-venv \
    python3.13-dev \
    # Compiladores e utilitários
    build-essential \
    pkg-config \
    cmake \
    autoconf \
    cargo \
    rustc \
    git \
    # Bibliotecas de multimídia, Bluetooth e rede
    ffmpeg \
    libavcodec-dev \
    libavformat-dev \
    libavutil-dev \
    libswscale-dev \
    libswresample-dev \
    libffi-dev \
    libssl-dev \
    libjpeg-dev \
    zlib1g-dev \
    libopenblas-dev \
    gfortran \
    libturbojpeg0 \
    libpcap-dev \
    libasound2 \
    libasound2-dev \
    libv4l-0 \
    libv4l-dev \
    libimlib2-dev \
    bluez \
    tzdata \
    && update-ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 2. Compilar SQLite modernizado (Home Assistant exige SQLite >= 3.40.1 para o recorder)
# O Ubuntu 22.04 nativo traz o 3.37.2, logo compilamos o 3.46.1 em /usr/local
ARG SQLITE_VERSION="3460100"
ARG SQLITE_YEAR="2024"
RUN mkdir -p /tmp/sqlite && cd /tmp/sqlite && \
    curl -sL "https://www.sqlite.org/${SQLITE_YEAR}/sqlite-autoconf-${SQLITE_VERSION}.tar.gz" | tar -xz --strip-components=1 && \
    ./configure --prefix=/usr/local --enable-shared && \
    make -j$(nproc) && \
    make install && \
    echo "/usr/local/lib" > /etc/ld.so.conf.d/00-local.conf && \
    ldconfig && \
    cd / && rm -rf /tmp/sqlite

# 3. Baixar binário estático pré-compilado do go2rtc (AlexxIT) para ARM
RUN curl -sL "https://github.com/AlexxIT/go2rtc/releases/latest/download/go2rtc_linux_arm" -o /usr/local/bin/go2rtc && \
    chmod +x /usr/local/bin/go2rtc

# 4. Compilar SSOCR (Seven Segment Optical Character Recognition)
ARG SSOCR_VERSION="2.23.1"
RUN mkdir -p /tmp/ssocr /opt/ssocr && \
    curl -sL "https://github.com/auerswal/ssocr/archive/refs/tags/v${SSOCR_VERSION}.tar.gz" | tar -xz -C /tmp/ssocr --strip-components=1 && \
    cd /tmp/ssocr && \
    make -j$(nproc) && \
    make PREFIX=/opt/ssocr install && \
    ln -s /opt/ssocr/bin/ssocr /usr/local/bin/ssocr && \
    cd / && rm -rf /tmp/ssocr

# 5. Criar ambiente virtual e configurar Piwheels no PIP
# CRÍTICO: Configura o Piwheels para fornecer wheels ARMv7 pré-compilados
RUN mkdir -p /homeassistant /config && \
    python3.13 -m venv /homeassistant/.venv && \
    mkdir -p /etc && \
    printf "[global]\nextra-index-url = https://www.piwheels.org/simple\nprefer-binary = true\n" > /etc/pip.conf && \
    /homeassistant/.venv/bin/pip install --no-cache-dir --upgrade pip wheel setuptools

# 6. Instalar o Home Assistant
ARG HA_VERSION="latest"
ENV HA_VERSION=${HA_VERSION}

RUN if [ "$HA_VERSION" = "latest" ] || [ -z "$HA_VERSION" ]; then \
        /homeassistant/.venv/bin/pip install --no-cache-dir homeassistant; \
    else \
        /homeassistant/.venv/bin/pip install --no-cache-dir homeassistant==${HA_VERSION}; \
    fi

# Portas e volumes
EXPOSE 8123

VOLUME ["/config"]
WORKDIR /config

# Inicialização
CMD ["/homeassistant/.venv/bin/python3", "-m", "homeassistant", "-c", "/config"]
