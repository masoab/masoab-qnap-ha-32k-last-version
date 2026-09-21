# Home Assistant para QNAP ARMv7 / 32 bits

# Base Ubuntu 22.04

# Home Assistant 2026.2.3

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV DISABLE_JEMALLOC=true
ENV PATH=/homeassistant/.venv/bin:/usr/local/bin:/usr/bin:/bin
ENV LD_LIBRARY_PATH=/usr/local/lib

# Ferramentas básicas

RUN sed -i 's/main restricted/main restricted universe multiverse/g' /etc/apt/sources.list

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl gnupg software-properties-common && apt-get clean && rm -rf /var/lib/apt/lists/*

# Python 3.13 - Deadsnakes

RUN mkdir -p /etc/apt/trusted.gpg.d /etc/apt/sources.list.d

RUN curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xBA6932366A755776" | gpg --dearmor -o /etc/apt/trusted.gpg.d/deadsnakes.gpg

RUN echo "deb https://ppa.launchpadcontent.net/deadsnakes/ppa/ubuntu jammy main" > /etc/apt/sources.list.d/deadsnakes.list

# Python 3.13 e ferramentas de compilação

RUN apt-get update && apt-get install -y --no-install-recommends python3.13 python3.13-venv python3.13-dev build-essential pkg-config cmake autoconf automake libtool cargo rustc git ffmpeg libavcodec-dev libavformat-dev libavutil-dev libswscale-dev libswresample-dev libffi-dev libssl-dev libjpeg-dev zlib1g-dev libopenblas-dev gfortran libturbojpeg0-dev libpcap-dev libasound2 libasound2-dev libv4l-0 libv4l-dev libimlib2-dev bluez tzdata && apt-get clean && rm -rf /var/lib/apt/lists/*

# SQLite 3.46.1

ARG SQLITE_VERSION=3460100
ARG SQLITE_YEAR=2024

RUN mkdir -p /tmp/sqlite && cd /tmp/sqlite && curl -sL "https://www.sqlite.org/${SQLITE_YEAR}/sqlite-autoconf-${SQLITE_VERSION}.tar.gz" | tar -xz --strip-components=1 && ./configure --prefix=/usr/local --enable-shared && make -j$(nproc) && make install && echo "/usr/local/lib" > /etc/ld.so.conf.d/00-local.conf && ldconfig && cd / && rm -rf /tmp/sqlite

# go2rtc

RUN curl -sL "https://github.com/AlexxIT/go2rtc/releases/latest/download/go2rtc_linux_arm" -o /usr/local/bin/go2rtc && chmod +x /usr/local/bin/go2rtc

# SSOCR

ARG SSOCR_VERSION=2.23.1

RUN mkdir -p /tmp/ssocr /opt/ssocr && curl -sL "https://github.com/auerswal/ssocr/archive/refs/tags/v${SSOCR_VERSION}.tar.gz" | tar -xz -C /tmp/ssocr --strip-components=1 && cd /tmp/ssocr && make -j$(nproc) && make PREFIX=/opt/ssocr install && ln -s /opt/ssocr/bin/ssocr /usr/local/bin/ssocr && cd / && rm -rf /tmp/ssocr

# Ambiente virtual Python

RUN mkdir -p /homeassistant /config

RUN python3.13 -m venv /homeassistant/.venv

RUN /homeassistant/.venv/bin/pip install --no-cache-dir --upgrade pip wheel setuptools

# Piwheels

RUN printf "[global]\nextra-index-url = https://www.piwheels.org/simple\n" > /etc/pip.conf

# CFFI compilado localmente

# Evita wheel que exige GLIBC 2.38

RUN /homeassistant/.venv/bin/pip install --no-cache-dir --no-binary=cffi cffi

# Cryptography compilado localmente

# Evita wheel pré-compilado incompatível

RUN /homeassistant/.venv/bin/pip install --no-cache-dir --no-binary=cryptography cryptography

# Home Assistant

ARG HA_VERSION=2026.2.3

ENV HA_VERSION=${HA_VERSION}

RUN /homeassistant/.venv/bin/pip install --no-cache-dir homeassistant==${HA_VERSION}

# Configuração

EXPOSE 8123

VOLUME ["/config"]

WORKDIR /config

CMD ["/homeassistant/.venv/bin/python3", "-m", "homeassistant", "-c", "/config"]
