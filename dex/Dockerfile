# Tiny wrapper: official Dex + baked config. Most robust config delivery on
# Fargate (no EFS/sidecar). The client secret stays out of the image — it is
# expanded from $DEX_CLIENT_SECRET at runtime (injected from Secrets Manager).
FROM ghcr.io/dexidp/dex:v2.41.1
COPY config.yaml /etc/dex/config.yaml
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
# image runs as a non-root user; ensure the script is executable
USER root
RUN chmod 0755 /usr/local/bin/entrypoint.sh
USER 1001
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
