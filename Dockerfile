```dockerfile
# ==============================================================================
# Home Assistant Container para QNAP NAS ARMv7
# Base: Ubuntu 22.04 (Jammy)
#
# Objetivo:
# - ARMv7 / 32 bits
# - Home Assistant 2026.2.3
# - Compatibilidade com QNAP
# - Evitar wheels de cffi/cryptography incompatíveis com GLIBC
# ==============================================================================

FROM ubuntu:22.04

# ==============================================================================
# 1. Variáveis de ambiente
# ==============================================================================

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    DISABLE_JEMALLOC=true \
    PATH="/homeassistant/.venv/bin:/usr/local/bin:$PATH" \
    LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"

# ==============================================================================
# 2. Repositórios e ferramentas básicas
# ==============================================================================

RUN sed -i 's/main restricted/main restricted universe multiverse/g' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        software-properties-common && \
    update-ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# ==============================================================================
# 3. Repositório Deadsnakes
#    Python 3.13
# ==============================================================================

RUN mkdir -p /etc/apt/trusted.gpg.d /etc/apt/sources.list.d && \
    curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xBA6932366A755776" \
        | gpg --dearmor -o /etc/apt/trusted.gpg.d/deadsnakes.gpg && \
    echo "deb https://ppa.launchpadcontent.net/deadsnakes/ppa/ubuntu jammy main" \
        > /etc/apt/sources.list.d/deadsnakes.list

# ==============================================================================
# 4. Python 3.13 + ferramentas de compilação + bibliotecas
# ==============================================================================

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3.13 \
        python3.13-venv \
        python3.13-dev \
        build-essential \
        pkg-config \
        cmake \
        autoconf \
        automake \
        libtool \
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

# ==============================================================================
# 5. SQLite moderno
#    Home Assistant exige SQLite >= 3.40.1
# ==============================================================================

ARG SQLITE_VERSION="3460100"
ARG SQLITE_YEAR="2024"

RUN mkdir -p /tmp/sqlite && \
    cd /tmp/sqlite && \
    curl -sL \
        "https://www.sqlite.org/${SQLITE_YEAR}/sqlite-autoconf-${SQLITE_VERSION}.tar.gz" \
        | tar -xz --strip-components=1 && \
    ./configure \
        --prefix=/usr/local \
        --enable-shared && \
    make -j$(nproc) && \
    make install && \
    echo "/usr/local/lib" > /etc/ld.so.conf.d/00-local.conf && \
    ldconfig && \
    cd / && \
    rm -rf /tmp/sqlite

# ==============================================================================
# 6. go2rtc para ARM
# ==============================================================================

RUN curl -sL \
        "https://github.com/AlexxIT/go2rtc/releases/latest/download/go2rtc_linux_arm" \
        -o /usr/local/bin/go2rtc && \
    chmod +x /usr/local/bin/go2rtc

# ==============================================================================
# 7. SSOCR
# ==============================================================================

ARG SSOCR_VERSION="2.23.1"

RUN mkdir -p /tmp/ssocr /opt/ssocr && \
    curl -sL \
        "https://github.com/auerswal/ssocr/archive/refs/tags/v${SSOCR_VERSION}.tar.gz" \
        | tar -xz -C /tmp/ssocr --strip-components=1 && \
    cd /tmp/ssocr && \
    make -j$(nproc) && \
    make PREFIX=/opt/ssocr install && \
    ln -s /opt/ssocr/bin/ssocr /usr/local/bin/ssocr && \
    cd / && \
    rm -rf /tmp/ssocr

# ==============================================================================
# 8. Ambiente virtual Python
# ==============================================================================

RUN mkdir -p /homeassistant /config && \
    python3.13 -m venv /homeassistant/.venv && \
    /homeassistant/.venv/bin/pip install --no-cache-dir \
        --upgrade pip wheel setuptools

# ==============================================================================
# 9. Configurar Piwheels
#
# IMPORTANTE:
# Não usamos prefer-binary globalmente.
# cffi e cryptography serão compilados localmente.
# ==============================================================================

RUN printf "[global]\n" > /etc/pip.conf && \
    printf "extra-index-url = https://www.piwheels.org/simple\n" >> /etc/pip.conf

# ==============================================================================
# 10. Compilar CFFI localmente
#
# Isto evita utilizar um wheel pré-compilado que possa exigir GLIBC 2.38.
# ==============================================================================

RUN /homeassistant/.venv/bin/pip install \
        --no-cache-dir \
        --no-binary=cffi \
        cffi

# ==============================================================================
# 11. Compilar Cryptography localmente
#
# Isto também evita wheels pré-compilados incompatíveis com o glibc
# existente no Ubuntu 22.04.
# ==============================================================================

RUN /homeassistant/.venv/bin/pip install \
        --no-cache-dir \
        --no-binary=cryptography \
        cryptography

# ==============================================================================
# 12. Instalar Home Assistant
# ==============================================================================

ARG HA_VERSION="2026.2.3"

ENV HA_VERSION=${HA_VERSION}

RUN /homeassistant/.venv/bin/pip install \
        --no-cache-dir \
        homeassistant==${HA_VERSION}

# ==============================================================================
# 13. Portas e volumes
# ==============================================================================

EXPOSE 8123

VOLUME ["/config"]

WORKDIR /config

# ==============================================================================
# 14. Inicialização
# ==============================================================================

CMD ["/homeassistant/.venv/bin/python3", "-m", "homeassistant", "-c", "/config"]
```
