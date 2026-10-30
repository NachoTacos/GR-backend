# Arquitectura — Landing, Galería de Proyectos y Blog · Grupo Ricartti

> Documento de arquitectura del sistema completo, que abarca los repositorios **GR-backend** y **GR-frontend**. Describe las capas, la API, el modelo de seguridad y las decisiones técnicas. Para instalar y ejecutar, consulta el [README](../README.md). El detalle del esquema relacional está en [DATABASE.md](DATABASE.md).
>
> **Diseño y contrato del frontend:** el **handoff de Grupo Ricartti** (`HANDOFF-grupo-ricartti.md` y su asset pack) es la fuente de verdad del sitio, del panel, de los textos ES/EN y del contrato de la API (§9 del handoff). Este documento lo implementa y señala dónde se extiende; por ejemplo, el blog no forma parte del handoff.

---

## 1. Alcance

El sitio es **bilingüe** (español por defecto, inglés) para un *venture builder* con sede en Durango: crea, incuba, financia y vende sus propias empresas.

| Módulo | Descripción |
|---|---|
| **Galería pública** | Tarjetas con portada, nombre, categoría, etapa y descripción breve. Al abrir una tarjeta se abre el detalle (diálogo) con descripción, resultados, evidencias en imagen y áreas de respaldo del grupo. El filtro por categoría se resuelve en el servidor. |
| **Blog** *(extensión al handoff)* | Entradas bilingües con portada, extracto, contenido en Markdown, autor, etiquetas y tiempo de lectura. Filtro por etiqueta, búsqueda y paginación en el servidor. |
| **Formulario de clientes** | Clientes, inversionistas y compradores. Interés: adquirir un proyecto, coinvertir, incubar o contratar servicios. |
| **Formulario de talento** | Postulación con área, LinkedIn o portafolio opcional y **CV en PDF opcional (≤ 5 MB)**. |
| **Panel de administración** | Ruta protegida con menú lateral: **Proyectos** (crear, editar con textos ES/EN, ocultar o publicar, y gestionar resultados, evidencias y áreas de respaldo), **Blog** (redactar en ES/EN, previsualizar, publicar, programar y archivar) y, de forma opcional, **Mensajes** (bandejas de los formularios, con descarga de CV). |

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
| Frontend | **Angular** (versión estable vigente, componentes standalone y signals) + **CSS plano** con los tokens del handoff (`tokens.css`, `reference.css`), **sin Tailwind ni librerías de UI** | Escapa la salida por defecto (XSS) y sanea `[innerHTML]`, trae formularios reactivos y su `HttpClient` incluye protección XSRF. El handoff recomienda React, pero también indica usar lo que el equipo ya tenga; se eligió Angular. Sus reglas visuales se respetan tal cual: sin Tailwind y con los tokens CSS 1:1. |
| Backend | **ASP.NET Core 10 (LTS)**, Web API con controladores | Rate limiting nativo, una canalización de autenticación extensible, EF Core con consultas parametrizadas y una separación en capas sencilla mediante proyectos. |
| Acceso a datos | **Entity Framework Core 10** + **Npgsql** | ORM: no se escribe SQL concatenado en ningún punto. |
| Base de datos | **PostgreSQL 17** | Restricciones completas (FK, `CHECK`, índices parciales), `pg_dump` genera un `.sql` plano y corre igual en Windows, macOS, Linux y Docker. |
| Hash de contraseñas | **BCrypt.Net-Next** (factor 12) | Requisito explícito: bcrypt. |
| Validación | Validadores propios (`FieldValidator`), sin librerías | Cada regla refleja un `CHECK` de la BD y devuelve los códigos del contrato (`required`, `email`, `consent`, `url`, `invalid`, `file_type`). Son pocas reglas y así el equipo no depende de otra herramienta. |
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
| **Dominio** | `Ricartti.Domain` | Entidades (`Admin`, `AdminSession`, `Category`, `SupportArea`, `Project`, `ProjectImage`, `ProjectResult`, `BlogPost`, `BlogTag`, `ClientLead`, `TalentApplication`), el valor `Localized { Es, En }` y enums (`ProjectStage`, `BlogPostStatus`, `LeadInterest`, `TalentArea`…) | Dependencias externas |

