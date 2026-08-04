FROM ubuntu:24.04
RUN apt-get update && apt-get install -y \
    iptables iproute2 iputils-ping tcpdump curl net-tools python3 \
    && rm -rf /var/lib/apt/lists/*
COPY fw-rules.sh /root/fw-rules.sh
RUN chmod +x /root/fw-rules.sh
CMD ["/bin/bash"]
