FROM ubuntu:24.04

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        unzip \
        ca-certificates \
        iproute2 && \
    rm -rf /var/lib/apt/lists/*

ARG LOKI_VERSION=3.0.0
RUN curl -sL -o /tmp/loki.zip \
        "https://github.com/grafana/loki/releases/download/v${LOKI_VERSION}/loki-linux-amd64.zip" && \
    unzip /tmp/loki.zip -d /usr/local/bin && \
    mv /usr/local/bin/loki-linux-amd64 /usr/local/bin/loki && \
    chmod +x /usr/local/bin/loki && \
    rm /tmp/loki.zip

RUN mkdir -p /loki/chunks /loki/rules /etc/loki

COPY loki-config.yaml /etc/loki/local-config.yaml
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3100/tcp

ENTRYPOINT ["/entrypoint.sh"]
