# Arquitectura — Landing, Galería de Proyectos y Blog · Grupo Ricartti

> Documento de arquitectura del sistema completo, que abarca los repositorios **GR-backend** y **GR-frontend**. Describe las capas, la API, el modelo de seguridad y las decisiones técnicas. Para instalar y ejecutar, consulta el [README](../README.md). El detalle del esquema relacional está en [DATABASE.md](DATABASE.md).

---

## 1. Alcance

| Módulo | Descripción |
|---|---|
| **Galería pública** | Tarjetas con imagen, nombre, categoría y descripción breve. Al abrir una tarjeta se muestra el detalle del proyecto con sus evidencias (imágenes o resultados). Los filtros, la búsqueda, el orden y la paginación se resuelven en el servidor. |
| **Blog** | Entradas con portada, extracto, contenido con formato (Markdown), autor, etiquetas y tiempo de lectura. Tiene listado con filtro por etiqueta, búsqueda y paginación en el servidor, y una página de detalle. La landing muestra las tres entradas más recientes. |
| **Formulario de clientes** | Contacto para personas o empresas interesadas en Grupo Ricartti (busco inversión, alianza, coinversión, otro). |
| **Formulario de talento** | Postulación para personas interesadas en trabajar en Grupo Ricartti. |
| **Panel de administración** | Ruta protegida con un menú lateral: **Proyectos** (crear, editar, ocultar o publicar, y gestionar evidencias), **Blog** (redactar, editar, previsualizar, publicar, programar y archivar entradas) y, de forma opcional, **Mensajes** (bandejas de los formularios). |

**Restricciones del proyecto:**

- Se ejecuta **solo en local**, no se publica en ningún servidor.
- Debe poder levantarlo cualquier persona siguiendo el README, **sin conocimientos de .NET**.
- Hay **dos formas de ejecutarlo**: con Docker o con PostgreSQL instalado localmente.
- El código está en **dos repositorios de GitHub**, `GR-backend` y `GR-frontend`, que se clonan uno al lado del otro en la misma carpeta (ver §4).
- Puede haber **varios administradores**, todos con los mismos permisos. Se crean desde el script SQL de datos de prueba; no hay pantalla para gestionarlos.

---

## 2. Stack

| Capa | Tecnología | Motivo |
|---|---|---|
| Frontend | **Angular** (versión estable vigente, componentes standalone y signals) + **Tailwind CSS** | Escapa la salida por defecto (XSS) y sanea `[innerHTML]`, trae formularios reactivos y su `HttpClient` incluye protección XSRF. Tailwind permite trasladar el diseño visual sin pelear con una librería de componentes. |
| Backend | **ASP.NET Core 10 (LTS)**, Web API con controladores | Rate limiting nativo, una canalización de autenticación extensible, EF Core con consultas parametrizadas y una separación en capas sencilla mediante proyectos. |
| Acceso a datos | **Entity Framework Core 10** + **Npgsql** | ORM: no se escribe SQL concatenado en ningún punto. |
| Base de datos | **PostgreSQL 17** | Restricciones completas (FK, `CHECK`, índices parciales), `pg_dump` genera un `.sql` plano y corre igual en Windows, macOS, Linux y Docker. |
| Hash de contraseñas | **BCrypt.Net-Next** (factor 12) | Requisito explícito: bcrypt. |
| Validación | **FluentValidation** | Reglas declarativas y comprobables por DTO. |
| Contenido del blog | **Markdig** (Markdown → HTML, con HTML crudo deshabilitado) + **HtmlSanitizer** (lista blanca) | Los administradores escriben con formato sin poder inyectar HTML ni scripts. |
| Orquestación local | **Docker Compose** (opcional) | Un solo comando levanta la base de datos, la API y el frontend. |

---

## 3. Vista general

```
                         ┌───────────────────────────── Navegador ─────────────────────────────┐
                         │  Angular SPA  (sitio público + blog  +  /admin)                      │
                         └───────────────┬──────────────────────────────────────────────────────┘
                                         │  mismo origen: /, /api/*, /uploads/*
                                         ▼
        Docker:  Nginx (contenedor web, :8080)        Local:  ng serve (:4200) con proxy
                 · sirve el build de Angular                  · /api y /uploads → :5080
                 · /api y /uploads → api:8080
                 · cabeceras de seguridad (CSP…)
                                         │
                                         ▼
                ┌──────────────────────── ASP.NET Core API ────────────────────────┐
                │  Ricartti.Api            controladores, auth, rate limit, errores │
                │  Ricartti.Application    casos de uso, DTO, validación, reglas    │
                │  Ricartti.Infrastructure EF Core, repositorios, bcrypt, archivos, │
                │                          render de Markdown                       │
                │  Ricartti.Domain         entidades y enums                        │
                └───────────────┬───────────────────────────────┬──────────────────┘
                                │ EF Core (parametrizado)       │ sistema de archivos
                                ▼                               ▼
                         PostgreSQL 17                     uploads/  (imágenes)
```

