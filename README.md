# GR-backend — Grupo Ricartti

API, base de datos y entorno Docker de la landing de Grupo Ricartti: galería de proyectos, blog, formulario para clientes, formulario para talento y panel de administración protegido.

El sistema está repartido en **dos repositorios**:

| Repositorio | Contenido | Tecnología |
|---|---|---|
| **GR-backend** (este) | API, base de datos, scripts, imágenes de prueba, Docker Compose y documentación de arquitectura | ASP.NET Core 10 · PostgreSQL 17 |
| **GR-frontend** | Sitio público bilingüe (ES/EN) y panel de administración | Angular · CSS con los tokens del handoff |

> **Esta es la guía principal para ejecutar el sistema completo.** El README de GR-frontend solo cubre los detalles propios del frontend.
>
> **No necesitas saber .NET.** Basta con copiar los comandos de esta guía, en orden.

### Estado del desarrollo (por lotes)

El sistema se construye y se prueba por lotes. Cada lote amplía lo que se puede verificar con esta guía:

| Lote | Contenido | Estado | Cómo probarlo |
|---|---|---|---|
| **1. Base de datos** | Esquema, datos de prueba del handoff, volcado, scripts Docker y local | ✅ Listo | §4 con `docker compose up db`, §5.3 y §8 |
| **2. API pública** | Solución .NET en capas, salud, categorías, proyectos, imágenes, cabeceras de seguridad, límite global, Docker de la API | ✅ Listo | Sección «API pública (lote 2)» de §6 |
| **3. Formularios y protección** | Leads de clientes y talento, validación 422, honeypot, CV privado en PDF, límite de peticiones (5 por 15 min) | ✅ Listo | Sección «Formularios (lote 3)» de §6 |
| 4. Autenticación y API del panel | Login con sesión, bloqueo, antiforgery (CSRF), `/api/admin/projects` (crear, editar, ocultar), bandejas de leads y descarga de CV | ⏳ Pendiente | |
| 5. Blog (API) | Entradas ES/EN, Markdown saneado, programación, vista previa | ⏳ Pendiente | |
| 6. Frontend público | Landing, galería, detalle, preferencias, 404, Nginx y `docker compose up --build` completo | ⏳ Pendiente | |
| 7. Frontend: formularios y panel | Formularios, login, lista y editor de proyectos, blog | ⏳ Pendiente | |
| 8. Cierre | Pruebas automatizadas, axe, revisión final de las guías | ⏳ Pendiente | |

Mientras un lote esté pendiente, los pasos que dependen de él todavía no funcionan. Por ejemplo, `docker compose up --build` completo requiere los lotes 2 y 6.

---

## Contenido

