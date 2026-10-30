-- =====================================================================
-- Grupo Ricartti — 01: esquema relacional (PostgreSQL 16+)
-- ---------------------------------------------------------------------
-- Fuente de verdad del modelo de datos. EF Core mapea estas tablas;
-- no se usan migraciones. Alineado con el contrato del handoff de
-- frontend (§9): contenido bilingüe ES/EN, etapas, áreas de respaldo.
--
-- Se ejecuta conectado a la base de la aplicación y con el rol de la
-- aplicación activo, para que ese rol sea dueño de los objetos:
--
--   psql -U postgres -d ricartti -c "SET ROLE ricartti_app" -f database/sql/01_schema.sql
--
-- Convenciones:
--   · Claves primarias: identity (GENERATED ALWAYS), salvo catálogos
--     con código natural (support_areas).
--   · Fechas: timestamptz en UTC.
--   · Texto bilingüe: columnas <campo>_es / <campo>_en. Español es el
--     idioma fuente; el inglés puede faltar en borradores, pero es
--     obligatorio para publicar (CHECK).
--   · Códigos de dominio: varchar + CHECK con lista cerrada, en el mismo
--     valor estable que usa el frontend.
--   · Nombres de restricciones: pk_, fk_, uq_, ck_, ix_ + tabla + detalle.
-- =====================================================================
\set ON_ERROR_STOP on
SET client_encoding = 'UTF8';
SET client_min_messages = warning;

BEGIN;

-- Búsqueda sin acentos ("credito" encuentra "Crédito").
-- Extensión "trusted": la puede crear el dueño de la base sin ser superusuario.
CREATE EXTENSION IF NOT EXISTS unaccent;

-- ---------------------------------------------------------------------
-- Función de trigger: mantiene updated_at en cada UPDATE.
-- ---------------------------------------------------------------------
CREATE FUNCTION set_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;


-- =====================================================================
-- ADMINISTRACIÓN
-- =====================================================================

