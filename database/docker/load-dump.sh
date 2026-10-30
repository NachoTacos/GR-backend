#!/bin/sh
# =====================================================================
# Recrea la base de la aplicación a partir del volcado, dentro del
# contenedor de PostgreSQL:
#   docker compose exec db sh /docker-scripts/load-dump.sh
# =====================================================================
set -e

DUMP_FILE=/dump/ricartti_dump.sql
[ -f "$DUMP_FILE" ] || { echo "No existe $DUMP_FILE" >&2; exit 1; }

echo "[ricartti] Borrando la base '${APP_DB_NAME}'..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres \
     -c "DROP DATABASE IF EXISTS \"${APP_DB_NAME}\" WITH (FORCE)"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres \
     -v db_name="$APP_DB_NAME" -v db_user="$APP_DB_USER" -v db_password="$APP_DB_PASSWORD" \
     -f /sql/00_create_role_and_db.sql

echo "[ricartti] Cargando el volcado..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$APP_DB_NAME" \
     -c "SET ROLE \"${APP_DB_USER}\"" \
     -f "$DUMP_FILE"

echo "[ricartti] Volcado cargado."