**Regla de dependencias:** `Api → Application → Domain` e `Infrastructure → Application`. `Api` referencia a `Infrastructure` solo para registrar la inyección de dependencias en `Program.cs`. Los controladores no ven el `DbContext`.

### 5.2 Flujo de una petición (ejemplo: galería pública)

```
GET /api/projects?category=fintech
  │
  ├─ Middleware: cabeceras de seguridad → rate limit global → autenticación (anónima)
  ├─ ProjectsController.List(GalleryQueryRequest)          [Api]
  │     └─ GalleryQueryValidator                           [Application]  → 422 si es inválido
  ├─ GalleryService.ListVisibleAsync(query)                [Application]
  │     └─ IProjectRepository.ListVisibleAsync(...)        [Infrastructure]
  │           └─ EF Core → SELECT … WHERE is_visible AND category.slug = @p0 ORDER BY sort_order, year DESC
  └─ 200 Project[]   (contrato del handoff §9: textos como { es, en })
```

### 5.3 Convenciones transversales

- **DTO en los límites.** Las entidades nunca se serializan directamente. Cada endpoint tiene un DTO de entrada y otro de salida, lo que evita la asignación masiva (*over-posting*) y la fuga de columnas internas.
- **`Result<T>` en vez de excepciones** para los errores esperados (`NotFound`, `Validation`, `Conflict`, `Unauthorized`). El controlador traduce cada uno a su código HTTP.
- **Errores con formato uniforme.** Los errores de validación responden **422** con `{ "errors": { "<campo>": "<código>" } }`, como pide el handoff. Los códigos son `required`, `email`, `consent`, `url`, `file_type` y `file_size`, y el frontend los traduce. El resto de errores usa `ProblemDetails` (RFC 9457). Fuera de `Development` no se exponen *stack traces*.
- **Textos bilingües.** La base de datos guarda `<campo>_es` / `<campo>_en`, y la API los expone como objetos `Localized { es, en }`. El frontend elige el idioma, por lo que una sola respuesta sirve para ES y EN.
- **Fechas en UTC.** Se guardan como `timestamptz` y se generan desde un `IClock` inyectado, lo que permite probar la lógica temporal (por ejemplo, las entradas programadas).
- **Normalización.** Se recortan espacios y los correos se guardan en minúsculas. Se hace en la capa de aplicación y la base de datos lo verifica con `CHECK`.

---

## 6. API

Las respuestas son JSON. **Las rutas y las formas marcadas como *handoff* siguen exactamente el contrato del handoff (§9)**; las demás son extensiones de este proyecto (blog, salud, antiforgery, bandejas).

Formas principales del contrato:

```ts
type Localized = { es: string; en: string };
interface Category { id: string /* slug */; name: Localized; order: number }
interface Project {
  id: number; slug: string; category: string; stage: 'incubacion' | 'venture' | 'exit';
  year: number; name: string; visible: boolean;
  summary: Localized; description: Localized; cover: string;
  evidence: { src: string; caption: Localized }[];
  results: { value: string; label: Localized }[];
  support: ('legal' | 'fiscal' | 'comercial' | 'marca')[];
  updatedAt: string;
}
```

### 6.1 Pública

