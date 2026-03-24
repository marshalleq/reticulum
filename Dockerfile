FROM python:3.12-slim AS builder

RUN pip install --no-cache-dir rns nomadnet lxmf

FROM python:3.12-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends gosu && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=builder /usr/local/bin/rnsd /usr/local/bin/rnsd
COPY --from=builder /usr/local/bin/rnstatus /usr/local/bin/rnstatus
COPY --from=builder /usr/local/bin/rnpath /usr/local/bin/rnpath
COPY --from=builder /usr/local/bin/rnprobe /usr/local/bin/rnprobe
COPY --from=builder /usr/local/bin/rncp /usr/local/bin/rncp
COPY --from=builder /usr/local/bin/rnx /usr/local/bin/rnx
COPY --from=builder /usr/local/bin/nomadnet /usr/local/bin/nomadnet
COPY --from=builder /usr/local/bin/lxmd /usr/local/bin/lxmd

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV PUID=1000
ENV PGID=1000
ENV RNS_LOGLEVEL=4

VOLUME /config
VOLUME /logs

EXPOSE 37428
EXPOSE 4242

ENTRYPOINT ["/entrypoint.sh"]
CMD ["rnsd", "--config", "/config"]