En los dos modos de ejecución, navegador, frontend y API comparten **el mismo origen**. Por eso la cookie de sesión puede ser `SameSite=Strict` y no hace falta configurar CORS.

---

## 4. Repositorios y estructura

El sistema se versiona en **dos repositorios de GitHub** independientes. En el equipo local se clonan **uno al lado del otro**:

```
grupo-ricartti/                         # Carpeta contenedora (no es un repositorio)
├── GR-backend/                         # Repositorio 1
└── GR-frontend/                        # Repositorio 2
```

| Repositorio | Responsabilidad |
|---|---|
| **GR-backend** | API, base de datos (esquema, datos de prueba, volcado), imágenes del seed, orquestación con Docker Compose, documentación del sistema y guía principal de instalación |
| **GR-frontend** | Aplicación Angular (sitio público y panel), su `Dockerfile` y su `nginx.conf` |

**Integración entre los dos repositorios:**

- El **contrato** es la API HTTP descrita en §6. El frontend nunca accede a la base de datos.
- **Docker:** el `docker-compose.yml` de GR-backend construye el frontend desde `${FRONTEND_PATH:-../GR-frontend}`. Con un solo `docker compose up` se levanta todo.
- **Desarrollo del frontend:** `docker compose up db api` publica la API en `localhost:5080`, y `npm start` en GR-frontend la usa a través de su proxy. Así, quien desarrolla el frontend no necesita instalar .NET.
- Cada repositorio tiene sus propios `.gitignore`, `.gitattributes` y README. **Solo GR-backend tiene `.env`**: el frontend no maneja secretos.

### 4.1 GR-backend

```
GR-backend/
├── Ricartti.sln
├── Dockerfile                          # Imagen de la API
├── src/
│   ├── Ricartti.Domain/                # Entidades y enums. Sin dependencias.
│   ├── Ricartti.Application/           # Servicios, DTO, validadores, interfaces (puertos)
│   ├── Ricartti.Infrastructure/        # DbContext, mapeos EF, repositorios, bcrypt, almacenamiento, Markdown
│   └── Ricartti.Api/                   # Program.cs, controladores, autenticación, middleware
├── tests/
│   └── Ricartti.UnitTests/             # Validadores, reglas de negocio y saneamiento de HTML
├── database/
│   ├── sql/
│   │   ├── 00_create_role_and_db.sql   # Crea el rol de la app y la base de datos (idempotente)
│   │   ├── 01_schema.sql               # Tablas, relaciones, restricciones, índices, triggers
│   │   └── 02_seed.sql                 # Datos de prueba (ficticios) y administradores
│   ├── docker/
│   │   ├── initdb.sh                   # Primer arranque del contenedor: ejecuta los 3 scripts
│   │   └── load-dump.sh                # Recrea la base desde el volcado (dentro del contenedor)
│   └── dump/ricartti_dump.sql          # Volcado generado con pg_dump
├── scripts/
│   ├── db-setup.ps1                    # Instalación local de la BD (Windows)
│   └── db-setup.sh                     # Instalación local de la BD (macOS / Linux)
├── uploads/
│   └── seed/                           # Imágenes de los datos de prueba (proyectos y blog, versionadas)
├── docs/
│   ├── ARCHITECTURE.md                 # Este documento (sistema completo)
│   └── DATABASE.md
├── docker-compose.yml                  # BD + API + frontend (desde ../GR-frontend)
├── .env.example
├── .gitignore
├── .gitattributes
└── README.md                           # Guía principal de instalación
```

### 4.2 GR-frontend

```
GR-frontend/
├── src/
│   ├── app/                            # Ver §13
│   └── assets/fonts/                   # Fuentes alojadas localmente (CSP)
├── proxy.conf.json                     # npm start: /api y /uploads → http://localhost:5080
├── nginx.conf                          # Docker: sirve el build, proxy a la API, cabeceras de seguridad
├── Dockerfile                          # Build con Node → imagen Nginx
├── angular.json · package.json · tailwind.config.js
├── .gitignore
├── .gitattributes
└── README.md                           # Desarrollo del frontend (remite a GR-backend para el sistema completo)
```

---

## 5. Backend: capas

### 5.1 Responsabilidades

