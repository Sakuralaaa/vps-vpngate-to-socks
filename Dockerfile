FROM alpine:3.20

RUN apk add --no-cache \
    bash \
    ca-certificates \
    curl \
    iproute2 \
    iptables \
    openvpn \
    psmisc \
    python3 \
    tzdata \
  && rm -rf /var/cache/apk/*

WORKDIR /app

COPY vpngate_manager.py proxy_server.py vpn_utils.py LICENSE /app/
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod +x /usr/local/bin/docker-entrypoint.sh \
  && mkdir -p /app/data

ENV VPNGATE_DATA_DIR=/app/data \
    LOCAL_PROXY_HOST=0.0.0.0 \
    LOCAL_PROXY_PORT=7928 \
    UI_HOST=0.0.0.0 \
    UI_PORT=8787 \
    TZ=Asia/Shanghai

EXPOSE 8787 7928

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD python3 -c "import os,socket; s=socket.create_connection(('127.0.0.1', int(os.environ.get('UI_PORT','8787'))), 3); s.close()"

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
