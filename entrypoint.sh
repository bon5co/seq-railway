#!/bin/bash
# Seq on $PORT (dual-stack), admin login and API key seeded from variables.
# Boot is two-phase so the API key exists before the server is reachable by anything else:
#   1. start Seq on loopback only, log in as admin, create the API key if it is missing, stop it;
#   2. exec Seq on the public listen address.
# The healthcheck therefore cannot pass before the key works.
set -euo pipefail

export ACCEPT_EULA=Y
unset SEQ_PASSWORD
DATA_DIR="${DATA_DIR:-/data}"
export DATA_DIR
LISTEN_PORT="${PORT:-8080}"
ADMIN_USER="admin"
KEY_TITLE="railway-agent"
BOOT_PORT=18999

: "${SEQ_ADMIN_PASSWORD:?SEQ_ADMIN_PASSWORD is required}"
: "${SEQ_API_KEY:?SEQ_API_KEY is required}"
if [ "${#SEQ_API_KEY}" -lt 16 ] || [[ ! "$SEQ_API_KEY" =~ ^[A-Za-z0-9]+$ ]]; then
  echo "[boot] SEQ_API_KEY must be at least 16 letters and digits" >&2
  exit 1
fi
if [[ ! "$SEQ_ADMIN_PASSWORD" =~ ^[A-Za-z0-9]+$ ]]; then
  echo "[boot] SEQ_ADMIN_PASSWORD must be letters and digits only" >&2
  exit 1
fi

mkdir -p "$DATA_DIR"
echo "[boot] data dir owner=$(stat -c %u:%g "$DATA_DIR") listen=[::]:$LISTEN_PORT"

# The hash only matters on the first boot of a volume; later boots keep the stored user.
export SEQ_FIRSTRUN_ADMINPASSWORDHASH="$(printf '%s\n' "$SEQ_ADMIN_PASSWORD" | seqsvr config hash | tail -n 1)"
export SEQ_FIRSTRUN_NOAUTHENTICATION=False

if [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
  export BASE_URI="https://${RAILWAY_PUBLIC_DOMAIN}"
fi

seqinit

provision() {
  local base="http://127.0.0.1:${BOOT_PORT}" jar csrf body code
  for _ in $(seq 1 120); do
    curl -fsS -o /dev/null "$base/api" 2>/dev/null && break
    sleep 1
  done
  jar="$(mktemp)"
  body="$(curl -sS -c "$jar" -X POST "$base/api/users/login" -H 'Content-Type: application/json' \
    --data "{\"Username\":\"${ADMIN_USER}\",\"Password\":\"${SEQ_ADMIN_PASSWORD}\"}")" || true
  csrf="$(printf '%s' "$body" | sed -n 's/.*"CsrfToken":"\([^"]*\)".*/\1/p')"
  if [ -z "$csrf" ]; then
    echo "[boot] admin login failed, API key not seeded: $(printf '%s' "$body" | head -c 200)" >&2
    return 1
  fi
  if curl -sS -b "$jar" "$base/api/apikeys" -H "X-Seq-CsrfToken: $csrf" | grep -q "\"TokenPrefix\":\"${SEQ_API_KEY:0:4}\""; then
    echo "[boot] API key already present"
    return 0
  fi
  code="$(curl -sS -o /tmp/apikey.out -w '%{http_code}' -b "$jar" -X POST "$base/api/apikeys" \
    -H 'Content-Type: application/json' -H "X-Seq-CsrfToken: $csrf" \
    --data "{\"Title\":\"${KEY_TITLE}\",\"Token\":\"${SEQ_API_KEY}\",\"AssignedPermissions\":[\"Ingest\",\"Read\",\"Write\"]}")"
  if [ "$code" != "201" ]; then
    echo "[boot] API key create returned $code: $(head -c 300 /tmp/apikey.out)" >&2
    return 1
  fi
  echo "[boot] API key created"
}

# Phase 1: loopback only.
seqsvr config set -k api.listenUris -v "http://127.0.0.1:${BOOT_PORT}" >/dev/null
seqsvr >/tmp/seq-boot.log 2>&1 &
SEQ_PID=$!
if ! provision; then
  tail -n 20 /tmp/seq-boot.log >&2 || true
  kill "$SEQ_PID" 2>/dev/null || true
  wait "$SEQ_PID" 2>/dev/null || true
  exit 1
fi
kill -TERM "$SEQ_PID" 2>/dev/null || true
wait "$SEQ_PID" 2>/dev/null || true

# Phase 2: the real listener. [::] is dual-stack in Kestrel, so IPv4 and the IPv6 private network both work.
seqsvr config set -k api.listenUris -v "http://[::]:${LISTEN_PORT}" >/dev/null
exec seqsvr
