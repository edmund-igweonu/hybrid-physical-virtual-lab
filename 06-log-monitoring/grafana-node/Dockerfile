FROM ubuntu:24.04

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        apt-transport-https \
        software-properties-common \
        wget \
        gpg \
        iproute2 \
        ca-certificates && \
    wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor > /usr/share/keyrings/grafana.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/grafana.gpg] https://apt.grafana.com stable main" \
        > /etc/apt/sources.list.d/grafana.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends grafana && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/grafana/provisioning/datasources

COPY datasource.yaml /etc/grafana/provisioning/datasources/datasource.yaml

EXPOSE 3000/tcp

ENTRYPOINT ["/usr/sbin/grafana-server", \
            "--homepath=/usr/share/grafana", \
            "--config=/etc/grafana/grafana.ini", \
            "cfg:default.paths.provisioning=/etc/grafana/provisioning"]
