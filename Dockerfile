# ==============================================================================
# Dockerfile: Home Assistant Latest (Universal / Python 3.14+) para QNAP 32K
# ==============================================================================
FROM albertogeniola/homeassistant-qnap-32k:latest

LABEL maintainer="QNAP 32K Home Assistant Auto-Builder"
LABEL description="Home Assistant Latest com Python 3.14 compativel com QNAP 32K"

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Sao_Paulo
ENV DISABLE_JEMALLOC=True
ENV PYTHONUNBUFFERED=1

# 1. Atualiza libstdc++6 (resolve o erro GLIBCXX_3.4.29 para Google Home / grpc) e utilitarios
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common curl ca-certificates && \
    add-apt-repository -y ppa:ubuntu-toolchain-r/test && \
    apt-get update && apt-get install -y --no-install-recommends libstdc++6 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 2. Instala o Python 3.14 standalone oficial para ARMv7 (suporte a versoes recentes e futuras)
RUN mkdir -p /opt/python3.14 && \
    curl -fsSL https://github.com/astral-sh/python-build-standalone/releases/download/20260901/cpython-3.14.7%2B20260901-armv7-unknown-linux-gnueabihf-install_only.tar.gz | tar -xz -C /opt/python3.14 --strip-components=1 && \
    /opt/python3.14/bin/python3 -m venv /homeassistant/.venv --clear

# 3. Instala a versao mais recente estavel do Home Assistant
ARG HA_VERSION=latest
RUN /homeassistant/.venv/bin/pip install --no-cache-dir --upgrade pip wheel && \
    if [ "$HA_VERSION" = "latest" ] || [ -z "$HA_VERSION" ]; then \
        /homeassistant/.venv/bin/pip install --no-cache-dir homeassistant; \
    else \
        /homeassistant/.venv/bin/pip install --no-cache-dir homeassistant==${HA_VERSION}; \
    fi

WORKDIR /config
EXPOSE 8123

CMD ["/homeassistant/.venv/bin/python3", "-m", "homeassistant", "-c", "/config"]
