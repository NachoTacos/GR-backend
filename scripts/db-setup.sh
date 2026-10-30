#!/usr/bin/env bash
# =====================================================================
# Crea la base de datos local de Grupo Ricartti (sin Docker).
#   1. Lee la configuración de .env (raíz del repositorio).
#   2. Crea el rol de la aplicación y la base de datos (si no existen).
#   3. Carga el esquema y los datos de prueba (o el volcado con --from-dump).
#
# Funciona en macOS, Linux y Git Bash (Windows).
#
# Uso:
#   ./scripts/db-setup.sh              # instalación normal
#   ./scripts/db-setup.sh --reset      # borra y recrea la base
#   ./scripts/db-setup.sh --from-dump  # carga database/dump/ricartti_dump.sql
# =====================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SQL_DIR="$REPO_ROOT/database/sql"
RESET=false
FROM_DUMP=false

for arg in "$@"; do
  case "$arg" in
    --reset)     RESET=true ;;
    --from-dump) FROM_DUMP=true ;;
    *) echo "Opción desconocida: $arg" >&2; exit 1 ;;
  esac
done

fail() { printf '\nERROR: %s\n' "$1" >&2; exit 1; }
step() { printf '\n==> %s\n' "$1"; }

# --- 1. Leer .env (sin ejecutarlo como script) -------------------------
ENV_FILE="$REPO_ROOT/.env"
[ -f "$ENV_FILE" ] || fail "No existe .env. Copia .env.example como .env y edita las contraseñas:  cp .env.example .env"

get_setting() {
  # Devuelve el valor de la clave $1 en .env, o $2 si no existe o está vacía.
  local value
  value="$(grep -E "^[[:space:]]*$1=" "$ENV_FILE" | tail -n 1 | cut -d '=' -f 2- | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')" || true
  printf '%s' "${value:-${2:-}}"
}

DB_HOST="$(get_setting DB_HOST localhost)"
DB_PORT="$(get_setting DB_PORT 5432)"
DB_NAME="$(get_setting DB_NAME)"
DB_USER="$(get_setting DB_USER)"
DB_PASSWORD="$(get_setting DB_PASSWORD)"
ADMIN_USER="$(get_setting DB_ADMIN_USER postgres)"
ADMIN_PASSWORD="$(get_setting DB_ADMIN_PASSWORD)"

[ -n "$DB_NAME" ]     || fail "Falta DB_NAME en .env"
[ -n "$DB_USER" ]     || fail "Falta DB_USER en .env"
[ -n "$DB_PASSWORD" ] || fail "Falta DB_PASSWORD en .env"
for pair in "DB_NAME=$DB_NAME" "DB_USER=$DB_USER"; do
  [[ "${pair#*=}" =~ ^[a-z_][a-z0-9_]{0,62}$ ]] \
    || fail "${pair%%=*} solo admite minúsculas, números y guion bajo (valor actual: '${pair#*=}')"
done

# --- 2. Localizar psql -------------------------------------------------
IS_GIT_BASH=false
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) IS_GIT_BASH=true ;; esac

PSQL="$(command -v psql || true)"
if [ -z "$PSQL" ] && [ -x "/Applications/Postgres.app/Contents/Versions/latest/bin/psql" ]; then
  PSQL="/Applications/Postgres.app/Contents/Versions/latest/bin/psql"
fi
if [ -z "$PSQL" ] && [ "$IS_GIT_BASH" = true ]; then
  # Instalador oficial de Windows: elige la versión más reciente.
  PSQL="$(ls -1d "/c/Program Files/PostgreSQL/"*/bin/psql.exe 2>/dev/null | sort -V | tail -n 1 || true)"
fi
[ -n "$PSQL" ] || fail "No se encontró psql. Instala PostgreSQL (ver README) o agrega su carpeta bin al PATH."
echo "Usando psql: $PSQL"

# En Git Bash, psql.exe no puede mostrar la solicitud de contraseña y se queda
# esperando: la contraseña debe venir de .env.
if [ "$IS_GIT_BASH" = true ] && [ -z "$ADMIN_PASSWORD" ]; then
  fail "En Git Bash debes definir DB_ADMIN_PASSWORD en .env (psql no puede pedir la contraseña en esta terminal)."
fi

export PGHOST="$DB_HOST" PGPORT="$DB_PORT" PGUSER="$ADMIN_USER" PGCLIENTENCODING="UTF8"
if [ -n "$ADMIN_PASSWORD" ]; then export PGPASSWORD="$ADMIN_PASSWORD"; else unset PGPASSWORD || true; fi
trap 'unset PGPASSWORD' EXIT

run_psql() { "$PSQL" -X -v ON_ERROR_STOP=1 "$@"; }

# --- 3. Probar conexión ------------------------------------------------
step "Probando conexión a PostgreSQL en $DB_HOST:$DB_PORT como '$ADMIN_USER'..."
run_psql -d postgres -tAc 'SELECT version()'

# --- 4. Reset opcional -------------------------------------------------
if [ "$RESET" = true ]; then
  step "Borrando la base '$DB_NAME' (--reset)..."
  run_psql -d postgres -c "DROP DATABASE IF EXISTS $DB_NAME WITH (FORCE)"
fi

# --- 5. Rol y base de datos --------------------------------------------
step "Creando rol '$DB_USER' y base '$DB_NAME' (si no existen)..."
run_psql -d postgres \
  -v db_name="$DB_NAME" -v db_user="$DB_USER" -v db_password="$DB_PASSWORD" \
  -f "$SQL_DIR/00_create_role_and_db.sql"

# --- 6. Esquema y datos ------------------------------------------------
EXISTS="$(run_psql -d "$DB_NAME" -tAc "SELECT to_regclass('public.projects') IS NOT NULL")"
if [ "$EXISTS" = "t" ]; then
  printf "\nLa base '%s' ya tiene el esquema. No se modificó nada.\n" "$DB_NAME"
  printf "Para recrearla desde cero ejecuta: ./scripts/db-setup.sh --reset\n"
  exit 0
fi

if [ "$FROM_DUMP" = true ]; then
  DUMP_FILE="$REPO_ROOT/database/dump/ricartti_dump.sql"
  [ -f "$DUMP_FILE" ] || fail "No existe $DUMP_FILE"
  step "Cargando el volcado ricartti_dump.sql..."
  run_psql -d "$DB_NAME" -c "SET ROLE $DB_USER" -f "$DUMP_FILE"
else
  step "Creando esquema y cargando datos de prueba..."
  run_psql -d "$DB_NAME" -c "SET ROLE $DB_USER" \
    -f "$SQL_DIR/01_schema.sql" \
    -f "$SQL_DIR/02_seed.sql"
fi

# --- 7. Verificación ---------------------------------------------------
step "Verificando..."
run_psql -d "$DB_NAME" -c "SELECT (SELECT count(*) FROM admins) AS admins, (SELECT count(*) FROM projects) AS proyectos, (SELECT count(*) FROM projects WHERE is_visible) AS visibles, (SELECT count(*) FROM project_evidences) AS evidencias, (SELECT count(*) FROM blog_posts) AS entradas_blog, (SELECT count(*) FROM blog_posts WHERE status = 'published' AND published_at <= now()) AS blog_publicas"

printf "\nBase de datos '%s' lista.\n" "$DB_NAME"