| Capa | Proyecto | Contiene | No contiene |
|---|---|---|---|
| **Rutas** | `Ricartti.Api` | Controladores (traducen HTTP ↔ DTO), autenticación, políticas de rate limiting, cabeceras de seguridad, manejo global de errores, carga y validación de configuración | Reglas de negocio ni acceso a `DbContext` |
| **Lógica** | `Ricartti.Application` | Servicios de caso de uso (`GalleryService`, `AdminProjectService`, `BlogService`, `AdminBlogService`, `FormSubmissionService`, `AuthService`), DTO de entrada y salida, validadores FluentValidation, interfaces (repositorios, almacenamiento, hashing, reloj, `IContentRenderer`) y el tipo `Result<T>` | Referencias a EF Core, ASP.NET, Markdig o al sistema de archivos |
| **Acceso a datos** | `Ricartti.Infrastructure` | `RicarttiDbContext`, configuraciones Fluent API (mapean el esquema SQL existente), repositorios, `BcryptPasswordHasher`, `LocalFileStorage`, validación de firmas de imagen y `MarkdownContentRenderer` (Markdig + HtmlSanitizer) | Decisiones de negocio |
| **Dominio** | `Ricartti.Domain` | Entidades (`Admin`, `AdminSession`, `Category`, `Project`, `ProjectEvidence`, `BlogPost`, `BlogTag`, `ClientInquiry`, `JobApplication`) y enums (`EvidenceKind`, `BlogPostStatus`…) | Dependencias externas |

**Regla de dependencias:** `Api → Application → Domain` e `Infrastructure → Application`. `Api` referencia a `Infrastructure` solo para registrar la inyección de dependencias en `Program.cs`. Los controladores no ven el `DbContext`.

### 5.2 Flujo de una petición (ejemplo: galería pública)

```
GET /api/projects?category=fintech&q=pagos&sort=recent&page=1&pageSize=6
  │
  ├─ Middleware: cabeceras de seguridad → rate limit global → autenticación (anónima)
  ├─ ProjectsController.List(GalleryQueryRequest)          [Api]
  │     └─ GalleryQueryValidator                           [Application]  → 400 si es inválido
  ├─ GalleryService.SearchAsync(query)                     [Application]
  │     └─ IProjectRepository.SearchVisibleAsync(...)      [Infrastructure]
  │           └─ EF Core → SELECT … WHERE is_visible AND category.slug = @p0 AND title ILIKE @p1 …
  └─ 200 { items: [...], page, pageSize, totalItems, totalPages }
```

### 5.3 Convenciones transversales

- **DTO en los límites.** Las entidades nunca se serializan directamente. Cada endpoint tiene un DTO de entrada y otro de salida, lo que evita la asignación masiva (*over-posting*) y la fuga de columnas internas.
- **`Result<T>` en vez de excepciones** para los errores esperados (`NotFound`, `Validation`, `Conflict`, `Unauthorized`). El controlador traduce cada uno a su código HTTP.
- **Errores con formato uniforme.** Todas las respuestas de error usan `ProblemDetails` (RFC 9457). Las de validación incluyen un diccionario `errors` por campo. Fuera de `Development` no se exponen *stack traces*.
- **Fechas en UTC.** Se guardan como `timestamptz` y se generan desde un `IClock` inyectado, lo que permite probar la lógica temporal (por ejemplo, las entradas programadas).
- **Normalización.** Se recortan espacios y los correos se guardan en minúsculas. Se hace en la capa de aplicación y la base de datos lo verifica con `CHECK`.

---

## 6. API

Respuestas en JSON. La paginación sigue siempre el formato `{ items, page, pageSize, totalItems, totalPages }`.

### 6.1 Pública

| Método | Ruta | Descripción | Rate limit |
|---|---|---|---|
| GET | `/api/health` | Estado de la API y de la conexión a la BD | global |
| GET | `/api/antiforgery/token` | Emite la cookie `XSRF-TOKEN` | global |
| GET | `/api/categories` | Categorías activas, con el número de proyectos visibles de cada una | global |
| GET | `/api/projects` | Galería: filtros, búsqueda, orden y paginación (ver §7) | global |
| GET | `/api/projects/{slug}` | Detalle del proyecto con sus evidencias. 404 si no existe **o está oculto** | global |
| GET | `/api/blog/posts` | Entradas publicadas: `tag`, `q`, `page`, `pageSize` (ver §8) | global |
| GET | `/api/blog/posts/{slug}` | Detalle con `contentHtml` saneado, autor, etiquetas y tiempo de lectura. 404 si no existe, es borrador, está programada o archivada | global |
| GET | `/api/blog/tags` | Etiquetas con el número de entradas publicadas de cada una | global |
| POST | `/api/forms/client-inquiries` | Formulario de clientes | **forms** |
| POST | `/api/forms/job-applications` | Formulario de talento | **forms** |

### 6.2 Autenticación

| Método | Ruta | Descripción | Rate limit |
|---|---|---|---|
| POST | `/api/auth/login` | `{ email, password }` → cookie de sesión. 401 con mensaje genérico ante cualquier fallo | **login** |
| POST | `/api/auth/logout` | Revoca la sesión actual y borra la cookie | global |
| GET | `/api/auth/me` | Administrador autenticado, o 401. Lo usa el guard del frontend | global |

### 6.3 Administración (todas requieren sesión)

Toda ruta bajo `/api/admin/*` exige la política `AdminOnly`. Se aplica a nivel de grupo de controladores, así que ninguna acción queda pública por omisión.

