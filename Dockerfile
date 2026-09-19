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

# 1. Ativar repositórios universe e multiverse e instalar ferramentas base
RUN sed -i 's/main restricted/main restricted universe multiverse/g' /etc/apt/sources.list && \
    sed -i 's/main/main restricted universe multiverse/g' /etc/apt/sources.list && \
    apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg && \
    update-ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# 2. Adicionar o PPA deadsnakes (Python 3.13) via chave GPG direta por HTTPS
RUN mkdir -p /etc/apt/trusted.gpg.d /etc/apt/sources.list.d && \
    curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xBA6932366A755776" | gpg --dearmor -o /etc/apt/trusted.gpg.d/deadsnakes.gpg && \
    echo "deb https://ppa.launchpadcontent.net/deadsnakes/ppa/ubuntu jammy main" > /etc/apt/sources.list.d/deadsnakes.list

# 3. Instalar Python 3.13, compiladores e bibliotecas de sistema necessárias
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3.13 \
        python3.13-venv \
        python3.13-dev \
        build-essential \
        pkg-config \
        cmake \
        autoconf \
        cargo \
        rustc \
        git \
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
        libturbojpeg0-dev \
        libpcap-dev \
        libasound2 \
        libasound2-dev \
        libv4l-0 \
        libv4l-dev \
        libimlib2-dev \
        bluez \
        tzdata && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 4. Compilar SQLite modernizado (Home Assistant exige SQLite >= 3.40.1 para o recorder)
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

# 5. Baixar binário estático pré-compilado do go2rtc (AlexxIT) para ARM
RUN curl -sL "https://github.com/AlexxIT/go2rtc/releases/latest/download/go2rtc_linux_arm" -o /usr/local/bin/go2rtc && \
    chmod +x /usr/local/bin/go2rtc

# 6. Compilar SSOCR (Seven Segment OCR)
ARG SSOCR_VERSION="2.23.1"
RUN mkdir -p /tmp/ssocr /opt/ssocr && \
    curl -sL "https://github.com/auerswal/ssocr/archive/refs/tags/v${SSOCR_VERSION}.tar.gz" | tar -xz -C /tmp/ssocr --strip-components=1 && \
    cd /tmp/ssocr && \
    make -j$(nproc) && \
    make PREFIX=/opt/ssocr install && \
    ln -s /opt/ssocr/bin/ssocr /usr/local/bin/ssocr && \
    cd / && rm -rf /tmp/ssocr

# 7. Criar ambiente virtual e configurar Piwheels no PIP
RUN mkdir -p /homeassistant /config && \
    python3.13 -m venv /homeassistant/.venv && \
    mkdir -p /etc && \
    printf "[global]\nextra-index-url = https://www.piwheels.org/simple\nprefer-binary = true\n" > /etc/pip.conf && \
    /homeassistant/.venv/bin/pip install --no-cache-dir --upgrade pip wheel setuptools

# 8. Instalar o Home Assistant utilizando os binários pré-compilados do Piwheels
ARG HA_VERSION="2026.2.3"
ENV HA_VERSION=${HA_VERSION}

RUN /homeassistant/.venv/bin/pip install --no-cache-dir \
    --extra-index-url https://www.piwheels.org/simple \
    --prefer-binary \
    homeassistant==${HA_VERSION}

# Portas e volumes
EXPOSE 8123

VOLUME ["/config"]
WORKDIR /config

# Inicialização
CMD ["/homeassistant/.venv/bin/python3", "-m", "homeassistant", "-c", "/config"]
