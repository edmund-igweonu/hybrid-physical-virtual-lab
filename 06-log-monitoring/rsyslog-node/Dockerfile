FROM ubuntu:24.04

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        rsyslog \
        tcpdump \
        iproute2 \
        net-tools \
        curl \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Promtail (tails the per-host log files rsyslog writes, pushes to Loki)
ARG PROMTAIL_VERSION=3.0.0
RUN curl -sL -o /tmp/promtail.zip \
        "https://github.com/grafana/loki/releases/download/v${PROMTAIL_VERSION}/promtail-linux-amd64.zip" && \
    apt-get update && apt-get install -y --no-install-recommends unzip && \
    unzip /tmp/promtail.zip -d /usr/local/bin && \
    mv /usr/local/bin/promtail-linux-amd64 /usr/local/bin/promtail && \
    chmod +x /usr/local/bin/promtail && \
    rm /tmp/promtail.zip && \
    apt-get purge -y unzip && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/log/remote

COPY rsyslog.conf /etc/rsyslog.conf
COPY promtail-config.yaml /etc/promtail/promtail-config.yaml

# rsyslog runs as a daemon; promtail runs in foreground.
# Start both via a tiny entrypoint script so the container has one PID 1
# that supervises rsyslogd and keeps promtail attached to the log files.
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 514/udp 514/tcp

ENTRYPOINT ["/entrypoint.sh"]