**Proyectos**

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/api/admin/projects` | Lista con filtros `q`, `category`, `visibility=all\|visible\|hidden` y paginación |
| GET | `/api/admin/projects/{id}` | Detalle editable, incluye `version` para control de concurrencia |
| POST | `/api/admin/projects` | Crea un proyecto (siempre oculto al crearse) |
| PUT | `/api/admin/projects/{id}` | Edita los datos. Exige `version`; responde 409 si otro administrador lo modificó antes |
| PATCH | `/api/admin/projects/{id}/visibility` | `{ isVisible, version }`. Publicar exige portada; la primera publicación fija `published_at` |
| PUT | `/api/admin/projects/{id}/cover` | `multipart/form-data`: sube o reemplaza la portada |
| POST | `/api/admin/projects/{id}/evidences/images` | `multipart/form-data`: imagen + `altText`, `title`, `description` |
| POST | `/api/admin/projects/{id}/evidences/results` | JSON: `metricValue`, `metricLabel`, `title`, `description` |
| PUT | `/api/admin/projects/{id}/evidences/{evidenceId}` | Edita los textos o el orden de una evidencia |
| DELETE | `/api/admin/projects/{id}/evidences/{evidenceId}` | Elimina la evidencia y su archivo |
| GET | `/api/admin/categories` | Todas las categorías, para los selectores del formulario |

**Blog**

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/api/admin/blog/posts` | Lista con filtros `status=all\|draft\|scheduled\|published\|archived`, `q`, `tag` y paginación |
| GET | `/api/admin/blog/posts/{id}` | Detalle editable (Markdown, etiquetas, `version`) |
| POST | `/api/admin/blog/posts` | Crea una entrada (siempre como borrador) |
| PUT | `/api/admin/blog/posts/{id}` | Edita `title`, `excerpt`, `contentMarkdown` y `tags`. Exige `version`; responde 409 ante un conflicto |
| PATCH | `/api/admin/blog/posts/{id}/status` | `{ status, publishedAt?, version }`: publicar ahora, programar, archivar o volver a borrador (ver §8.1) |
| PUT | `/api/admin/blog/posts/{id}/cover` | `multipart/form-data`: sube o reemplaza la portada |
| POST | `/api/admin/blog/posts/{id}/images` | `multipart/form-data`: imagen para el cuerpo. Devuelve `{ path }`, que el editor inserta como `![alt](path)` |
| POST | `/api/admin/blog/preview` | `{ contentMarkdown }` → `{ html }`. Usa el mismo renderizado saneado que el sitio público |
| GET | `/api/admin/blog/tags` | Todas las etiquetas, con su número de entradas |

**Mensajes (opcional)**

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/api/admin/client-inquiries` | Bandeja de mensajes de clientes |
| GET | `/api/admin/job-applications` | Bandeja de postulaciones |

> Los proyectos y las entradas del blog **no se borran**: los proyectos se ocultan y las entradas se archivan. Así se conserva el historial y se evitan borrados accidentales entre varios administradores.

---

## 7. Galería: filtros en el servidor

`GET /api/projects` acepta los siguientes parámetros. Cualquier valor fuera de estas reglas devuelve **400**:

| Parámetro | Regla | Uso |
|---|---|---|
| `category` | slug `^[a-z0-9-]{1,60}$`, opcional | `categories.slug = @p` (categoría activa) |
| `q` | texto opcional de hasta 100 caracteres, recortado | `unaccent(title) ILIKE unaccent(@p)` y lo mismo sobre `summary` ("credito" encuentra "Crédito"). Se escapan `%`, `_` y `\` antes de pasarlo como parámetro |
| `sort` | `featured` (por defecto) \| `recent` \| `name` | Lista blanca → `ORDER BY` fijo en el código. El valor nunca se interpola |
| `page` | entero ≥ 1 (por defecto 1) | `OFFSET` |
| `pageSize` | entero de 1 a 24 (por defecto 6) | `LIMIT` |

Siempre se aplica `is_visible = true`, sin importar los parámetros. El frontend guarda el estado de los filtros en la URL (`?category=…&q=…`), de modo que una búsqueda se puede compartir y el botón Atrás funciona. Cada cambio dispara una nueva consulta a la API; la búsqueda por texto espera 300 ms sin escribir antes de enviarse.

---

## 8. Blog

### 8.1 Estados y publicación

```
              publicar (ahora o con fecha futura)
   ┌──────────┐ ──────────────────────────────▶ ┌─────────────┐   archivar   ┌───────────┐
   │ Borrador │                                 │  Publicada  │ ───────────▶ │ Archivada │
   └──────────┘ ◀────────────────────────────── └─────────────┘ ◀─────────── └───────────┘
                     volver a borrador                            volver a publicar