1. [Clonar los dos repositorios](#1-clonar-los-dos-repositorios)
2. [Elige cómo ejecutarlo](#2-elige-cómo-ejecutarlo)
3. [Credenciales de prueba](#3-credenciales-de-prueba)
4. [Opción A — Docker](#4-opción-a--docker-recomendada)
5. [Opción B — Instalación local sin Docker](#5-opción-b--instalación-local-sin-docker)
6. [Comprobar que todo funciona](#6-comprobar-que-todo-funciona)
7. [Variables de entorno](#7-variables-de-entorno)
8. [Cargar el volcado (sql.dump)](#cargar-el-volcado-sqldump)
9. [Estructura y documentación](#9-estructura-y-documentación)
10. [Solución de problemas](#10-solución-de-problemas)

---

## 1. Clonar los dos repositorios

Los dos repositorios deben quedar **uno al lado del otro**, dentro de la misma carpeta y con estos nombres exactos:

```
grupo-ricartti/          ← carpeta contenedora (no es un repositorio)
├── GR-backend/
└── GR-frontend/
```

Docker Compose construye el frontend a partir de `../GR-frontend`, por eso importa esta ubicación.

```bash
mkdir grupo-ricartti
cd grupo-ricartti
git clone https://github.com/NachoTacos/GR-backend.git  GR-backend
git clone https://github.com/NachoTacos/GR-frontend.git GR-frontend
```

> Si necesitas otra ubicación, indica la ruta del frontend en `FRONTEND_PATH` dentro de `GR-backend/.env`.

Si todavía no tienes Git: en Windows, `winget install -e --id Git.Git`; en macOS, `xcode-select --install`.

---

## 2. Elige cómo ejecutarlo

| | **Opción A: Docker** | **Opción B: Local** |
|---|---|---|
| Qué instalas | Git y Docker Desktop | Git, .NET 10 SDK, Node.js y PostgreSQL |
| Dónde ejecutas | Una terminal, en `GR-backend` | Dos terminales: `GR-backend` (API) y `GR-frontend` (sitio) |
| Dirección del sitio | http://localhost:8080 | http://localhost:4200 |
| Recomendado para | Probar el proyecto | Desarrollar |

Usa **una** de las dos opciones. Puedes tener ambas instaladas: Docker expone PostgreSQL en el puerto `5433`, así que no choca con una instalación local en el `5432`.

### ¿Qué terminal usar en Windows?

Todos los comandos funcionan en **PowerShell** y en **Git Bash** (la terminal que se instala con Git). Cuando un comando cambia según la terminal, la guía muestra ambas versiones:

| Bloque marcado como | Úsalo en |
|---|---|
| `# Windows (PowerShell)` | PowerShell o Windows Terminal |
| `# macOS / Linux / Git Bash` | Terminal de macOS o Linux, o **Git Bash en Windows** |
| Sin marca | Cualquier terminal |

Para usar Git Bash en Windows: abre la carpeta `grupo-ricartti` en el Explorador, haz clic derecho y elige **Open Git Bash here** (en Windows 11, primero *Mostrar más opciones*).

---

## 3. Credenciales de prueba

Panel de administración: **`/admin/login`**. El menú lateral tiene tres secciones: **Proyectos**, **Blog** y **Mensajes**.

| Correo | Contraseña | Estado |
|---|---|---|
| `admin@gruporicartti.test` | `Ricartti#Admin2026` | Activo |
| `operaciones@gruporicartti.test` | `Ricartti#Ops2026` | Activo |
| `inactivo@gruporicartti.test` | `Ricartti#Inactivo2026` | **Desactivado**: el inicio de sesión debe fallar |

Todos tienen los mismos permisos. En la base de datos solo se guarda el hash bcrypt de cada contraseña. **Todos los datos de prueba son ficticios.**

---

## 4. Opción A — Docker (recomendada)

Con Docker no hace falta instalar .NET, Node.js ni PostgreSQL: todo se compila y ejecuta dentro de contenedores.

### 4.1 Instalar los requisitos (una sola vez)

| Sistema | Pasos |
|---|---|
| **Windows 10/11** | 1. Abre PowerShell **como administrador** y ejecuta `wsl --install`. Reinicia el equipo.<br>2. `winget install -e --id Docker.DockerDesktop`<br>3. Abre **Docker Desktop** y espera a que indique *Engine running*. |
| **macOS** | Instala [Docker Desktop](https://www.docker.com/products/docker-desktop/) y ábrelo. |
| **Linux** | Instala [Docker Engine y el plugin Compose](https://docs.docker.com/engine/install/). |

Comprueba la instalación con `docker --version` y `docker compose version`. Los dos comandos deben mostrar una versión.

### 4.2 Ejecutar

Todos los comandos de esta opción se ejecutan **dentro de `GR-backend`**:

```bash
cd GR-backend
```

> **Importante:** abre la terminal **sin** permisos de administrador; solo `wsl --install` los necesita. PowerShell como administrador arranca en `C:\Windows\system32` y `docker compose` responde `no configuration file provided: not found`.
>
> Si la terminal no está en la carpeta contenedora, entra con la ruta completa, por ejemplo:
>
> - PowerShell: `cd "$HOME\OneDrive\Documentos\grupo-ricartti\GR-backend"`
> - Git Bash: `cd ~/OneDrive/Documentos/grupo-ricartti/GR-backend`
>
> También puedes abrir la carpeta `GR-backend` en el Explorador, escribir `powershell` en la barra de direcciones y pulsar Enter.

Crea el archivo de configuración a partir de la plantilla:

```powershell
# Windows (PowerShell)
Copy-Item .env.example .env
```

```bash
# macOS / Linux / Git Bash
cp .env.example .env
```

Abre `.env` con cualquier editor y **cambia las dos contraseñas** marcadas con `CAMBIAR` (`DB_PASSWORD` y `DB_ADMIN_PASSWORD`). Puedes inventarlas; solo se usan en tu equipo. El resto de valores ya funciona tal cual.

Levanta todo:

```bash
docker compose up --build
```

La primera vez tarda unos minutos porque descarga imágenes y compila la API y el frontend. Cuando la terminal deje de avanzar y muestre mensajes de la API (`Now listening on: http://[::]:8080`), abre:

- **Sitio:** http://localhost:8080
- **Blog:** http://localhost:8080/blog
- **Panel:** http://localhost:8080/admin/login
- **Estado de la API:** http://localhost:8080/api/health

La base de datos se crea y se llena con los datos de prueba **automáticamente** en el primer arranque.

> **Para desarrollar el frontend sin instalar .NET:** levanta solo la base y la API con `docker compose up --build db api` (la API queda en http://localhost:5080) y ejecuta `npm start` en GR-frontend. Consulta su README.

### 4.3 Detener, reiniciar y empezar de cero

| Acción | Comando (en `GR-backend`) |
|---|---|
| Detener | `Ctrl + C` en la terminal, o `docker compose down` |
| Volver a levantar (conserva los datos) | `docker compose up` |
| Aplicar cambios después de un `git pull` en cualquiera de los repositorios | `docker compose up --build` |
| **Borrar la base y recargar los datos de prueba** | `docker compose down -v` y luego `docker compose up --build` |

---

## 5. Opción B — Instalación local sin Docker

### 5.1 Instalar los requisitos (una sola vez)

<details open>
<summary><strong>Windows 10/11</strong></summary>

En PowerShell:

```powershell
winget install -e --id Microsoft.DotNet.SDK.10
winget install -e --id OpenJS.NodeJS.LTS
winget install -e --id PostgreSQL.PostgreSQL.17 --interactive
```

Durante la instalación de PostgreSQL:

- **Anota la contraseña que definas para el usuario `postgres`.** La necesitarás en el paso 5.2.
- Deja el puerto en `5432`.
- Puedes omitir *Stack Builder*.

Si prefieres el instalador gráfico, descárgalo de [postgresql.org/download/windows](https://www.postgresql.org/download/windows/).

**Cierra y vuelve a abrir la terminal** (PowerShell o Git Bash) para que reconozca los nuevos programas. Los comandos `winget` también funcionan desde Git Bash.
</details>

<details>
<summary><strong>macOS (Homebrew)</strong></summary>

```bash
brew install node postgresql@17
brew install --cask dotnet-sdk
brew services start postgresql@17
```

Con Homebrew, el superusuario de PostgreSQL es **tu usuario de macOS y no tiene contraseña**. En `.env` usa `DB_ADMIN_USER=<tu usuario>` (el resultado de `whoami`) y deja `DB_ADMIN_PASSWORD=` vacío.
</details>

<details>
<summary><strong>Linux (Ubuntu/Debian)</strong></summary>

Instala [.NET 10 SDK](https://learn.microsoft.com/dotnet/core/install/linux), [Node.js LTS](https://nodejs.org/) y PostgreSQL:

```bash
sudo apt install postgresql
# Asigna una contraseña al usuario postgres (la usarás en DB_ADMIN_PASSWORD):
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'tu_contrasena'"
```
</details>

Comprueba la instalación. Los tres comandos deben mostrar una versión:

```bash
dotnet --version      # 10.x
node --version        # 22 o superior
npm --version
```

### 5.2 Configurar el backend

```bash
cd GR-backend
```

```powershell
# Windows (PowerShell)
Copy-Item .env.example .env
```

```bash
# macOS / Linux / Git Bash
cp .env.example .env
```

Edita `GR-backend/.env`:

- `DB_ADMIN_PASSWORD`: la contraseña del usuario `postgres` que definiste al instalar PostgreSQL. En PowerShell, macOS y Linux puedes dejarla vacía y el script te la pedirá. **En Git Bash es obligatoria**, porque esa terminal no puede mostrar la solicitud de contraseña.
- `DB_PASSWORD`: inventa una contraseña para el usuario de la aplicación. El script lo crea con ella.

### 5.3 Crear la base de datos (en `GR-backend`)

```powershell
# Windows (PowerShell)
powershell -ExecutionPolicy Bypass -File scripts\db-setup.ps1
```

```bash
# macOS / Linux / Git Bash
bash scripts/db-setup.sh
```

El script crea el usuario `ricartti_app` y la base `ricartti`, carga el esquema y los datos de prueba, y termina mostrando un conteo de registros con el mensaje **"Base de datos 'ricartti' lista."** En Git Bash encuentra `psql` automáticamente en `C:\Program Files\PostgreSQL`.

Para borrarla y empezar de cero, usa `-Reset` en PowerShell o `--reset` en Bash (`bash scripts/db-setup.sh --reset`).

### 5.4 Ejecutar la API — terminal 1 (en `GR-backend`)

```bash
dotnet run --project src/Ricartti.Api
```

Espera a ver `Now listening on: http://localhost:5080`. Comprueba que responde abriendo http://localhost:5080/api/health. **Deja esta terminal abierta.**

### 5.5 Ejecutar el frontend — terminal 2 (en `GR-frontend`)

Abre otra terminal **en la carpeta `GR-frontend`**:

```bash
cd ../GR-frontend
npm install
npm start
```

El frontend no necesita `.env`: en desarrollo reenvía `/api` y `/uploads` a `http://localhost:5080`. Cuando aparezca `Local: http://localhost:4200/`, abre:

- **Sitio:** http://localhost:4200
- **Blog:** http://localhost:4200/blog
- **Panel:** http://localhost:4200/admin/login

Para detener cualquiera de los dos procesos, pulsa `Ctrl + C` en su terminal.

---

## 6. Comprobar que todo funciona

Cada bloque indica el lote a partir del cual se puede comprobar (ver [Estado del desarrollo](#estado-del-desarrollo-por-lotes)). Sustituye `<sitio>` por `http://localhost:8080` (Docker) o `http://localhost:4200` (local).

**Base de datos (lote 1)**

Con Docker, ejecuta `docker compose up -d db` y luego este comando en `GR-backend`. En Git Bash, antepón `MSYS_NO_PATHCONV=1`:

```bash
docker compose exec db psql -U postgres -d ricartti -c "SELECT (SELECT count(*) FROM categories) AS categorias, (SELECT count(*) FROM projects WHERE is_visible) AS visibles, (SELECT count(*) FROM projects) AS proyectos, (SELECT count(*) FROM blog_posts) AS entradas"
```

- [ ] Responde `categorias = 3`, `visibles = 6`, `proyectos = 7` y `entradas = 6`. En la instalación local, el script de §5.3 muestra el mismo conteo al terminar.
- [ ] Los logs del contenedor (`docker compose logs db`) terminan con `[ricartti] Base de datos lista.` y no muestran errores.
- [ ] Cargar el volcado (§8) termina con `Volcado cargado.` y deja los mismos conteos.

**API pública (lote 2)**

Con Docker, levanta la base y la API (la primera vez compila la imagen, unos minutos). Desde `GR-backend`:

```bash
docker compose up -d --build db api
```

La API queda en **http://localhost:5080**. Ábrelas en el navegador o con `curl`:

- [ ] http://localhost:5080/api/health responde `Healthy`.
- [ ] http://localhost:5080/api/categories devuelve 3 categorías (`fintech`, `agrotech`, `healthtech`) con `count` = 2 cada una.
- [ ] http://localhost:5080/api/projects devuelve **6 proyectos** (sin `ruta-fria`), con textos `{ "es": …, "en": … }`, `evidence`, `results` y `support`.
- [ ] http://localhost:5080/api/projects?category=agrotech devuelve 2 proyectos. `?category=no-existe` devuelve `[]`. `?category=DROP TABLE` devuelve **422** con `{"errors":{"category":"invalid"}}`.
- [ ] http://localhost:5080/api/projects/kuali-pagos devuelve el proyecto con 3 resultados y 3 evidencias. `/api/projects/ruta-fria` (oculto) y `/api/projects/no-existe` devuelven **404**.
- [ ] http://localhost:5080/uploads/seed/kuali-pagos/cover.webp muestra la imagen. `http://localhost:5080/uploads/../.env` devuelve 404.
- [ ] Las respuestas llevan `X-Content-Type-Options: nosniff` y no llevan la cabecera `Server`.
- [ ] Pedir `/api/categories` más de 120 veces en un minuto devuelve **429** con `Retry-After`.

Sin Docker (opción B), con la base ya creada en §5.3, usa `dotnet run --project src/Ricartti.Api` y las mismas direcciones.

**Sitio público (lotes 2 y 6)**

- [ ] `<sitio>/api/health` responde `Healthy`.
- [ ] La galería muestra **6 proyectos**. **Ruta Fría** no aparece porque está oculto.
- [ ] El filtro muestra **Todos + Fintech, Agrotech y Salud digital**, con 2 proyectos cada una, y actualiza `?categoria=` en la URL.
- [ ] `<sitio>/proyectos/kuali-pagos` abre el detalle con 3 resultados, 3 evidencias y sus áreas de respaldo. **Esc** lo cierra.
- [ ] `<sitio>/proyectos/ruta-fria` y cualquier ruta inexistente muestran la página 404.
- [ ] Preferencias cambia el idioma (ES/EN), el movimiento y la apariencia, y los cambios se conservan al recargar.

**Formularios (lote 3, API)**

Todavía no hay interfaz, así que se prueban con `curl` (viene con Windows 10/11, macOS y Linux). Desde `GR-backend`, con la API en marcha (`docker compose up -d --build db api`):

> **Importante:** los formularios admiten **5 envíos por IP cada 15 minutos** (compartidos entre los dos). Cada petición cuenta, también las que fallan por validación. Para repetir las pruebas, reinicia la API: `docker compose restart api`.

```powershell
# Windows (PowerShell) — usa curl.exe, no "curl" (en PowerShell 5.1 "curl" es otro comando).
# El JSON se guarda primero en un archivo: PowerShell 5.1 deforma las comillas si se pasa en la línea de comandos.
Set-Content -Path cliente.json -Encoding ascii -Value '{"name":"Laura Mendez","company":"Fondo Altiplano","email":"laura@ejemplo.test","interest":"acquire","message":"Quiero conocer los proyectos.","consent":true}'
curl.exe -i -X POST http://localhost:5080/api/leads/client -H "Content-Type: application/json" --data-binary "@cliente.json"
curl.exe -i -X POST http://localhost:5080/api/leads/client -H "Content-Type: application/json" --data-binary '{}'
curl.exe -i -X POST http://localhost:5080/api/leads/talent -F "name=Daniel Ortega" -F "email=daniel@ejemplo.test" -F "area=engineering" -F "consent=true"
Remove-Item cliente.json
```

```bash
# macOS / Linux / Git Bash
curl -i -X POST http://localhost:5080/api/leads/client -H "Content-Type: application/json" -d '{"name":"Laura Mendez","company":"Fondo Altiplano","email":"laura@ejemplo.test","interest":"acquire","message":"Quiero conocer los proyectos.","consent":true}'
curl -i -X POST http://localhost:5080/api/leads/client -H "Content-Type: application/json" -d '{}'
curl -i -X POST http://localhost:5080/api/leads/talent -F "name=Daniel Ortega" -F "email=daniel@ejemplo.test" -F "area=engineering" -F "consent=true"
```

- [ ] El primer comando responde `201 Created` con `{"id":…}`. El segundo (cuerpo vacío) responde **422** con `{"errors":{"name":"required","company":"required","email":"required","interest":"required","message":"required","consent":"consent"}}`. El tercero responde `201`.
- [ ] Un correo inválido da `"email":"email"`, un interés desconocido `"interest":"invalid"` y `"consent":false` da `"consent":"consent"`.
- [ ] Con el campo trampa `"website":"x"` la API responde `201`, pero **no guarda nada** (comprueba la tabla con el comando de abajo).
- [ ] El formulario de talento acepta un PDF real (`-F "cv=@mi-cv.pdf;type=application/pdf"`) y responde **422** `"cv":"file_type"` con cualquier otro tipo, aunque el archivo se llame `.pdf` pero no empiece con `%PDF-`. Un PDF de más de 5 MB responde **413**.
- [ ] Un enlace que no sea `http(s)://…` (`-F "link=javascript:alert(1)"`) da `"link":"url"`.
- [ ] El sexto envío en menos de 15 minutos responde **429** con `Retry-After: 900`.
- [ ] El CV se guarda en una carpeta **privada** (`private/cv/` en local; un volumen en Docker) con un nombre aleatorio. No existe ninguna dirección pública para descargarlo.

Para ver lo que se guardó:

```bash
docker compose exec db psql -U postgres -d ricartti -c "SELECT id, full_name, email, interest, lang, created_at FROM client_leads ORDER BY id DESC LIMIT 5"
docker compose exec db psql -U postgres -d ricartti -c "SELECT id, full_name, area, cv_original_name, cv_size_bytes FROM talent_applications ORDER BY id DESC LIMIT 5"
```

**Formularios (lote 7, interfaz)**

- [ ] Al enviar el formulario de clientes aparece "Solicitud recibida". Si lo envías con campos vacíos, se muestran los errores de cada campo.
- [ ] El formulario de talento acepta un CV en PDF y rechaza otros tipos de archivo o un PDF de más de 5 MB.
- [ ] Enviar un formulario más de 5 veces seguidas muestra **"Intenta de nuevo en unos minutos."** (límite de peticiones).

**Blog (lotes 5 y 7)**

- [ ] `<sitio>/blog` lista **3 entradas publicadas**, en el idioma activo.
- [ ] Filtrar por la etiqueta **Inversión** muestra 2 entradas.
- [ ] Una entrada se ve con formato (subtítulos, listas, imagen, enlaces), con su autor y su tiempo de lectura.
- [ ] `<sitio>/blog/agrotech-en-el-norte-de-mexico` (programada para 2030) muestra "no encontrado".

**Panel de administración (lotes 4 y 7)**

- [ ] `<sitio>/api/admin/projects` sin haber iniciado sesión responde **401**.
- [ ] Con `operaciones@gruporicartti.test` y una contraseña incorrecta aparece "Correo o contraseña incorrectos.". Al sexto intento en un minuto aparece "Demasiadas solicitudes", y esa cuenta queda bloqueada 15 minutos. Usa esta cuenta para la prueba, no la principal.
- [ ] `inactivo@gruporicartti.test` no puede entrar.
- [ ] Con `admin@gruporicartti.test` se ven 7 proyectos, incluido **Ruta Fría** (oculto).
- [ ] Al activar el interruptor de **Ruta Fría**, el proyecto aparece en la galería pública. Al desactivarlo, desaparece.
- [ ] Crear un proyecto con textos en ES y EN, resultados, áreas de respaldo, portada y evidencias funciona. Sin la versión en inglés, el interruptor de visibilidad no se activa.
- [ ] En **Blog** se ven 6 entradas con su estado: 3 Publicadas, 1 Programada, 1 Borrador y 1 Archivada.
- [ ] Crear una entrada, escribir Markdown, verla en **Vista previa**, subir portada y **Publicar ahora** hace que aparezca en `<sitio>/blog`.
- [ ] Escribir `<script>alert(1)</script>` en el contenido de una entrada lo muestra como texto, sin ejecutarse (protección XSS).
- [ ] Al **archivar** una entrada publicada, desaparece del blog público.
- [ ] Después de cerrar sesión, el panel vuelve a pedir credenciales.

---

## 7. Variables de entorno

Se definen en `GR-backend/.env`, que es una copia de [`.env.example`](.env.example). **`.env` nunca se sube al repositorio** porque está en `.gitignore`. Formato: `CLAVE=valor`, sin comillas. El frontend no tiene variables con secretos.

| Variable | Valor de ejemplo | Descripción |
|---|---|---|
| `DB_HOST` | `localhost` | Host de PostgreSQL. En Docker se sobrescribe con `db`. |
| `DB_PORT` | `5432` | Puerto de PostgreSQL local. |
| `DB_NAME` | `ricartti` | Nombre de la base de datos. |
| `DB_USER` | `ricartti_app` | Usuario que usa la API. No es superusuario. |
| `DB_PASSWORD` | *(la eliges tú)* | Contraseña de `DB_USER`. |
| `DB_ADMIN_USER` | `postgres` | Superusuario. Solo lo usan los scripts de instalación. |
| `DB_ADMIN_PASSWORD` | *(la eliges tú)* | Docker: se crea con este valor. Local: la contraseña de `postgres` que definiste al instalar. |
| `DB_DOCKER_HOST_PORT` | `5433` | Puerto del host donde Docker expone PostgreSQL. |
| `ASPNETCORE_ENVIRONMENT` | `Development` | Entorno de la API. |
| `API_PORT` | `5080` | Puerto de la API en el host, tanto en local como en Docker. Si lo cambias, actualiza también `proxy.conf.json` en GR-frontend. |
| `UPLOADS_PATH` | `uploads` | Carpeta de imágenes de proyectos y del blog, relativa a la raíz de GR-backend. |
| `UPLOAD_MAX_BYTES` | `5242880` | Tamaño máximo por imagen (5 MB). |
| `AUTH_COOKIE_NAME` | `ricartti_session` | Nombre de la cookie de sesión. |
| `AUTH_COOKIE_SECURE` | `true` | Marca la cookie como `Secure`. Ver [Solución de problemas](#10-solución-de-problemas). |
| `AUTH_SESSION_IDLE_MINUTES` | `30` | La sesión expira tras este tiempo sin actividad. |
| `AUTH_SESSION_ABSOLUTE_HOURS` | `8` | Duración máxima de una sesión. |
| `AUTH_MAX_FAILED_ATTEMPTS` | `5` | Intentos fallidos antes de bloquear la cuenta. |
| `AUTH_LOCKOUT_MINUTES` | `15` | Duración del bloqueo. |
| `RATE_LIMIT_LOGIN_PERMITS` / `_WINDOW_SECONDS` | `5` / `60` | Intentos de inicio de sesión por IP y ventana de tiempo. |
| `RATE_LIMIT_FORMS_PERMITS` / `_WINDOW_SECONDS` | `5` / `900` | Envíos de formulario por IP y ventana de tiempo. |
| `RATE_LIMIT_GLOBAL_PERMITS_PER_MINUTE` | `120` | Límite general de peticiones por IP. |
| `WEB_PORT` | `8080` | Puerto del sitio con Docker. |
| `FRONTEND_PATH` | `../GR-frontend` | Ruta al repositorio del frontend que usa Docker Compose. |
| `PRIVATE_FILES_PATH` | `private` | Carpeta **privada** de los CV en PDF del formulario de talento, relativa a la raíz de GR-backend. Nunca se sirve en `/uploads` y está en `.gitignore`. En Docker es un volumen con nombre. |

---

<a id="cargar-el-volcado-sqldump"></a>

## 8. Cargar el volcado (sql.dump)

[`database/dump/ricartti_dump.sql`](database/dump/ricartti_dump.sql) contiene el esquema y los datos de prueba en un solo archivo generado con `pg_dump`. Es una **alternativa** a los scripts `01_schema.sql` + `02_seed.sql`, y el resultado es idéntico. Todos los comandos se ejecutan en `GR-backend`.

**Instalación local:**

```powershell
# Windows (PowerShell)
powershell -ExecutionPolicy Bypass -File scripts\db-setup.ps1 -Reset -FromDump
```

```bash
# macOS / Linux / Git Bash
bash scripts/db-setup.sh --reset --from-dump
```

**Docker** (con los contenedores en marcha):

```powershell
# Windows (PowerShell), macOS / Linux
docker compose stop api
docker compose exec db sh /docker-scripts/load-dump.sh
docker compose start api
```

```bash
# Git Bash: MSYS_NO_PATHCONV=1 evita que Git Bash convierta la ruta del contenedor en una ruta de Windows
docker compose stop api
MSYS_NO_PATHCONV=1 docker compose exec db sh /docker-scripts/load-dump.sh
docker compose start api
```

Para regenerar el volcado, consulta [docs/DATABASE.md](docs/DATABASE.md#9-generar-el-volcado).

---

## 9. Estructura y documentación

```
GR-backend/
├── src/                      API ASP.NET Core (capas: Api, Application, Infrastructure, Domain)
├── tests/                    Pruebas unitarias
├── database/                 Scripts SQL (rol y base, esquema, datos de prueba), init de Docker y volcado
├── scripts/                  Instalación local de la base de datos (PowerShell y Bash)
├── uploads/                  Imágenes de proyectos y blog (las de seed/ se versionan; las subidas desde el panel no)
├── docs/                     Arquitectura y base de datos (de todo el sistema)
├── Dockerfile                Imagen de la API
└── docker-compose.yml        BD + API + frontend (construido desde ../GR-frontend)
```

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): capas, API, blog (estados y Markdown seguro), menú del panel, autenticación y cómo se cumple cada requisito de seguridad. Cubre **los dos repositorios**.
- [docs/DATABASE.md](docs/DATABASE.md): diagrama entidad-relación, tablas, restricciones y scripts.

Para ejecutar las pruebas del backend (opcional, solo en la instalación local): `dotnet test`.

---

## 10. Solución de problemas

| Problema | Solución |
|---|---|
| `no configuration file provided: not found` | La terminal no está en `GR-backend`. Entra con `cd` a esa carpeta y comprueba con `ls` que aparece `docker-compose.yml`. |
| `docker: command not found`, o Docker no arranca en Windows | Abre Docker Desktop y espera a *Engine running*. Si pide WSL, ejecuta `wsl --install` como administrador y reinicia. |
| Docker falla al construir `web` (*path not found* o *unable to prepare context*) | GR-frontend no está junto a GR-backend. Clónalo como se indica en el [paso 1](#1-clonar-los-dos-repositorios) o ajusta `FRONTEND_PATH` en `.env`. |
| `Define DB_PASSWORD en .env` | No existe `GR-backend/.env` o está vacía una contraseña. Repite el paso de copiar `.env.example`. Recuerda ejecutar `docker compose` dentro de `GR-backend`. |
| Cambié contraseñas en `.env` y Docker sigue con las anteriores | La base solo se inicializa la primera vez. Ejecuta `docker compose down -v` y luego `docker compose up --build`. |
| `port is already allocated`, o *address already in use* | Otro programa usa ese puerto. Cambia `WEB_PORT`, `DB_DOCKER_HOST_PORT` o `API_PORT` en `.env`. |
| `la ejecución de scripts está deshabilitada en este sistema` | Ejecuta el script como se indica: `powershell -ExecutionPolicy Bypass -File scripts\db-setup.ps1`, o usa Git Bash: `bash scripts/db-setup.sh`. |
| Git Bash: `En Git Bash debes definir DB_ADMIN_PASSWORD en .env` | Escribe en `.env` la contraseña de `postgres`. En Git Bash, `psql` no puede pedirla de forma interactiva. |
| Git Bash: un comando de `docker compose exec` falla con una ruta tipo `C:/Program Files/Git/...` | Git Bash convirtió la ruta del contenedor. Antepón `MSYS_NO_PATHCONV=1` al comando. |
| Git Bash: `$'\r': command not found` al ejecutar un script `.sh` | El archivo tiene finales de línea de Windows, lo que suele pasar al descargar el ZIP en lugar de clonar. Clona el repositorio con `git clone`: el `.gitattributes` fuerza los finales LF. |
| `No se encontró psql` | Instala PostgreSQL (paso 5.1). En Windows el script lo busca en `C:\Program Files\PostgreSQL`. En macOS o Linux, agrega su carpeta `bin` al `PATH`. |
| `password authentication failed for user "postgres"` | `DB_ADMIN_PASSWORD` no coincide con la contraseña que definiste al instalar PostgreSQL. |
| `dotnet: command not found`, o `npm` no se reconoce | Cierra y vuelve a abrir la terminal después de instalar. Comprueba con `dotnet --version`. |
| La API se detiene con `Falta la variable …` | Agrega esa variable a `.env`. Puedes copiarla de `.env.example`. |
| El sitio en `:4200` carga pero no muestra datos (errores 504 o de proxy) | La API no está en marcha o no usa el puerto 5080. Revisa la terminal 1 y que `API_PORT` coincida con `proxy.conf.json` de GR-frontend. |
| Inicio sesión pero el panel me devuelve al login | Tu navegador rechaza cookies `Secure` en `http://localhost`. Pon `AUTH_COOKIE_SECURE=false` en `.env` y reinicia la API (o `docker compose up`). Chrome, Edge y Firefox no lo necesitan. |
| "Demasiadas solicitudes" | Es el límite de peticiones funcionando. Espera el tiempo indicado o reinicia la API. |
| Las imágenes no cargan | Comprueba que existe `GR-backend/uploads/seed/` y que la API se ejecuta desde `GR-backend`. |
