FROM ubuntu:24.04
RUN apt-get update && apt-get install -y \
    freeradius freeradius-utils \
    iproute2 iputils-ping tcpdump net-tools vim \
    && rm -rf /var/lib/apt/lists/*
RUN sed -i "s/use_tunneled_reply = no/use_tunneled_reply = yes/" /etc/freeradius/3.0/mods-available/eap
COPY clients.conf /etc/freeradius/3.0/clients.conf
COPY authorize /etc/freeradius/3.0/mods-config/files/authorize
RUN chown -R freerad:freerad /etc/freeradius/3.0
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