```

| Estado | `status` | ¿Visible en el sitio? |
|---|---|---|
| Borrador | `draft` | No |
| Programada | `published` con `published_at` futura | No, hasta que llegue la fecha |
| Publicada | `published` con `published_at <= now()` | **Sí** |
| Archivada | `archived` | No |

**Reglas de publicación:**

- El estado *programada* no es un valor aparte: se deriva de `published_at`. Una entrada programada aparece sola en el sitio al llegar su fecha, sin procesos en segundo plano, porque la consulta pública siempre filtra `status = 'published' AND published_at <= now()`.
- Para publicar hacen falta título, extracto, contenido y **portada**. La regla se valida en el servicio y la base de datos la refuerza con un `CHECK`.
- Si al publicar no se envía `publishedAt`, se usa la fecha actual. Al volver a publicar una entrada archivada se conserva su fecha original.
- El autor es el administrador que creó la entrada. Si su cuenta se elimina, el sitio muestra "Grupo Ricartti".

### 8.2 Contenido: Markdown renderizado de forma segura

El contenido se guarda **solo en Markdown** (`content_markdown`), que es la única fuente de verdad. El HTML se genera en la API al leer la entrada:

1. **Markdig** convierte Markdown a HTML con el **HTML crudo deshabilitado**: cualquier `<script>` o `<div onclick>` escrito en el texto se muestra como texto literal. Los `#` se rebajan a `<h2>`, porque el `<h1>` de la página es el título de la entrada.
2. **HtmlSanitizer** filtra el resultado con una lista blanca:
   - **Etiquetas:** `p`, `h2`–`h4`, `strong`, `em`, `ul`, `ol`, `li`, `blockquote`, `a`, `img`, `code`, `pre`, `hr`, `br`.
   - **Atributos:** `href` (solo `https:`, `mailto:` o rutas internas que empiezan con `/`), `src` (solo `/uploads/…`), `alt` y `title`.
   - **Enlaces externos:** reciben `rel="noopener noreferrer nofollow"`.
3. El HTML resultante se guarda en caché en memoria con la clave `(post_id, updated_at)`. Así cada versión se renderiza una sola vez, y editar la entrada invalida la caché automáticamente.

La vista previa del panel (`POST /api/admin/blog/preview`) usa **exactamente el mismo** `IContentRenderer`, de modo que lo que ve el administrador es lo que se publica.

### 8.3 Listado público

`GET /api/blog/posts` acepta los siguientes parámetros. Cualquier valor fuera de estas reglas devuelve **400**:

| Parámetro | Regla |
|---|---|
| `tag` | slug opcional |
| `q` | texto opcional de hasta 100 caracteres. Busca con `unaccent … ILIKE` sobre `title` y `excerpt`, igual que la galería |
| `page` | entero ≥ 1 (por defecto 1) |
| `pageSize` | entero de 1 a 24 (por defecto 6) |

El orden es siempre `published_at DESC`. La landing pide `pageSize=3` para mostrar las más recientes.

### 8.4 Editor del panel

- **Área de texto Markdown** con una barra de formato (negrita, cursiva, subtítulo, lista, cita, enlace, imagen) y una pestaña de **vista previa**.
- **Imágenes en el cuerpo:** se suben a `POST /api/admin/blog/posts/{id}/images` y se insertan como `![texto alternativo](/uploads/blog/{id}/…)`. Por eso el editor guarda el borrador antes de permitir la primera subida.
- **Etiquetas:** se elige una existente o se escribe una nueva. El servidor normaliza el nombre, genera su slug y la crea si no existe, en la misma transacción que la entrada. Máximo 5 por entrada.
- **Tiempo de lectura:** lo calcula el servidor al guardar (palabras ÷ 200, mínimo 1 minuto).
- **Publicación:** botones *Publicar ahora*, *Programar* (con selector de fecha), *Archivar* y *Volver a borrador*.

---

## 9. Autenticación y sesiones

Se usan **sesiones en el servidor con una cookie `HttpOnly`**, no JWT. Con varios administradores importa poder **revocar el acceso al instante** (cerrar sesión o desactivar una cuenta), y con JWT eso obliga a mantener una lista de bloqueo. Además, el token nunca queda al alcance de JavaScript.

### 9.1 Inicio de sesión

1. El rate limiter `login` corta el exceso de intentos (5 por minuto por IP; configurable).
2. Se valida el formato del DTO.
3. Se busca al administrador por correo normalizado. **Si no existe, igualmente se verifica la contraseña contra un hash señuelo**, para que el tiempo de respuesta no revele qué correos existen.
4. Si la cuenta está bloqueada (`lockout_until > now`), inactiva o la contraseña no coincide, se responde **401 con el mismo mensaje genérico**. Ante una contraseña incorrecta se incrementa `failed_login_count`; al llegar a 5 se bloquea la cuenta 15 minutos.
5. Si todo es correcto: se reinicia el contador, se generan **32 bytes aleatorios** (`RandomNumberGenerator`), se guarda **solo su SHA-256** en `admin_sessions` y se envía el token en la cookie.

