# Seq for Railway: the official Datalust image, pinned by digest, with an entrypoint that
# (1) accepts the EULA on the deployer's behalf (deploying this template is that acceptance),
# (2) listens on Railway's injected $PORT on IPv4 and IPv6 (the stock image listens on 80/5341,
#     which Railway's healthcheck never dials),
# (3) seeds the admin credential and one ingest+read API key from variables, so a coding agent can
#     ship and query logs with no UI step.
FROM datalust/seq:2026.1@sha256:76f6ecdf9f742442f5b7e31eb9b94084b952af0575049d5c1e9d9101a6c8100f
LABEL org.opencontainers.image.source="https://github.com/bon5co/seq-railway"
LABEL org.opencontainers.image.description="Datalust Seq structured log server with Railway defaults: generated admin login and API key"
COPY entrypoint.sh /usr/local/bin/railway-entrypoint.sh
RUN chmod +x /usr/local/bin/railway-entrypoint.sh
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
