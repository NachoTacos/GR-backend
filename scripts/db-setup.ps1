<#
.SYNOPSIS
  Crea la base de datos local de Grupo Ricartti (sin Docker).

.DESCRIPTION
  1. Lee la configuracion de .env (raiz del repositorio).
  2. Crea el rol de la aplicacion y la base de datos (si no existen).
  3. Carga el esquema y los datos de prueba (o el volcado con -FromDump).

.PARAMETER Reset
  Borra la base de datos y la vuelve a crear desde cero.

.PARAMETER FromDump
  Carga database/dump/ricartti_dump.sql en lugar de schema + seed.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\db-setup.ps1
  powershell -ExecutionPolicy Bypass -File scripts\db-setup.ps1 -Reset
#>
param(
    [switch]$Reset,
    [switch]$FromDump
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot

function Fail([string]$Message) {
    Write-Host ""
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit 1
}

function Step([string]$Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

# --- 1. Leer .env -------------------------------------------------------
$EnvFile = Join-Path $RepoRoot '.env'
if (-not (Test-Path $EnvFile)) {
    Fail "No existe .env. Copia .env.example como .env y edita las contrasenas:  Copy-Item .env.example .env"
}

$Config = @{}
foreach ($line in Get-Content $EnvFile -Encoding UTF8) {
    $trimmed = $line.Trim()
    if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }
    $idx = $trimmed.IndexOf('=')
    if ($idx -lt 1) { continue }
    $Config[$trimmed.Substring(0, $idx).Trim()] = $trimmed.Substring($idx + 1).Trim()
}

function Get-Setting([string]$Key, [string]$Default = $null, [switch]$Required) {
    $value = $Config[$Key]
    if ([string]::IsNullOrEmpty($value)) { $value = $Default }
    if ($Required -and [string]::IsNullOrEmpty($value)) { Fail "Falta la variable $Key en .env" }
    return $value
}

$DbHost      = Get-Setting 'DB_HOST' 'localhost'
$DbPort      = Get-Setting 'DB_PORT' '5432'
$DbName      = Get-Setting 'DB_NAME' -Required
$DbUser      = Get-Setting 'DB_USER' -Required
$DbPassword  = Get-Setting 'DB_PASSWORD' -Required
$AdminUser   = Get-Setting 'DB_ADMIN_USER' 'postgres'
$AdminPass   = Get-Setting 'DB_ADMIN_PASSWORD'

foreach ($pair in @(@('DB_NAME', $DbName), @('DB_USER', $DbUser))) {
    if ($pair[1] -notmatch '^[a-z_][a-z0-9_]{0,62}$') {
        Fail "$($pair[0]) solo admite minusculas, numeros y guion bajo (valor actual: '$($pair[1])')"
    }
}

# --- 2. Localizar psql --------------------------------------------------
$Psql = (Get-Command psql -ErrorAction SilentlyContinue).Source
if (-not $Psql) {
    $candidates = Get-ChildItem 'C:\Program Files\PostgreSQL\*\bin\psql.exe' -ErrorAction SilentlyContinue |
        Sort-Object { [int]($_.Directory.Parent.Name -replace '\D', '') } -Descending
    if ($candidates) { $Psql = $candidates[0].FullName }
}
if (-not $Psql) {
    Fail "No se encontro psql. Instala PostgreSQL (ver README) o agrega su carpeta bin al PATH."
}
Write-Host "Usando psql: $Psql"

# Conexion como superusuario. Si no hay contrasena en .env, psql la pedira.
$env:PGHOST = $DbHost
$env:PGPORT = $DbPort
$env:PGUSER = $AdminUser
$env:PGCLIENTENCODING = 'UTF8'
if ($AdminPass) { $env:PGPASSWORD = $AdminPass } else { Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue }

function Invoke-Psql([string[]]$Arguments) {
    & $Psql -v ON_ERROR_STOP=1 -X @Arguments
    if ($LASTEXITCODE -ne 0) { Fail "psql termino con codigo $LASTEXITCODE (ver mensaje anterior)." }
}

$SqlDir = Join-Path $RepoRoot 'database\sql'

try {
    # --- 3. Probar conexion ---------------------------------------------
    Step "Probando conexion a PostgreSQL en ${DbHost}:${DbPort} como '$AdminUser'..."
    Invoke-Psql @('-d', 'postgres', '-tAc', 'SELECT version()')

    # --- 4. Reset opcional ----------------------------------------------
    if ($Reset) {
        Step "Borrando la base '$DbName' (-Reset)..."
        Invoke-Psql @('-d', 'postgres', '-c', "DROP DATABASE IF EXISTS $DbName WITH (FORCE)")
    }

    # --- 5. Rol y base de datos -----------------------------------------
    Step "Creando rol '$DbUser' y base '$DbName' (si no existen)..."
    Invoke-Psql @('-d', 'postgres',
        '-v', "db_name=$DbName", '-v', "db_user=$DbUser", '-v', "db_password=$DbPassword",
        '-f', (Join-Path $SqlDir '00_create_role_and_db.sql'))

    # --- 6. Esquema y datos ---------------------------------------------
    $exists = (& $Psql -X -d $DbName -tAc "SELECT to_regclass('public.projects') IS NOT NULL").Trim()
    if ($LASTEXITCODE -ne 0) { Fail "No se pudo consultar la base '$DbName'." }
    if ($exists -eq 't') {
        Write-Host ""
        Write-Host "La base '$DbName' ya tiene el esquema. No se modifico nada." -ForegroundColor Yellow
        Write-Host "Para recrearla desde cero ejecuta el script con -Reset." -ForegroundColor Yellow
        exit 0
    }

    if ($FromDump) {
        $DumpFile = Join-Path $RepoRoot 'database\dump\ricartti_dump.sql'
        if (-not (Test-Path $DumpFile)) { Fail "No existe $DumpFile" }
        Step "Cargando el volcado ricartti_dump.sql..."
        Invoke-Psql @('-d', $DbName, '-c', "SET ROLE $DbUser", '-f', $DumpFile)
    }
    else {
        Step "Creando esquema y cargando datos de prueba..."
        Invoke-Psql @('-d', $DbName, '-c', "SET ROLE $DbUser",
            '-f', (Join-Path $SqlDir '01_schema.sql'),
            '-f', (Join-Path $SqlDir '02_seed.sql'))
    }

    # --- 7. Verificacion ------------------------------------------------
    Step "Verificando..."
    Invoke-Psql @('-d', $DbName, '-c',
        "SELECT (SELECT count(*) FROM admins) AS admins, (SELECT count(*) FROM projects) AS proyectos, (SELECT count(*) FROM projects WHERE is_visible) AS visibles, (SELECT count(*) FROM project_evidences) AS evidencias, (SELECT count(*) FROM blog_posts) AS entradas_blog, (SELECT count(*) FROM blog_posts WHERE status = 'published' AND published_at <= now()) AS blog_publicas")

    Write-Host ""
    Write-Host "Base de datos '$DbName' lista." -ForegroundColor Green
}
finally {
    Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
}