```
Set-Cookie: ricartti_session=<token base64url>; Path=/; HttpOnly; Secure; SameSite=Strict
```

### 9.2 En cada petición a `/api/admin/*`

Un `SessionAuthenticationHandler` propio lee la cookie, calcula su hash y busca la sesión. Debe cumplir: `revoked_at IS NULL`, `expires_at > now`, `absolute_expires_at > now` y administrador con `is_active = true`. Si algo falla responde 401.

- **Expiración deslizante:** `expires_at = min(now + 30 min, absolute_expires_at)`. Para no escribir en cada petición, solo se actualiza si pasó más de un minuto desde la última vez.
- **Expiración absoluta:** 8 horas desde el inicio de sesión. Después hay que volver a entrar aunque haya actividad.
- **Cierre de sesión:** fija `revoked_at` y elimina la cookie.
- **Sin fijación de sesión:** cada inicio de sesión crea un token nuevo.

### 9.3 CSRF

- La cookie de sesión es `SameSite=Strict`, así que otro sitio no puede hacer que el navegador la envíe.
- Además, **antiforgery de ASP.NET Core** en todo `POST/PUT/PATCH/DELETE`: la API emite la cookie legible `XSRF-TOKEN` y espera la cabecera `X-XSRF-TOKEN`. Angular `HttpClient` hace esto de forma automática para URL relativas.
- El token antiforgery está ligado a la identidad, por lo que el frontend **pide uno nuevo después del login y del logout**.

### 9.4 Frontend

`adminGuard` (`canMatch`) consulta `/api/auth/me` antes de cargar el módulo `/admin`, que se carga de forma diferida. El guard **solo mejora la experiencia de uso**: la protección real está en el servidor. Si la API responde 401 a una petición de administración, un interceptor redirige a `/admin/login`.

---

## 10. Requisitos de seguridad

| # | Requisito | Implementación | Dónde |
|---|---|---|---|
| 1 | Validación de entradas en el servidor | FluentValidation para cada DTO: longitudes iguales a las de la BD, formatos (correo, teléfono, URL `https`, slug), valores de enums en lista blanca, rechazo de caracteres de control, máximo 5 etiquetas por entrada y fechas de programación válidas. Las subidas se validan por tamaño, MIME **y firma binaria** (magic bytes). Además hay restricciones `CHECK` en la BD como última barrera | `Application/*/Validators`, `Infrastructure/Storage`, `01_schema.sql` |
| 2 | Consultas parametrizadas u ORM | Todo el acceso pasa por EF Core con LINQ. No se usa `FromSqlRaw` con interpolación. Los parámetros de orden se resuelven con una lista blanca, y `ILIKE` va por `EF.Functions.ILike` con el patrón escapado | `Infrastructure/Persistence` |
| 3 | Contraseñas con hash y sesión segura con expiración | bcrypt, factor 12. Tokens de sesión de 256 bits guardados como hash. Expiración deslizante de 30 min y absoluta de 8 h, con revocación inmediata | `Infrastructure/Security`, `Api/Auth`, tabla `admin_sessions` |
| 5 | Rutas de administración inaccesibles sin autenticación | Política `AdminOnly` aplicada al grupo `/api/admin`, más un test que recorre todas las rutas y verifica que responden 401 sin sesión. Las rutas de Angular están detrás del guard | `Api/Controllers/Admin`, `UnitTests` |
| 6 | Protección contra XSS | Angular escapa toda interpolación `{{ }}`. Proyectos y formularios guardan texto plano. **`[innerHTML]` está prohibido con una única excepción:** el componente `blog-content`, que recibe HTML ya generado y saneado en el servidor (Markdown con HTML crudo deshabilitado + lista blanca de HtmlSanitizer, §8.2). Ese HTML vuelve a pasar por el sanitizador integrado de Angular. **`bypassSecurityTrust*` está prohibido sin excepciones.** Hay tests unitarios que verifican que se eliminan `<script>`, `on*=`, `javascript:` y las imágenes externas. Cabeceras: `Content-Security-Policy` (`default-src 'self'; script-src 'self'; object-src 'none'; frame-ancestors 'none'; img-src 'self' data:`), `X-Content-Type-Options: nosniff`, `Referrer-Policy`. Las imágenes subidas reciben nombre aleatorio y solo se aceptan JPEG, PNG y WebP (**SVG no**, porque puede contener scripts) | Frontend, `MarkdownContentRenderer`, `nginx.conf`, middleware `SecurityHeaders` |
| 7 | Límite de peticiones en login y formularios | `Microsoft.AspNetCore.RateLimiting` por IP: `login` 5/min, `forms` 5 por 15 min, `global` 120/min. Responden **429** con `Retry-After`. En Docker se usa `ForwardedHeaders` para obtener la IP real detrás de Nginx, confiando **solo en la IP fija del contenedor Nginx**. Así, las peticiones directas al puerto publicado de la API no pueden falsear `X-Forwarded-For`. Los formularios también tienen un campo trampa (*honeypot*) | `Api/Configuration/RateLimiting` |
| 8 | Cero secretos en el repositorio | Toda la configuración viene de variables de entorno, leídas desde `.env` (ignorado por git). En el repo solo está `.env.example`, con valores de ejemplo. Al arrancar, la API valida las variables obligatorias y se detiene con un mensaje claro si falta alguna. Los administradores de prueba se guardan con hash; sus contraseñas solo aparecen en el README, como pide la prueba | `.gitignore`, `.env.example`, `Api/Configuration` |

