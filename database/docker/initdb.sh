#!/bin/sh
# =====================================================================
# Primer arranque del contenedor de PostgreSQL.
# La imagen oficial ejecuta este script UNA sola vez, cuando el volumen
# de datos está vacío. Usa los mismos scripts SQL que la instalación local.
# Para volver a ejecutarlo: docker compose down -v && docker compose up
# =====================================================================
# Solo "set -e": si la imagen ejecuta el script con "source", un "set -u"
# afectaría al entrypoint de PostgreSQL.
set -e

: "${APP_DB_NAME:?APP_DB_NAME no está definida (DB_NAME en .env)}"
: "${APP_DB_USER:?APP_DB_USER no está definida (DB_USER en .env)}"
: "${APP_DB_PASSWORD:?APP_DB_PASSWORD no está definida (DB_PASSWORD en .env)}"

echo "[ricartti] Creando rol '${APP_DB_USER}' y base '${APP_DB_NAME}'..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres \
     -v db_name="$APP_DB_NAME" -v db_user="$APP_DB_USER" -v db_password="$APP_DB_PASSWORD" \
     -f /sql/00_create_role_and_db.sql

echo "[ricartti] Creando esquema y cargando datos de prueba..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$APP_DB_NAME" \
     -c "SET ROLE \"${APP_DB_USER}\"" \
     -f /sql/01_schema.sql \
     -f /sql/02_seed.sql

echo "[ricartti] Base de datos lista."
