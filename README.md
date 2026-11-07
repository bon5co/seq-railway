# seq-railway

[Seq](https://datalust.co/seq) (Datalust's structured log server) for Railway, as a container image.

- The official `datalust/seq` image, pinned by digest (Seq 2026.1.17526).
- Listens on Railway's `$PORT` (default 8080) on IPv4 and IPv6. The stock image listens on 80 and
  5341, which Railway's healthcheck never dials.
- Seeds the `admin` login from `SEQ_ADMIN_PASSWORD` and one API key (`railway-agent`, permissions
  Ingest, Read, Write) from `SEQ_API_KEY` on first boot, before the server is reachable.
- Data lives in `/data` (mount a volume there).
- Sets `ACCEPT_EULA=Y`: running this image is acceptance of the
  [Seq EULA](https://datalust.co/doc/eula-current.pdf). Seq runs free for a single user; more users
  or commercial multi-user use needs a licence from Datalust.

Environment: `SEQ_ADMIN_PASSWORD` and `SEQ_API_KEY` (required, letters and digits; key at least 16
characters), `PORT` (default 8080), `RAILWAY_PUBLIC_DOMAIN` (sets the canonical URI when present).

Image: `ghcr.io/bon5co/seq`. This wrapper is MIT licensed; Seq itself is proprietary software
covered by the Datalust EULA.