---

## 11. Gestión y consistencia de datos

- **El esquema es SQL versionado.** `database/sql/01_schema.sql` es la fuente de verdad y EF Core solo mapea esas tablas. No se usan migraciones de EF: quien ejecute el proyecto no necesita herramientas de .NET para crear la base de datos.
- **Restricciones en la BD.** FK con reglas `ON DELETE` explícitas y `CHECK` de formatos y de reglas de negocio:
  - Un proyecto visible debe tener portada y fecha de publicación.
  - Una evidencia es *imagen* **o** *resultado*, nunca ambas.
  - Una entrada publicada debe tener fecha y portada.

  Además: `UNIQUE` en slugs, correos y nombres de etiqueta, y `updated_at` mantenido por trigger.
- **Una sola fuente para el contenido del blog.** Se guarda únicamente el Markdown y el HTML se deriva al leer, así que nunca puede quedar desincronizado.
- **Transacciones.** Las operaciones de varios pasos se ejecutan en una sola transacción mediante `IUnitOfWork`:
  - Crear un proyecto con su portada.
  - Reemplazar una imagen.
  - Guardar una entrada creando sus etiquetas nuevas y reemplazando las de `blog_post_tags`.
- **Consistencia entre archivos y BD:**
  - *Alta:* se escribe el archivo primero. Si falla la inserción en la BD, se borra el archivo.
  - *Reemplazo o borrado:* el archivo anterior se elimina solo después de confirmar la transacción.
- **Concurrencia optimista.** EF Core usa la columna de sistema `xmin` de PostgreSQL como token de versión. Si dos administradores editan el mismo proyecto o la misma entrada, el segundo recibe **409 Conflict** en lugar de sobrescribir el cambio sin aviso.
- **Auditoría básica.** `created_by` y `updated_by` en proyectos y entradas, `author_id` en entradas y `last_login_at` en administradores.
- **Slugs** generados en el servidor a partir del título (minúsculas, sin acentos, con guiones), únicos y estables: no cambian si se edita el título, para no romper enlaces.

---

## 12. Archivos e imágenes

- Se guardan con un nombre generado por el servidor. **Nunca se usa el nombre de archivo del usuario.**
  - `UPLOADS_PATH/projects/{projectId}/{guid}.{ext}`: portadas y evidencias de proyectos.
  - `UPLOADS_PATH/blog/{postId}/{guid}.{ext}`: portadas e imágenes del cuerpo de las entradas.
- Se validan el tamaño (≤ 5 MB por defecto), la extensión, el MIME y la **firma binaria**: JPEG `FF D8 FF`, PNG `89 50 4E 47`, WebP `RIFF....WEBP`.
- La API los sirve bajo `/uploads` con `nosniff`. En Docker, Nginx redirige `/uploads` a la API.
- Las imágenes del seed viven en `uploads/seed/` (proyectos y `blog/`) y están versionadas; las subidas en tiempo de ejecución están en `.gitignore`.
- Si una imagen del cuerpo de una entrada se sube pero se borra del texto, el archivo queda huérfano dentro de la carpeta de esa entrada. Es aceptable en este alcance; ver §15.

---

## 13. Frontend (repositorio GR-frontend)

```
GR-frontend/src/app/
├── core/
│   ├── api/          # Servicios HTTP tipados (gallery, blog, forms, auth, admin-projects, admin-blog)
│   ├── auth/         # auth.store (signals), admin.guard
│   ├── http/         # error.interceptor (401 → login, 429 → aviso), configuración XSRF
│   └── models/       # Interfaces que reflejan los DTO de la API
├── features/
│   ├── public/
│   │   ├── landing/                # Secciones de la landing (incluye "Últimas entradas")
│   │   ├── gallery/                # Página, filtros y tarjeta de proyecto
│   │   ├── project-detail/         # Detalle (/proyectos/:slug)
│   │   ├── blog-list/              # Listado, filtro por etiqueta y búsqueda (/blog)
│   │   ├── blog-post/              # Detalle de la entrada (/blog/:slug)
│   │   ├── client-inquiry-form/
│   │   └── job-application-form/
│   └── admin/                      # Carga diferida, detrás de adminGuard
│       ├── login/
│       ├── shell/                  # Layout del panel: menú lateral + barra superior
│       ├── projects-list/
│       ├── project-editor/         # Datos, portada, visibilidad y evidencias
│       ├── blog-list/              # Entradas, con filtro por estado
│       ├── blog-editor/            # Markdown, vista previa, etiquetas, portada y publicación
│       └── messages/               # (Opcional) Bandejas de los formularios
├── shared/ui/                      # Botón, input, paginación, estado vacío, imagen con respaldo,
│                                   # blog-content (único uso permitido de [innerHTML])
├── app.routes.ts
└── app.config.ts
```

