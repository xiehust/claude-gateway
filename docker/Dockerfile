# Claude apps gateway image — ARM64 glibc.
#
# The gateway server runs the *native* Linux `claude` binary (NOT Node). A
# "requires the native binary" boot error means the wrong artifact was baked in.
# We copy the host-verified, pinned 2.1.196 aarch64 binary (integrity source:
# the locally installed, version-managed release at
# /home/ubuntu/.local/share/claude/versions/2.1.196, ELF aarch64, glibc).
FROM debian:bookworm-slim

# Runtime deps: CA roots (TLS to OIDC/Bedrock), and the glibc the binary links.
# debian:bookworm-slim already ships glibc; we only add ca-certificates + tini.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates tini \
    && rm -rf /var/lib/apt/lists/*

# Writable config/state dir — minimal images have no writable HOME; the gateway
# needs a writable state directory. Keep it out of the read-only image layers.
ENV CLAUDE_CONFIG_DIR=/tmp/.claude

# Pinned native binary.
COPY claude /usr/local/bin/claude
RUN chmod 0755 /usr/local/bin/claude \
    && /usr/local/bin/claude --version

# Config is mounted/injected at deploy time at /etc/claude/gateway.yaml.
# Do NOT bake a real gateway.yaml or any secret into the image.
RUN mkdir -p /etc/claude

# tini as PID 1 for correct signal handling under ECS.
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["claude", "gateway", "--config", "/etc/claude/gateway.yaml"]