-- ---------------------------------------------------------------------
-- admins: cuentas del panel. Todas con los mismos permisos.
-- ---------------------------------------------------------------------
CREATE TABLE admins (
    id                  bigint       GENERATED ALWAYS AS IDENTITY,
    email               varchar(254) NOT NULL,
    full_name           varchar(120) NOT NULL,
    password_hash       varchar(100) NOT NULL,
    is_active           boolean      NOT NULL DEFAULT true,
    failed_login_count  smallint     NOT NULL DEFAULT 0,
    lockout_until       timestamptz,
    last_login_at       timestamptz,
    created_at          timestamptz  NOT NULL DEFAULT now(),
    updated_at          timestamptz  NOT NULL DEFAULT now(),

    CONSTRAINT pk_admins PRIMARY KEY (id),
    CONSTRAINT uq_admins_email UNIQUE (email),
    -- Correo normalizado (minúsculas, sin espacios) y con forma válida.
    CONSTRAINT ck_admins_email_format
        CHECK (email = lower(btrim(email)) AND email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
    CONSTRAINT ck_admins_full_name_not_blank CHECK (btrim(full_name) <> ''),
    -- Solo se aceptan hashes bcrypt ($2a$/$2b$/$2y$, 60 caracteres).
    CONSTRAINT ck_admins_password_hash_bcrypt
        CHECK (password_hash ~ '^\$2[aby]\$[0-9]{2}\$[./A-Za-z0-9]{53}$'),
    CONSTRAINT ck_admins_failed_login_count CHECK (failed_login_count >= 0)
);

COMMENT ON TABLE  admins IS 'Administradores del panel. Se crean desde el script de datos (sin pantalla de gestión).';
COMMENT ON COLUMN admins.password_hash IS 'Hash bcrypt. La contraseña en texto plano nunca se almacena.';
COMMENT ON COLUMN admins.lockout_until IS 'Bloqueo temporal tras demasiados intentos fallidos.';

CREATE TRIGGER trg_admins_updated_at
    BEFORE UPDATE ON admins
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();


-- ---------------------------------------------------------------------
-- admin_sessions: sesiones de servidor (cookie HttpOnly).
-- Se guarda solo el SHA-256 del token, nunca el token.
-- ---------------------------------------------------------------------
CREATE TABLE admin_sessions (
    id                   bigint       GENERATED ALWAYS AS IDENTITY,
    admin_id             bigint       NOT NULL,
    token_hash           bytea        NOT NULL,
    created_at           timestamptz  NOT NULL DEFAULT now(),
    last_seen_at         timestamptz  NOT NULL DEFAULT now(),
    expires_at           timestamptz  NOT NULL,
    absolute_expires_at  timestamptz  NOT NULL,
    revoked_at           timestamptz,
    ip_address           inet,
    user_agent           varchar(512),

    CONSTRAINT pk_admin_sessions PRIMARY KEY (id),
    CONSTRAINT fk_admin_sessions_admin
        FOREIGN KEY (admin_id) REFERENCES admins (id) ON DELETE CASCADE,
    CONSTRAINT uq_admin_sessions_token_hash UNIQUE (token_hash),
    CONSTRAINT ck_admin_sessions_token_hash_length CHECK (octet_length(token_hash) = 32),
    -- La expiración deslizante nunca supera la absoluta.
    CONSTRAINT ck_admin_sessions_expiry_order
        CHECK (created_at < expires_at AND expires_at <= absolute_expires_at),
    CONSTRAINT ck_admin_sessions_last_seen CHECK (last_seen_at >= created_at),
    CONSTRAINT ck_admin_sessions_revoked_at CHECK (revoked_at IS NULL OR revoked_at >= created_at)
);

COMMENT ON TABLE  admin_sessions IS 'Sesiones activas e históricas. Revocar = fijar revoked_at.';
COMMENT ON COLUMN admin_sessions.token_hash IS 'SHA-256 (32 bytes) del token aleatorio enviado en la cookie.';
COMMENT ON COLUMN admin_sessions.expires_at IS 'Expiración deslizante (inactividad).';
COMMENT ON COLUMN admin_sessions.absolute_expires_at IS 'Límite máximo de vida de la sesión.';

CREATE INDEX ix_admin_sessions_admin_id ON admin_sessions (admin_id);
CREATE INDEX ix_admin_sessions_absolute_expires_at ON admin_sessions (absolute_expires_at);


-- =====================================================================
-- PORTAFOLIO DE PROYECTOS
-- =====================================================================

-- ---------------------------------------------------------------------
-- categories: filtro de la galería. El slug es el "id" del contrato.
-- ---------------------------------------------------------------------
CREATE TABLE categories (
    id          smallint     GENERATED ALWAYS AS IDENTITY,
    slug        varchar(40)  NOT NULL,
    name_es     varchar(60)  NOT NULL,
    name_en     varchar(60)  NOT NULL,
    sort_order  smallint     NOT NULL DEFAULT 0,
    is_active   boolean      NOT NULL DEFAULT true,
    created_at  timestamptz  NOT NULL DEFAULT now(),
    updated_at  timestamptz  NOT NULL DEFAULT now(),

    CONSTRAINT pk_categories PRIMARY KEY (id),
    CONSTRAINT uq_categories_slug UNIQUE (slug),
    CONSTRAINT ck_categories_slug_format CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
    CONSTRAINT ck_categories_names_not_blank
        CHECK (btrim(name_es) <> '' AND btrim(name_en) <> ''),
    CONSTRAINT ck_categories_sort_order CHECK (sort_order >= 0)
);

-- Nombre único sin distinguir mayúsculas, por idioma.
CREATE UNIQUE INDEX uq_categories_name_es_ci ON categories (lower(name_es));
CREATE UNIQUE INDEX uq_categories_name_en_ci ON categories (lower(name_en));

COMMENT ON TABLE  categories IS 'Categorías de proyectos. Las inactivas no aparecen en el filtro público.';
COMMENT ON COLUMN categories.slug IS 'Identificador público (Category.id en el contrato, ?categoria=<slug>).';

CREATE TRIGGER trg_categories_updated_at
    BEFORE UPDATE ON categories
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();


-- ---------------------------------------------------------------------
-- support_areas: catálogo de áreas de respaldo del grupo.
-- Código natural como PK: es el valor estable del contrato.
-- ---------------------------------------------------------------------
CREATE TABLE support_areas (
    code        varchar(20)  NOT NULL,
    name_es     varchar(60)  NOT NULL,
    name_en     varchar(60)  NOT NULL,
    sort_order  smallint     NOT NULL DEFAULT 0,

    CONSTRAINT pk_support_areas PRIMARY KEY (code),
    CONSTRAINT ck_support_areas_code_format CHECK (code ~ '^[a-z]+$'),
    CONSTRAINT ck_support_areas_names_not_blank
        CHECK (btrim(name_es) <> '' AND btrim(name_en) <> '')
);

COMMENT ON TABLE support_areas IS 'Áreas con las que el grupo respalda a cada proyecto (legal, fiscal, comercial, marca).';


-- ---------------------------------------------------------------------
-- projects: tarjetas de la galería y su detalle.
-- ---------------------------------------------------------------------
CREATE TABLE projects (
    id                bigint        GENERATED ALWAYS AS IDENTITY,
    category_id       smallint      NOT NULL,
    slug              varchar(80)   NOT NULL,
    name              varchar(120)  NOT NULL,
    stage             varchar(12)   NOT NULL,
    year              smallint      NOT NULL,
    summary_es        varchar(120),
    summary_en        varchar(120),
    description_es    text,
    description_en    text,
    cover_image_path  varchar(300),
    is_visible        boolean       NOT NULL DEFAULT false,
    sort_order        integer       NOT NULL DEFAULT 0,
    created_by        bigint,
    updated_by        bigint,
    created_at        timestamptz   NOT NULL DEFAULT now(),
    updated_at        timestamptz   NOT NULL DEFAULT now(),

    CONSTRAINT pk_projects PRIMARY KEY (id),
    -- Una categoría con proyectos no se puede borrar (se desactiva).
    CONSTRAINT fk_projects_category
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE RESTRICT,
    -- Si se elimina un administrador, se conserva el proyecto.
    CONSTRAINT fk_projects_created_by
        FOREIGN KEY (created_by) REFERENCES admins (id) ON DELETE SET NULL,
    CONSTRAINT fk_projects_updated_by
        FOREIGN KEY (updated_by) REFERENCES admins (id) ON DELETE SET NULL,
    CONSTRAINT uq_projects_slug UNIQUE (slug),
    CONSTRAINT ck_projects_slug_format CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
    CONSTRAINT ck_projects_name_not_blank CHECK (btrim(name) <> ''),
    CONSTRAINT ck_projects_stage CHECK (stage IN ('incubacion', 'venture', 'exit')),
    CONSTRAINT ck_projects_year CHECK (year BETWEEN 1990 AND 2100),
    CONSTRAINT ck_projects_texts_not_blank CHECK (
        (summary_es     IS NULL OR btrim(summary_es)     <> '') AND
        (summary_en     IS NULL OR btrim(summary_en)     <> '') AND
        (description_es IS NULL OR btrim(description_es) <> '') AND
        (description_en IS NULL OR btrim(description_en) <> '')
    ),
    CONSTRAINT ck_projects_description_length CHECK (
        (description_es IS NULL OR char_length(description_es) <= 5000) AND
        (description_en IS NULL OR char_length(description_en) <= 5000)
    ),
    -- Rutas internas generadas por el servidor: sin "..", sin espacios,
    -- solo formatos raster permitidos (SVG excluido a propósito).
    CONSTRAINT ck_projects_cover_path_format
        CHECK (cover_image_path IS NULL
               OR cover_image_path ~ '^/uploads/[A-Za-z0-9_/-]+\.(jpg|jpeg|png|webp)$'),
    -- Publicar exige portada y el texto completo en los DOS idiomas (handoff §6.17).
    CONSTRAINT ck_projects_visible_requires_content CHECK (
        NOT is_visible OR (
            cover_image_path IS NOT NULL
            AND summary_es IS NOT NULL AND summary_en IS NOT NULL
            AND description_es IS NOT NULL AND description_en IS NOT NULL
        )
    ),
    CONSTRAINT ck_projects_sort_order CHECK (sort_order >= 0)
);

COMMENT ON TABLE  projects IS 'Proyectos del portafolio. No se borran: se ocultan (is_visible = false).';
COMMENT ON COLUMN projects.slug IS 'Identificador público en la URL (/proyectos/:slug). Único y editable desde el panel.';
COMMENT ON COLUMN projects.stage IS 'incubacion · venture · exit (vendido).';
COMMENT ON COLUMN projects.summary_es IS 'Descripción breve de la tarjeta (≤ 120 caracteres).';
COMMENT ON COLUMN projects.description_es IS 'Texto plano del detalle (sin HTML).';

CREATE INDEX ix_projects_category_id ON projects (category_id);
-- Índice parcial para la galería pública (solo proyectos visibles).
CREATE INDEX ix_projects_public_listing
    ON projects (sort_order, year DESC)
    WHERE is_visible;

CREATE TRIGGER trg_projects_updated_at
    BEFORE UPDATE ON projects
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();


-- ---------------------------------------------------------------------
-- project_support_areas: relación N:M proyecto ↔ área de respaldo.
-- ---------------------------------------------------------------------
CREATE TABLE project_support_areas (
    project_id  bigint       NOT NULL,
    area_code   varchar(20)  NOT NULL,

    CONSTRAINT pk_project_support_areas PRIMARY KEY (project_id, area_code),
    CONSTRAINT fk_project_support_areas_project
        FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE,
    CONSTRAINT fk_project_support_areas_area
        FOREIGN KEY (area_code) REFERENCES support_areas (code) ON DELETE RESTRICT
);

CREATE INDEX ix_project_support_areas_area ON project_support_areas (area_code);


-- ---------------------------------------------------------------------
-- project_images: evidencias en imagen (con pie de foto bilingüe).
-- ---------------------------------------------------------------------
CREATE TABLE project_images (
    id          bigint        GENERATED ALWAYS AS IDENTITY,
    project_id  bigint        NOT NULL,
    image_path  varchar(300)  NOT NULL,
    caption_es  varchar(150)  NOT NULL,
    caption_en  varchar(150),
    sort_order  integer       NOT NULL DEFAULT 0,
    created_at  timestamptz   NOT NULL DEFAULT now(),
    updated_at  timestamptz   NOT NULL DEFAULT now(),

    CONSTRAINT pk_project_images PRIMARY KEY (id),
    -- Las evidencias pertenecen al proyecto y desaparecen con él.
    CONSTRAINT fk_project_images_project
        FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE,
    CONSTRAINT ck_project_images_path_format
        CHECK (image_path ~ '^/uploads/[A-Za-z0-9_/-]+\.(jpg|jpeg|png|webp)$'),
    -- El pie de foto es también el texto alternativo de la imagen.
    CONSTRAINT ck_project_images_captions_not_blank CHECK (
        btrim(caption_es) <> '' AND (caption_en IS NULL OR btrim(caption_en) <> '')
    ),
    CONSTRAINT ck_project_images_sort_order CHECK (sort_order >= 0)
);

COMMENT ON TABLE  project_images IS 'Evidencias en imagen del detalle. El pie de foto se usa como alt.';

CREATE INDEX ix_project_images_project_order ON project_images (project_id, sort_order);

CREATE TRIGGER trg_project_images_updated_at
    BEFORE UPDATE ON project_images
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();


-- ---------------------------------------------------------------------
-- project_results: cifras del detalle ("+38%", "1,200", "$84 M").
-- ---------------------------------------------------------------------
CREATE TABLE project_results (
    id          bigint        GENERATED ALWAYS AS IDENTITY,
    project_id  bigint        NOT NULL,
    value       varchar(30)   NOT NULL,
    label_es    varchar(100)  NOT NULL,
    label_en    varchar(100),
    sort_order  integer       NOT NULL DEFAULT 0,
    created_at  timestamptz   NOT NULL DEFAULT now(),
    updated_at  timestamptz   NOT NULL DEFAULT now(),

    CONSTRAINT pk_project_results PRIMARY KEY (id),
    CONSTRAINT fk_project_results_project
        FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE,
    CONSTRAINT ck_project_results_texts_not_blank CHECK (
        btrim(value) <> '' AND btrim(label_es) <> ''
        AND (label_en IS NULL OR btrim(label_en) <> '')
    ),
    CONSTRAINT ck_project_results_sort_order CHECK (sort_order >= 0)
);

COMMENT ON TABLE  project_results IS 'Resultados del detalle. value es texto de presentación, no un número.';

CREATE INDEX ix_project_results_project_order ON project_results (project_id, sort_order);

CREATE TRIGGER trg_project_results_updated_at
    BEFORE UPDATE ON project_results
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();


-- =====================================================================
-- BLOG (bilingüe ES/EN)
-- =====================================================================

-- ---------------------------------------------------------------------
-- blog_tags: etiquetas de las entradas (filtro del blog).
-- ---------------------------------------------------------------------
CREATE TABLE blog_tags (
    id          smallint     GENERATED ALWAYS AS IDENTITY,
    slug        varchar(40)  NOT NULL,
    name_es     varchar(40)  NOT NULL,
    name_en     varchar(40)  NOT NULL,
    created_at  timestamptz  NOT NULL DEFAULT now(),

    CONSTRAINT pk_blog_tags PRIMARY KEY (id),
    CONSTRAINT uq_blog_tags_slug UNIQUE (slug),
    CONSTRAINT ck_blog_tags_slug_format CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
    CONSTRAINT ck_blog_tags_names_not_blank
        CHECK (btrim(name_es) <> '' AND btrim(name_en) <> '')
);

CREATE UNIQUE INDEX uq_blog_tags_name_es_ci ON blog_tags (lower(name_es));

COMMENT ON TABLE blog_tags IS 'Etiquetas del blog. Se crean desde el editor de entradas.';


-- ---------------------------------------------------------------------
-- blog_posts: entradas del blog, bilingües.
--   status = 'draft'     → borrador, solo en el panel (el inglés puede faltar).
--   status = 'published' → pública cuando published_at <= now()
--                          (con fecha futura queda programada).
--   status = 'archived'  → retirada del sitio, se conserva.
-- El contenido se guarda en Markdown; la API lo convierte a HTML
-- saneado al leerlo (una sola fuente de verdad).
-- ---------------------------------------------------------------------
CREATE TABLE blog_posts (
    id                   bigint        GENERATED ALWAYS AS IDENTITY,
    slug                 varchar(190)  NOT NULL,
    title_es             varchar(180)  NOT NULL,
    title_en             varchar(180),
    excerpt_es           varchar(300)  NOT NULL,
    excerpt_en           varchar(300),
    content_markdown_es  text          NOT NULL,
    content_markdown_en  text,
    cover_image_path     varchar(300),
    status               varchar(10)   NOT NULL DEFAULT 'draft',
    published_at         timestamptz,
    reading_minutes      smallint      NOT NULL DEFAULT 1,
    author_id            bigint,
    created_by           bigint,
    updated_by           bigint,
    created_at           timestamptz   NOT NULL DEFAULT now(),
    updated_at           timestamptz   NOT NULL DEFAULT now(),

    CONSTRAINT pk_blog_posts PRIMARY KEY (id),
    -- Si se elimina el administrador, la entrada se conserva
    -- (el sitio muestra "Grupo Ricartti" como autor).
    CONSTRAINT fk_blog_posts_author
        FOREIGN KEY (author_id) REFERENCES admins (id) ON DELETE SET NULL,
    CONSTRAINT fk_blog_posts_created_by
        FOREIGN KEY (created_by) REFERENCES admins (id) ON DELETE SET NULL,
    CONSTRAINT fk_blog_posts_updated_by
        FOREIGN KEY (updated_by) REFERENCES admins (id) ON DELETE SET NULL,
    CONSTRAINT uq_blog_posts_slug UNIQUE (slug),
    CONSTRAINT ck_blog_posts_slug_format CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
    CONSTRAINT ck_blog_posts_texts_not_blank CHECK (
        btrim(title_es) <> '' AND btrim(excerpt_es) <> '' AND btrim(content_markdown_es) <> ''
        AND (title_en            IS NULL OR btrim(title_en)            <> '')
        AND (excerpt_en          IS NULL OR btrim(excerpt_en)          <> '')
        AND (content_markdown_en IS NULL OR btrim(content_markdown_en) <> '')
    ),
    CONSTRAINT ck_blog_posts_content_length CHECK (
        char_length(content_markdown_es) <= 50000
        AND (content_markdown_en IS NULL OR char_length(content_markdown_en) <= 50000)
    ),
    CONSTRAINT ck_blog_posts_status CHECK (status IN ('draft', 'published', 'archived')),
    -- Publicar exige fecha, portada y la versión en inglés completa.
    CONSTRAINT ck_blog_posts_published_requires_content CHECK (
        status <> 'published' OR (
            published_at IS NOT NULL
            AND cover_image_path IS NOT NULL
            AND title_en IS NOT NULL AND excerpt_en IS NOT NULL AND content_markdown_en IS NOT NULL
        )
    ),
    CONSTRAINT ck_blog_posts_cover_path_format
        CHECK (cover_image_path IS NULL
               OR cover_image_path ~ '^/uploads/[A-Za-z0-9_/-]+\.(jpg|jpeg|png|webp)$'),
    CONSTRAINT ck_blog_posts_reading_minutes CHECK (reading_minutes BETWEEN 1 AND 600)
);

COMMENT ON TABLE  blog_posts IS 'Entradas del blog (ES/EN). No se borran: se archivan.';
COMMENT ON COLUMN blog_posts.content_markdown_es IS 'Fuente en Markdown. El HTML se genera y sanea en la API (HTML crudo deshabilitado).';
COMMENT ON COLUMN blog_posts.published_at IS 'Fecha de publicación. Si es futura y status = published, la entrada está programada.';
COMMENT ON COLUMN blog_posts.reading_minutes IS 'Tiempo estimado de lectura (versión en español), calculado por la API al guardar.';

-- Blog público: publicadas, de la más reciente a la más antigua.
CREATE INDEX ix_blog_posts_public_listing
    ON blog_posts (published_at DESC)
    WHERE status = 'published';
CREATE INDEX ix_blog_posts_status_updated ON blog_posts (status, updated_at DESC);
CREATE INDEX ix_blog_posts_author_id ON blog_posts (author_id);

CREATE TRIGGER trg_blog_posts_updated_at
    BEFORE UPDATE ON blog_posts
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();


-- ---------------------------------------------------------------------
-- blog_post_tags: relación N:M entre entradas y etiquetas.
-- ---------------------------------------------------------------------
CREATE TABLE blog_post_tags (
    post_id  bigint    NOT NULL,
    tag_id   smallint  NOT NULL,

    CONSTRAINT pk_blog_post_tags PRIMARY KEY (post_id, tag_id),
    CONSTRAINT fk_blog_post_tags_post
        FOREIGN KEY (post_id) REFERENCES blog_posts (id) ON DELETE CASCADE,
    -- Una etiqueta en uso no se puede borrar.
    CONSTRAINT fk_blog_post_tags_tag
        FOREIGN KEY (tag_id) REFERENCES blog_tags (id) ON DELETE RESTRICT
);

COMMENT ON TABLE blog_post_tags IS 'Etiquetas asignadas a cada entrada (máximo 5 por entrada, regla de la API).';

CREATE INDEX ix_blog_post_tags_tag_id ON blog_post_tags (tag_id);


-- =====================================================================
-- FORMULARIOS (leads)
-- =====================================================================

-- ---------------------------------------------------------------------
-- client_leads: formulario "Soy cliente o inversionista".
-- ---------------------------------------------------------------------
CREATE TABLE client_leads (
    id                   bigint         GENERATED ALWAYS AS IDENTITY,
    full_name            varchar(120)   NOT NULL,
    company              varchar(120)   NOT NULL,
    email                varchar(254)   NOT NULL,
    phone                varchar(20),
    interest             varchar(12)    NOT NULL,
    message              varchar(2000)  NOT NULL,
    lang                 varchar(2)     NOT NULL DEFAULT 'es',
    privacy_accepted_at  timestamptz    NOT NULL,
    status               varchar(20)    NOT NULL DEFAULT 'new',
    ip_address           inet,
    user_agent           varchar(512),
    created_at           timestamptz    NOT NULL DEFAULT now(),
    updated_at           timestamptz    NOT NULL DEFAULT now(),

    CONSTRAINT pk_client_leads PRIMARY KEY (id),
    CONSTRAINT ck_client_leads_full_name CHECK (char_length(btrim(full_name)) >= 2),
    CONSTRAINT ck_client_leads_company CHECK (btrim(company) <> ''),
    CONSTRAINT ck_client_leads_email_format
        CHECK (email = lower(btrim(email)) AND email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
    CONSTRAINT ck_client_leads_phone_format
        CHECK (phone IS NULL OR phone ~ '^\+?[0-9][0-9 ()-]{6,19}$'),
    -- Valores estables del handoff (§6.11); la etiqueta se traduce en el frontend.
    CONSTRAINT ck_client_leads_interest
        CHECK (interest IN ('acquire', 'coinvest', 'incubate', 'services')),
    CONSTRAINT ck_client_leads_message CHECK (btrim(message) <> ''),
    CONSTRAINT ck_client_leads_lang CHECK (lang IN ('es', 'en')),
    CONSTRAINT ck_client_leads_status
        CHECK (status IN ('new', 'reviewed', 'contacted', 'archived'))
);

COMMENT ON TABLE  client_leads IS 'Formulario de clientes, inversionistas y compradores.';
COMMENT ON COLUMN client_leads.interest IS 'acquire = adquirir un proyecto · coinvest = coinvertir · incubate = incubar · services = servicios legales/comerciales/fiscales.';
COMMENT ON COLUMN client_leads.lang IS 'Idioma en que se envió el formulario, para responder en el mismo.';
COMMENT ON COLUMN client_leads.privacy_accepted_at IS 'Momento en que se aceptó el aviso de privacidad (obligatorio).';
COMMENT ON COLUMN client_leads.ip_address IS 'IP de origen, para trazabilidad ante abuso.';

CREATE INDEX ix_client_leads_status_created ON client_leads (status, created_at DESC);

CREATE TRIGGER trg_client_leads_updated_at
    BEFORE UPDATE ON client_leads
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();


-- ---------------------------------------------------------------------
-- talent_applications: formulario "Quiero trabajar en Grupo Ricartti".
-- El CV (PDF opcional) se guarda en almacenamiento PRIVADO, fuera de
-- /uploads: nunca es accesible públicamente; solo el panel lo descarga.
-- ---------------------------------------------------------------------
CREATE TABLE talent_applications (
    id                   bigint         GENERATED ALWAYS AS IDENTITY,
    full_name            varchar(120)   NOT NULL,
    email                varchar(254)   NOT NULL,
    area                 varchar(12)    NOT NULL,
    profile_url          varchar(300),
    cv_storage_key       varchar(80),
    cv_original_name     varchar(255),
    cv_size_bytes        integer,
    message              varchar(2000),
    lang                 varchar(2)     NOT NULL DEFAULT 'es',
    privacy_accepted_at  timestamptz    NOT NULL,
    status               varchar(20)    NOT NULL DEFAULT 'new',
    ip_address           inet,
    user_agent           varchar(512),
    created_at           timestamptz    NOT NULL DEFAULT now(),
    updated_at           timestamptz    NOT NULL DEFAULT now(),

    CONSTRAINT pk_talent_applications PRIMARY KEY (id),
    CONSTRAINT ck_talent_applications_full_name CHECK (char_length(btrim(full_name)) >= 2),
    CONSTRAINT ck_talent_applications_email_format
        CHECK (email = lower(btrim(email)) AND email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
    -- Valores estables del handoff (§6.12).
    CONSTRAINT ck_talent_applications_area
        CHECK (area IN ('engineering', 'brand', 'legal', 'tax', 'commercial')),
    CONSTRAINT ck_talent_applications_profile_url
        CHECK (profile_url IS NULL OR profile_url ~* '^https?://[^\s/]+\.[^\s/]+(/\S*)?$'),
    -- El nombre en disco lo genera el servidor (GUID); nunca el del usuario.
    CONSTRAINT ck_talent_applications_cv_key
        CHECK (cv_storage_key IS NULL OR cv_storage_key ~ '^cv/[0-9a-f]{32}\.pdf$'),
    -- Los tres datos del CV van juntos, y el archivo pesa como máximo 5 MB.
    CONSTRAINT ck_talent_applications_cv_consistency CHECK (
        (cv_storage_key IS NULL AND cv_original_name IS NULL AND cv_size_bytes IS NULL)
     OR (cv_storage_key IS NOT NULL AND cv_original_name IS NOT NULL
         AND cv_size_bytes BETWEEN 1 AND 5242880)
    ),
    CONSTRAINT ck_talent_applications_message
        CHECK (message IS NULL OR btrim(message) <> ''),
    CONSTRAINT ck_talent_applications_lang CHECK (lang IN ('es', 'en')),
    CONSTRAINT ck_talent_applications_status
        CHECK (status IN ('new', 'reviewed', 'shortlisted', 'archived'))
);

COMMENT ON TABLE  talent_applications IS 'Postulaciones de personas interesadas en trabajar en Grupo Ricartti.';
COMMENT ON COLUMN talent_applications.area IS 'engineering · brand · legal · tax · commercial.';
COMMENT ON COLUMN talent_applications.cv_storage_key IS 'Ruta relativa en el almacenamiento privado (PRIVATE_FILES_PATH). No se sirve en /uploads.';
COMMENT ON COLUMN talent_applications.cv_original_name IS 'Nombre original, solo para mostrarlo en el panel (saneado).';

CREATE INDEX ix_talent_applications_status_created ON talent_applications (status, created_at DESC);

CREATE TRIGGER trg_talent_applications_updated_at
    BEFORE UPDATE ON talent_applications
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMIT;
