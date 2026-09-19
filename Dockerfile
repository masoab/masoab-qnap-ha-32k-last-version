# syntax=docker/dockerfile:1.7
################ builder ################
FROM arm32v7/debian:trixie-slim AS builder

ARG HA_VERSION=latest
ARG STRICT_ALIGN=1
ENV DEBIAN_FRONTEND=noninteractive \
    VIRTUAL_ENV=/homeassistant/.venv \
    PATH=/homeassistant/.venv/bin:$PATH \
    PIP_EXTRA_INDEX_URL=[piwheels.org](https://www.piwheels.org/simple) \
    PIP_PREFER_BINARY=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    LDFLAGS="-Wl,-z,max-page-size=32768 -Wl,-z,common-page-size=32768"

RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 python3-venv python3-dev build-essential pkg-config \
      cargo rustc git curl ca-certificates binutils \
      libffi-dev libssl-dev zlib1g-dev libjpeg-dev libturbojpeg0-dev \
      libxml2-dev libxslt1-dev libopenjp2-7-dev libudev-dev \
      libavformat-dev libavcodec-dev libavdevice-dev libavutil-dev \
      libswscale-dev libswresample-dev libavfilter-dev libpcap-dev \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /homeassistant/.venv \
 && pip install --upgrade pip setuptools wheel

# instalação em passos separados: se falhar, o log aponta o pacote exato
RUN set -eux; \
    if [ -z "$HA_VERSION" ] || [ "$HA_VERSION" = "latest" ]; then \
        pip install -v homeassistant; \
    else \
        pip install -v "homeassistant==${HA_VERSION}"; \
    fi

# dependências comuns que o core não puxa sozinho
RUN pip install -v \
      "PyTurboJPEG" "av" "mutagen" "pyudev" "zeroconf" "securetar" "psutil-home-assistant"

# verificação de alinhamento de página (o requisito do QNAP)
RUN set -eu; bad=0; \
    for f in $(find /homeassistant/.venv -name '*.so' -o -name '*.so.*'); do \
      a=$(readelf -lW "$f" 2>/dev/null | awk '$1=="LOAD"{print $NF}' | sort -u | head -1); \
      case "$a" in 0x8000|0x10000|0x200000) ;; \
        *) echo "ALINHAMENTO $a (<32K): $f"; bad=$((bad+1));; esac; \
    done; \
    echo "bibliotecas fora do padrão: $bad"; \
    if [ "$STRICT_ALIGN" = "1" ] && [ "$bad" -gt 0 ]; then exit 1; fi

################ runtime ################
FROM arm32v7/debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive \
    VIRTUAL_ENV=/homeassistant/.venv \
    PATH=/homeassistant/.venv/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    TZ=Europe/Lisbon

RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 libstdc++6 libgcc-s1 libffi8 libssl3 zlib1g \
      libjpeg62-turbo libturbojpeg0 libxml2 libxslt1.1 libopenjp2-7 \
      libudev1 libpcap0.8 ffmpeg tzdata bluez iputils-ping \
      ca-certificates curl nano \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /homeassistant/.venv /homeassistant/.venv

VOLUME /config
EXPOSE 8123
WORKDIR /config
CMD ["python3", "-m", "homeassistant", "--config", "/config"]

