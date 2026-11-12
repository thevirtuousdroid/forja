#!/usr/bin/env bash
# Sobe um Postgres temporário, aplica as migrações e roda os testes.
# Requer os binários do PostgreSQL (initdb, pg_ctl, psql) no PATH ou em /usr/lib/postgresql/*/bin.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
PGBIN="$(dirname "$(ls /usr/lib/postgresql/*/bin/initdb 2>/dev/null | tail -1)")"
export PATH="$PGBIN:$PATH"

DATA="$(mktemp -d)"
PORT=54329
RUN_AS=""
if [ "$(id -u)" = "0" ]; then
  chown -R postgres "$DATA"
  RUN_AS="runuser -u postgres --"
fi

$RUN_AS initdb -D "$DATA" -A trust -U postgres >/dev/null
$RUN_AS pg_ctl -D "$DATA" -o "-p $PORT -k /tmp" -l "$DATA/log" start >/dev/null
trap '$RUN_AS pg_ctl -D "$DATA" stop -m fast >/dev/null; rm -rf "$DATA"' EXIT

PSQL="psql -h /tmp -p $PORT -U postgres -d postgres -v ON_ERROR_STOP=1 -q"
$PSQL -f "$HERE/00_supabase_stub.sql"
for f in "$ROOT"/migrations/*.sql; do
  echo "→ $(basename "$f")"
  $PSQL -f "$f"
done
for t in "$HERE"/[0-9][0-9]_*_test.sql; do
  echo "→ $(basename "$t")"
  $PSQL -f "$t"
done