| Método | Ruta | Origen | Descripción | Rate limit |
|---|---|---|---|---|
| GET | `/api/health` | extensión | Estado de la API y de la conexión a la BD | global |
| GET | `/api/antiforgery/token` | extensión | Emite la cookie `XSRF-TOKEN` | global |
| GET | `/api/categories` | handoff | `Category[]` activas, ordenadas por `order`. Incluye además `count`, el número de proyectos visibles, para los chips del filtro | global |
| GET | `/api/projects?category=<id>` | handoff | `Project[]` **solo visibles**, ordenados por `sort_order` y `year DESC`. El filtro se resuelve en el servidor (§7) | global |
| GET | `/api/projects/{slug}` | handoff | `Project`, o **404** si no existe **o está oculto** | global |
| GET | `/api/blog/posts` | extensión | Entradas publicadas: `tag`, `q`, `page`, `pageSize` (ver §8) | global |
| GET | `/api/blog/posts/{slug}` | extensión | Detalle con `contentHtml` saneado (ES y EN), autor, etiquetas y tiempo de lectura. 404 si no existe, es borrador, está programada o archivada | global |
| GET | `/api/blog/tags` | extensión | Etiquetas con el número de entradas publicadas de cada una | global |
| POST | `/api/leads/client` | handoff | JSON `{ name, company, email, phone?, interest, message, consent: true, website: "" }` → `201 { id }`, `422 { errors }`, `429` | **forms** |
| POST | `/api/leads/talent` | handoff | `multipart/form-data` `{ name, email, area, link?, cv?, message?, consent, website }` → `201`, `422`, `413` (CV > 5 MB), `429` | **forms** |

`website` es el **honeypot**. Si llega con contenido, la API responde `201` sin guardar nada, para no darle pistas al bot. Ambos formularios guardan también el idioma activo (`lang`), para responder en el mismo.

### 6.2 Autenticación (handoff)

| Método | Ruta | Descripción | Rate limit |
|---|---|---|---|
| POST | `/api/auth/login` | `{ email, password }` → `204` + cookie de sesión `HttpOnly`. `401` con mensaje genérico ante cualquier fallo | **login** |
| POST | `/api/auth/logout` | Revoca la sesión actual y borra la cookie → `204`. Siempre es POST, nunca GET (handoff §6.17) | global |
| GET | `/api/auth/me` | `{ email }` del administrador autenticado, o `401`. Lo usa el guard del frontend | global |

### 6.3 Administración (todas requieren sesión)

Toda ruta bajo `/api/admin/*` exige la política `AdminOnly`. Se aplica a nivel de grupo de controladores, así que ninguna acción queda pública por omisión.

