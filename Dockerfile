# ==============================================================================
# Dockerfile: Home Assistant Latest para QNAP ARM 32K - Versao definitiva
# Estrategia: Usa base 32K do Alberto + Python 3.14 standalone + wheels apenas
# ==============================================================================
FROM albertogeniola/homeassistant-qnap-32k:latest

LABEL maintainer="QNAP 32K Home Assistant Auto-Builder"
LABEL description="Home Assistant Latest com Python 3.14 compativel com QNAP 32K"

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Lisbon
ENV DISABLE_JEMALLOC=True
ENV PYTHONUNBUFFERED=1

# 1. Atualiza libstdc++6 (resolve o erro GLIBCXX_3.4.29 para Google Home / grpc)
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common curl ca-certificates gnupg && \
    add-apt-repository -y ppa:ubuntu-toolchain-r/test && \
    apt-get update && apt-get install -y --no-install-recommends libstdc++6 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 2. Instala Python 3.14 standalone para ARMv7 (pre-compilado oficial da Astral)
RUN mkdir -p /opt/python3.14 && \
    curl -fsSL "https://github.com/astral-sh/python-build-standalone/releases/download/20260901/cpython-3.14.7%2B20260901-armv7-unknown-linux-gnueabihf-install_only.tar.gz" \
    | tar -xz -C /opt/python3.14 --strip-components=1

# 3. Cria ambiente virtual limpo com Python 3.14
RUN /opt/python3.14/bin/python3 -m venv /homeassistant/.venv --clear && \
    /homeassistant/.venv/bin/pip install --no-cache-dir --upgrade pip setuptools wheel

# 4. Instala o Home Assistant usando wheels pre-compiladas (evita compilar C++ no ARM emulado)
ARG HA_VERSION=latest
RUN if [ "$HA_VERSION" = "latest" ] || [ -z "$HA_VERSION" ]; then \
        /homeassistant/.venv/bin/pip install --no-cache-dir \
            --prefer-binary \
            homeassistant; \
    else \
        /homeassistant/.venv/bin/pip install --no-cache-dir \
            --prefer-binary \
            homeassistant==${HA_VERSION}; \
    fi

WORKDIR /config
EXPOSE 8123

CMD ["/homeassistant/.venv/bin/python3", "-m", "homeassistant", "-c", "/config"]