### 13.1 Rutas

| Ruta | Vista |
|---|---|
| `/` | Landing: hero, galería, últimas entradas del blog, formularios |
| `/proyectos/:slug` | Detalle del proyecto (enlazable directamente) |
| `/blog` | Listado del blog |
| `/blog/:slug` | Entrada del blog |
| `/admin/login` | Inicio de sesión |
| `/admin` | Redirige a `/admin/proyectos` |
| `/admin/proyectos` · `/admin/proyectos/nuevo` · `/admin/proyectos/:id` | Lista y editor de proyectos |
| `/admin/blog` · `/admin/blog/nueva` · `/admin/blog/:id` | Lista y editor de entradas |
| `/admin/mensajes` | *(Opcional)* Bandejas de clientes y postulaciones |

### 13.2 Menú del panel

Todas las rutas del panel, salvo el login, se muestran dentro de `admin/shell`:

```
┌───────────────────────┬──────────────────────────────────────────────────┐
│  GRUPO RICARTTI       │  Andrea Ricartti                 [Cerrar sesión] │
│  Panel                ├──────────────────────────────────────────────────┤
│                       │                                                  │
│  ▸ Proyectos          │   (contenido de la sección activa)               │
│  ▸ Blog               │                                                  │
│  ▸ Mensajes (opc.)    │                                                  │
│                       │                                                  │
│  ↗ Ver sitio público  │                                                  │
└───────────────────────┴──────────────────────────────────────────────────┘
```

- El menú es una lista de configuración (`label`, `route`, `icon`), así que añadir una sección futura solo requiere una entrada nueva.
- En el listado del blog, cada entrada muestra su estado con una etiqueta de color: Borrador, Programada, Publicada o Archivada.

### 13.3 Otros criterios

- **Formularios reactivos** con validaciones iguales a las del servidor. Son solo para la experiencia de uso: el servidor sigue siendo la autoridad y sus errores por campo se muestran en el formulario.
- **Sin** Angular Material, *service worker* ni SSR: el diseño visual se implementa con Tailwind y el sitio se ejecuta en local.
- Las fuentes tipográficas se **alojan en el propio proyecto** para cumplir la CSP (`font-src 'self'`).

---

## 14. Configuración

Todas las variables se definen en `.env`, que se crea copiando `.env.example`. La lista completa con su descripción está en el README.

| Grupo | Variables |
|---|---|
| Base de datos | `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_ADMIN_USER`, `DB_ADMIN_PASSWORD`, `DB_DOCKER_HOST_PORT` |
| API | `ASPNETCORE_ENVIRONMENT`, `API_PORT`, `UPLOADS_PATH`, `UPLOAD_MAX_BYTES` |
| Autenticación | `AUTH_COOKIE_NAME`, `AUTH_COOKIE_SECURE`, `AUTH_SESSION_IDLE_MINUTES`, `AUTH_SESSION_ABSOLUTE_HOURS`, `AUTH_MAX_FAILED_ATTEMPTS`, `AUTH_LOCKOUT_MINUTES` |
| Rate limiting | `RATE_LIMIT_LOGIN_PERMITS`, `RATE_LIMIT_LOGIN_WINDOW_SECONDS`, `RATE_LIMIT_FORMS_PERMITS`, `RATE_LIMIT_FORMS_WINDOW_SECONDS`, `RATE_LIMIT_GLOBAL_PERMITS_PER_MINUTE` |
| Docker | `WEB_PORT` |

**Roles de PostgreSQL:**

- `DB_ADMIN_USER` es el superusuario. Solo lo usan los scripts de instalación para crear el rol de la aplicación y la base de datos.
- La API se conecta con `DB_USER`, un rol **sin privilegios de superusuario** que es dueño únicamente de la base `ricartti`.

---

## 15. Fuera de alcance (posibles mejoras)

- Gestión de administradores desde la interfaz (alta, baja, cambio de contraseña) y roles diferenciados (por ejemplo, editor de blog).
- Blog:
  - Historial de versiones de cada entrada.
  - Comentarios.
  - RSS.
  - Limpieza automática de imágenes del cuerpo que ya no se usan.
- Recepción de CV como archivo adjunto. La postulación pide perfiles de LinkedIn o portafolio para evitar recibir documentos.
- Envío de correos de notificación al recibir formularios.
- SSR para SEO si el sitio llega a publicarse (útil sobre todo para el blog).
- Separar el rol dueño del esquema del rol que usa la aplicación en tiempo de ejecución.