**Proyectos**

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/api/admin/projects` | *handoff*: `Project[]` **todos**, incluidos los ocultos. La búsqueda por nombre se hace en el cliente |
| GET | `/api/admin/projects/{id}` | *handoff*: `Project`, más `version` para el control de concurrencia |
| POST | `/api/admin/projects` | *handoff*: `multipart/form-data` con los campos del proyecto como JSON en `data`, más `cover` y `evidence[]` → `201 Project`. Se crea oculto |
| PUT | `/api/admin/projects/{id}` | *handoff*: mismo formato que POST → `200 Project`. Exige `version` y responde 409 si otro administrador lo modificó antes. Reemplaza resultados, áreas y evidencias en una sola transacción |
| PATCH | `/api/admin/projects/{id}` | *handoff*: `{ visible: boolean }` → `200 Project`. Publicar exige portada y los textos en ES y EN; si falta algo responde `422` con el campo que falta |
| GET | `/api/admin/categories` | Todas las categorías, incluidas las inactivas, para los selectores del editor |
| GET | `/api/admin/support-areas` | Catálogo de áreas de respaldo |

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
| GET | `/api/admin/leads/client` | Bandeja de clientes e inversionistas |
| GET | `/api/admin/leads/talent` | Bandeja de postulaciones |
| GET | `/api/admin/leads/talent/{id}/cv` | Descarga el CV en PDF desde el almacenamiento privado, con `Content-Disposition: attachment`. Solo con sesión |

> Los proyectos y las entradas del blog **no se borran**: los proyectos se ocultan y las entradas se archivan. Así se conserva el historial y se evitan borrados accidentales entre varios administradores.

---

## 7. Galería: filtros en el servidor

`GET /api/projects` sigue el contrato del handoff: un arreglo `Project[]`, **sin paginación**. El portafolio es pequeño y el frontend muestra todos los proyectos de la categoría elegida.

| Parámetro | Regla | Uso |
|---|---|---|
| `category` | slug `^[a-z0-9-]{1,40}$`, opcional. Un valor con formato inválido → `422`; una categoría inexistente → `[]` | `categories.slug = @p AND categories.is_active` |

- **Siempre** se aplica `is_visible = true`, sin importar los parámetros. Un proyecto oculto no aparece ni en el listado ni en `GET /api/projects/{slug}`, que responde 404.
- El orden es fijo en el código: `sort_order`, después `year DESC`.
- El frontend guarda el filtro en la URL como `?categoria=<id>` (handoff §6.6), de modo que se puede compartir y sobrevive al botón Atrás. Cada cambio dispara una nueva consulta a la API: **el filtro se resuelve en el servidor**.
- Los conteos de los chips salen de `GET /api/categories`.

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
- Para publicar hacen falta **portada** y el título, el extracto y el contenido **en español y en inglés**. Un borrador puede guardarse solo en español. La regla se valida en el servicio y la base de datos la refuerza con un `CHECK`.
- El editor tiene pestañas ES/EN, igual que el editor de proyectos del handoff, y el sitio muestra el idioma activo.
- Si al publicar no se envía `publishedAt`, se usa la fecha actual. Al volver a publicar una entrada archivada se conserva su fecha original.
- El autor es el administrador que creó la entrada. Si su cuenta se elimina, el sitio muestra "Grupo Ricartti".

### 8.2 Contenido: Markdown renderizado de forma segura

El contenido se guarda **solo en Markdown** (`content_markdown_es` / `content_markdown_en`), que es la única fuente de verdad. El HTML se genera en la API al leer la entrada:

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

- La cookie de sesión es `SameSite=Strict`, así que otro sitio no puede hacer que el navegador la envíe. El handoff pide `Lax` como mínimo; `Strict` es más restrictivo y compatible con la SPA, porque todas las peticiones de la API son del mismo sitio.
- Además, **antiforgery de ASP.NET Core** en el login y en todo `POST/PUT/PATCH/DELETE` bajo `/api/admin` (lote 4). **Los formularios públicos (`/api/leads/*`) no lo exigen**: son anónimos, no usan la sesión, no hay nada que un tercero pueda hacer en nombre del usuario, y los protegen el honeypot y el límite de peticiones. Para el resto: la API emite la cookie legible `XSRF-TOKEN` y espera la cabecera `X-XSRF-TOKEN`. Angular `HttpClient` hace esto de forma automática para URL relativas.
- El token antiforgery está ligado a la identidad, por lo que el frontend **pide uno nuevo después del login y del logout**.

### 9.4 Frontend

`adminGuard` (`canMatch`) consulta `/api/auth/me` antes de cargar el módulo `/admin`, que se carga de forma diferida. El guard **solo mejora la experiencia de uso**: la protección real está en el servidor. Si la API responde 401 a una petición de administración, un interceptor redirige a `/admin/login`.

---

## 10. Requisitos de seguridad

| # | Requisito | Implementación | Dónde |
|---|---|---|---|
| 1 | Validación de entradas en el servidor | Validadores de campo en la capa de aplicación para cada formulario: longitudes iguales a las de la BD, formatos (correo, teléfono, URL `https`, slug), valores de enums en lista blanca, rechazo de caracteres de control, máximo 5 etiquetas por entrada y fechas de programación válidas. Las subidas se validan por tamaño, MIME **y firma binaria** (magic bytes). Además hay restricciones `CHECK` en la BD como última barrera | `Application/*/Validators`, `Infrastructure/Storage`, `01_schema.sql` |
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
- Las imágenes del seed viven en `uploads/seed/` y están versionadas; las subidas en tiempo de ejecución están en `.gitignore`. Las de proyectos son los WebP del asset pack del handoff; las del blog son PNG generados en el mismo estilo.
- **CV de postulantes (PDF ≤ 5 MB):**
  - Se validan la firma `%PDF-` y el tamaño (`413` si lo supera).
  - Se guardan en `PRIVATE_FILES_PATH/cv/{guid}.pdf`, **fuera de `/uploads`**, así que no existe ninguna URL pública para ellos. En Docker van en un volumen con nombre, y en local en `private/`, que está en `.gitignore`.
  - Solo se descargan desde el panel, con sesión, y con `Content-Disposition: attachment` y `nosniff`.
  - El nombre original se guarda saneado, solo para mostrarlo.
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
│   │   ├── contact-section/        # Pestañas ARIA: client-form + talent-form (ambas montadas)
│   │   ├── settings-panel/         # Preferencias: idioma, movimiento, apariencia
│   │   └── not-found/              # 404 (con estado HTTP 404 real desde Nginx)
│   └── admin/                      # Carga diferida, detrás de adminGuard
│       ├── login/
│       ├── shell/                  # Layout del panel: menú lateral + barra superior
│       ├── projects-list/
│       ├── project-editor/         # Datos, portada, visibilidad y evidencias
│       ├── blog-list/              # Entradas, con filtro por estado
│       ├── blog-editor/            # Markdown, vista previa, etiquetas, portada y publicación
│       └── messages/               # (Opcional) Bandejas de los formularios
├── shared/ui/                      # Logo, Button, Tag, Field, Consent, Notice, Switch,
│                                   # blog-content (único uso permitido de [innerHTML])
├── core/i18n/                      # strings.json del handoff + pipe/servicio de traducción
├── core/preferences/               # applyPreferences(), localStorage "gr-prefs" (handoff §7)
├── app.routes.ts
└── app.config.ts
src/styles/                         # tokens.css y reference.css del handoff (copiados tal cual)
public/brand/                       # Logos, favicons y manifest del asset pack
```

