# ==============================================================================
# Dockerfile: Home Assistant Latest para QNAP ARM (Kernel 32K Page Size)
# ==============================================================================
FROM albertogeniola/homeassistant-qnap-32k:latest

LABEL maintainer="QNAP 32K Home Assistant Auto-Builder"
LABEL description="Home Assistant compativel com QNAP 32K Page Size"

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Sao_Paulo
ENV DISABLE_JEMALLOC=True

# 1. Atualiza libstdc++6 para resolver o erro GLIBCXX_3.4.29 (necessario para google_home / grpc)
RUN apt-get update && apt-get install -y --no-install-recommends software-properties-common && \
    add-apt-repository -y ppa:ubuntu-toolchain-r/test && \
    apt-get update && apt-get install -y --no-install-recommends libstdc++6 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 2. Atualiza o Home Assistant para a versao mais recente
ARG HA_VERSION=latest
RUN if [ "$HA_VERSION" = "latest" ] || [ -z "$HA_VERSION" ]; then \
        /homeassistant/.venv/bin/pip install --no-cache-dir --upgrade homeassistant; \
    else \
        /homeassistant/.venv/bin/pip install --no-cache-dir homeassistant==${HA_VERSION}; \
    fi

WORKDIR /config
EXPOSE 8123

CMD ["/homeassistant/.venv/bin/python3", "-m", "homeassistant", "-c", "/config"]
