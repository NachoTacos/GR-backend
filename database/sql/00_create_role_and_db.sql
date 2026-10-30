-- =====================================================================
-- Grupo Ricartti — 00: rol de la aplicación y base de datos
-- ---------------------------------------------------------------------
-- Se ejecuta como superusuario conectado a la base "postgres".
-- Es idempotente: si el rol o la base ya existen, no hace nada.
-- No contiene secretos: los valores llegan como variables de psql.
--
--   psql -U postgres -d postgres \
--        -v db_name=ricartti -v db_user=ricartti_app -v db_password=*** \
--        -f database/sql/00_create_role_and_db.sql
-- =====================================================================
\set ON_ERROR_STOP on

-- Rol de la aplicación: puede iniciar sesión, NO es superusuario.
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE',
              :'db_user', :'db_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'db_user')
\gexec

-- Si el rol ya existía, se sincroniza su contraseña con la del .env.
SELECT format('ALTER ROLE %I PASSWORD %L', :'db_user', :'db_password')
\gexec

-- Base de datos propiedad del rol de la aplicación.
SELECT format('CREATE DATABASE %I OWNER %I ENCODING %L TEMPLATE template0', :'db_name', :'db_user', 'UTF8')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'db_name')
\gexec

-- Nadie más que el dueño puede conectarse.
SELECT format('REVOKE ALL ON DATABASE %I FROM PUBLIC', :'db_name')
\gexec