Los componentes siguen el handoff (§6). Los nombres de clase pueden cambiar, pero los valores de `reference.css` no.

### 13.1 Rutas

| Ruta | Vista |
|---|---|
| `/` | Landing (handoff §4): NavBar, Hero, ProjectGallery, ModelBand, ContactSection, Footer |
| `/proyectos/:slug` | Landing con el detalle de ese proyecto **abierto** (diálogo). Slug oculto o inexistente → 404 |
| `/aviso-de-privacidad` | Página de texto simple (handoff, apéndice A) |
| `/blog` · `/blog/:slug` | Listado y entrada del blog *(extensión)* |
| `/admin/login` | Inicio de sesión. Si ya hay sesión, redirige a `/admin` |
| `/admin` | Lista de proyectos (handoff) |
| `/admin/proyectos/nuevo` · `/admin/proyectos/:id` | Editor de proyectos (handoff) |
| `/admin/blog` · `/admin/blog/nueva` · `/admin/blog/:id` | Lista y editor de entradas *(extensión)* |
| `/admin/mensajes` | *(Opcional)* Bandejas de clientes y postulaciones |
| `*` | 404, con estado HTTP 404 real |

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
- **Sin** Angular Material, Tailwind, *service worker* ni SSR. El diseño se implementa con CSS plano a partir de `tokens.css` y `reference.css` del handoff, con unidades `rem`, `color-scheme`, `prefers-contrast` y `prefers-reduced-motion` (handoff §5 y §7).
- **Bilingüe:** español por defecto e inglés, con los textos de `strings.json` del handoff. El idioma vive en las preferencias (`gr-prefs`), no en la ruta. Los datos de la API llegan en los dos idiomas y la vista elige uno.
- **Fuentes:** el handoff las carga desde Google Fonts, pero aquí se **alojan en el propio proyecto** (mismas familias y pesos: Khula 400/600, Roboto Slab 300/400, Ubuntu 300/400/500). Así la CSP puede ser `font-src 'self'` y no se envían datos de visitantes a terceros. El asset pack lo permite ("To self-host them, download the same families").
- **404 real:** en Docker, Nginx conoce las rutas válidas de la SPA y responde a cualquier otra con `index.html` y **estado 404**. Para `/proyectos/:slug`, el detalle consulta la API y, si recibe 404, muestra la página de error.
- **Accesibilidad:** se cumplen las reglas del handoff (§8): foco visible, diálogos nativos, objetivos de 44 px, avisos sin temporizador y un análisis axe sin errores graves.

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
