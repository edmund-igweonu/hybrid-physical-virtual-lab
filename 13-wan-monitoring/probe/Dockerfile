FROM ubuntu:24.04
RUN apt-get update && apt-get install -y --no-install-recommends \
      iputils-ping dnsutils curl ca-certificates tzdata \
    && rm -rf /var/lib/apt/lists/*
COPY probe.sh /usr/local/bin/probe.sh
RUN chmod +x /usr/local/bin/probe.sh
ENTRYPOINT ["/usr/local/bin/probe.sh"]
