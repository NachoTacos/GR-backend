-- =====================================================================
-- Grupo Ricartti — 01: esquema relacional (PostgreSQL 16+)
-- ---------------------------------------------------------------------
-- Fuente de verdad del modelo de datos. EF Core mapea estas tablas;
-- no se usan migraciones.
--
-- Se ejecuta conectado a la base de la aplicación y con el rol de la
-- aplicación activo, para que ese rol sea dueño de los objetos:
--
--   psql -U postgres -d ricartti -c "SET ROLE ricartti_app" -f database/sql/01_schema.sql
--
-- Convenciones:
--   · Claves primarias: identity (GENERATED ALWAYS).
--   · Fechas: timestamptz en UTC.
--   · Códigos de dominio (estados, tipos): varchar + CHECK con lista
--     cerrada, en inglés. Las etiquetas visibles se traducen en el frontend.
--   · Nombres de restricciones: pk_, fk_, uq_, ck_, ix_ + tabla + detalle.
-- =====================================================================
\set ON_ERROR_STOP on
SET client_encoding = 'UTF8';
SET client_min_messages = warning;

BEGIN;

-- Búsqueda sin acentos en la galería ("credito" encuentra "Crédito").
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
-- CATÁLOGO DE PROYECTOS
-- =====================================================================

-- ---------------------------------------------------------------------
-- categories: clasificación de los proyectos (filtro de la galería).
-- ---------------------------------------------------------------------
CREATE TABLE categories (
    id           smallint     GENERATED ALWAYS AS IDENTITY,
    name         varchar(60)  NOT NULL,
    slug         varchar(60)  NOT NULL,
    description  varchar(300),
    sort_order   smallint     NOT NULL DEFAULT 0,
    is_active    boolean      NOT NULL DEFAULT true,
    created_at   timestamptz  NOT NULL DEFAULT now(),
    updated_at   timestamptz  NOT NULL DEFAULT now(),

    CONSTRAINT pk_categories PRIMARY KEY (id),
    CONSTRAINT uq_categories_slug UNIQUE (slug),
    CONSTRAINT ck_categories_slug_format CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
    CONSTRAINT ck_categories_name_not_blank CHECK (btrim(name) <> ''),
    CONSTRAINT ck_categories_sort_order CHECK (sort_order >= 0)
);

-- Nombre único sin distinguir mayúsculas ("Fintech" = "fintech").
CREATE UNIQUE INDEX uq_categories_name_ci ON categories (lower(name));

COMMENT ON TABLE categories IS 'Categorías de proyectos. Las inactivas no aparecen en el filtro público.';

CREATE TRIGGER trg_categories_updated_at
    BEFORE UPDATE ON categories
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();


-- ---------------------------------------------------------------------
-- projects: tarjetas de la galería y su detalle.
-- ---------------------------------------------------------------------
CREATE TABLE projects (
    id                bigint        GENERATED ALWAYS AS IDENTITY,
    category_id       smallint      NOT NULL,
    title             varchar(150)  NOT NULL,
    slug              varchar(160)  NOT NULL,
    summary           varchar(300)  NOT NULL,
    description       text          NOT NULL,
    cover_image_path  varchar(300),
    is_visible        boolean       NOT NULL DEFAULT false,
    sort_order        integer       NOT NULL DEFAULT 0,
    published_at      timestamptz,
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
    CONSTRAINT ck_projects_title_not_blank CHECK (btrim(title) <> ''),
    CONSTRAINT ck_projects_summary_not_blank CHECK (btrim(summary) <> ''),
    CONSTRAINT ck_projects_description_length
        CHECK (char_length(btrim(description)) BETWEEN 1 AND 5000),
    -- Rutas internas generadas por el servidor: sin "..", sin espacios,
    -- solo formatos raster permitidos (SVG excluido a propósito).
    CONSTRAINT ck_projects_cover_path_format
        CHECK (cover_image_path IS NULL
               OR cover_image_path ~ '^/uploads/[A-Za-z0-9_/-]+\.(jpg|jpeg|png|webp)$'),
    -- Reglas de publicación.
    CONSTRAINT ck_projects_visible_requires_cover
        CHECK (NOT is_visible OR cover_image_path IS NOT NULL),
    CONSTRAINT ck_projects_visible_requires_published_at
        CHECK (NOT is_visible OR published_at IS NOT NULL),
    CONSTRAINT ck_projects_sort_order CHECK (sort_order >= 0)
);

COMMENT ON TABLE  projects IS 'Proyectos del portafolio. No se borran: se ocultan (is_visible = false).';
COMMENT ON COLUMN projects.slug IS 'Identificador público en la URL. Generado por el servidor y estable.';
COMMENT ON COLUMN projects.summary IS 'Descripción breve de la tarjeta.';
COMMENT ON COLUMN projects.description IS 'Texto plano del detalle (sin HTML).';
COMMENT ON COLUMN projects.published_at IS 'Primera publicación. Se fija al hacer visible el proyecto por primera vez.';

CREATE INDEX ix_projects_category_id ON projects (category_id);
-- Índice parcial para la galería pública (solo proyectos visibles).
CREATE INDEX ix_projects_public_listing
    ON projects (sort_order, published_at DESC)
    WHERE is_visible;

CREATE TRIGGER trg_projects_updated_at
    BEFORE UPDATE ON projects
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();


-- ---------------------------------------------------------------------
-- project_evidences: evidencias del detalle.
--   kind = 'image'  → imagen con texto alternativo.
--   kind = 'result' → métrica (valor + etiqueta), sin imagen.
-- ---------------------------------------------------------------------
CREATE TABLE project_evidences (
    id            bigint         GENERATED ALWAYS AS IDENTITY,
    project_id    bigint         NOT NULL,
    kind          varchar(10)    NOT NULL,
    title         varchar(150),
    description   varchar(1000),
    image_path    varchar(300),
    alt_text      varchar(200),
    metric_value  varchar(40),
    metric_label  varchar(100),
    sort_order    integer        NOT NULL DEFAULT 0,
    created_at    timestamptz    NOT NULL DEFAULT now(),
    updated_at    timestamptz    NOT NULL DEFAULT now(),

    CONSTRAINT pk_project_evidences PRIMARY KEY (id),
    -- Las evidencias pertenecen al proyecto y desaparecen con él.
    CONSTRAINT fk_project_evidences_project
        FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE,
    CONSTRAINT ck_project_evidences_kind CHECK (kind IN ('image', 'result')),
    -- Una evidencia es imagen O resultado, con los campos que le corresponden.
    CONSTRAINT ck_project_evidences_shape CHECK (
        (kind = 'image'
            AND image_path IS NOT NULL AND alt_text IS NOT NULL
            AND metric_value IS NULL AND metric_label IS NULL)
     OR (kind = 'result'
            AND image_path IS NULL AND alt_text IS NULL
            AND metric_value IS NOT NULL AND metric_label IS NOT NULL)
    ),
    CONSTRAINT ck_project_evidences_image_path_format
        CHECK (image_path IS NULL
               OR image_path ~ '^/uploads/[A-Za-z0-9_/-]+\.(jpg|jpeg|png|webp)$'),
    CONSTRAINT ck_project_evidences_texts_not_blank CHECK (
        (title        IS NULL OR btrim(title)        <> '') AND
        (description  IS NULL OR btrim(description)  <> '') AND
        (alt_text     IS NULL OR btrim(alt_text)     <> '') AND
        (metric_value IS NULL OR btrim(metric_value) <> '') AND
        (metric_label IS NULL OR btrim(metric_label) <> '')
    ),
    CONSTRAINT ck_project_evidences_sort_order CHECK (sort_order >= 0)
);

COMMENT ON TABLE project_evidences IS 'Evidencias del detalle de un proyecto: imágenes o resultados (métricas).';

CREATE INDEX ix_project_evidences_project_order ON project_evidences (project_id, sort_order);

CREATE TRIGGER trg_project_evidences_updated_at
    BEFORE UPDATE ON project_evidences
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();


-- =====================================================================
-- BLOG
-- =====================================================================

-- ---------------------------------------------------------------------
-- blog_tags: etiquetas de las entradas (filtro del blog).
-- ---------------------------------------------------------------------
CREATE TABLE blog_tags (
    id          smallint     GENERATED ALWAYS AS IDENTITY,
    name        varchar(40)  NOT NULL,
    slug        varchar(40)  NOT NULL,
    created_at  timestamptz  NOT NULL DEFAULT now(),

    CONSTRAINT pk_blog_tags PRIMARY KEY (id),
    CONSTRAINT uq_blog_tags_slug UNIQUE (slug),
    CONSTRAINT ck_blog_tags_slug_format CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
    CONSTRAINT ck_blog_tags_name_not_blank CHECK (btrim(name) <> '')
);

CREATE UNIQUE INDEX uq_blog_tags_name_ci ON blog_tags (lower(name));

COMMENT ON TABLE blog_tags IS 'Etiquetas del blog. Se crean desde el editor de entradas.';


-- ---------------------------------------------------------------------
-- blog_posts: entradas del blog.
--   status = 'draft'     → borrador, solo en el panel.
--   status = 'published' → pública cuando published_at <= now()
--                          (con fecha futura queda programada).
--   status = 'archived'  → retirada del sitio, se conserva.
-- El contenido se guarda en Markdown; la API lo convierte a HTML
-- saneado al leerlo (una sola fuente de verdad).
-- ---------------------------------------------------------------------
CREATE TABLE blog_posts (
    id                bigint        GENERATED ALWAYS AS IDENTITY,
    title             varchar(180)  NOT NULL,
    slug              varchar(190)  NOT NULL,
    excerpt           varchar(300)  NOT NULL,
    content_markdown  text          NOT NULL,
    cover_image_path  varchar(300),
    status            varchar(10)   NOT NULL DEFAULT 'draft',
    published_at      timestamptz,
    reading_minutes   smallint      NOT NULL DEFAULT 1,
    author_id         bigint,
    created_by        bigint,
    updated_by        bigint,
    created_at        timestamptz   NOT NULL DEFAULT now(),
    updated_at        timestamptz   NOT NULL DEFAULT now(),

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
    CONSTRAINT ck_blog_posts_title_not_blank CHECK (btrim(title) <> ''),
    CONSTRAINT ck_blog_posts_excerpt_not_blank CHECK (btrim(excerpt) <> ''),
    CONSTRAINT ck_blog_posts_content_length
        CHECK (char_length(btrim(content_markdown)) BETWEEN 1 AND 50000),
    CONSTRAINT ck_blog_posts_status CHECK (status IN ('draft', 'published', 'archived')),
    CONSTRAINT ck_blog_posts_published_requires_date
        CHECK (status <> 'published' OR published_at IS NOT NULL),
    -- Las tarjetas del blog siempre muestran portada.
    CONSTRAINT ck_blog_posts_published_requires_cover
        CHECK (status <> 'published' OR cover_image_path IS NOT NULL),
    CONSTRAINT ck_blog_posts_cover_path_format
        CHECK (cover_image_path IS NULL
               OR cover_image_path ~ '^/uploads/[A-Za-z0-9_/-]+\.(jpg|jpeg|png|webp)$'),
    CONSTRAINT ck_blog_posts_reading_minutes CHECK (reading_minutes BETWEEN 1 AND 600)
);

COMMENT ON TABLE  blog_posts IS 'Entradas del blog. No se borran: se archivan.';
COMMENT ON COLUMN blog_posts.content_markdown IS 'Fuente en Markdown. El HTML se genera y sanea en la API (HTML crudo deshabilitado).';
COMMENT ON COLUMN blog_posts.published_at IS 'Fecha de publicación. Si es futura y status = published, la entrada está programada.';
COMMENT ON COLUMN blog_posts.reading_minutes IS 'Tiempo estimado de lectura, calculado por la API al guardar.';

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
-- FORMULARIOS
-- =====================================================================

-- ---------------------------------------------------------------------
-- client_inquiries: formulario de clientes interesados.
-- ---------------------------------------------------------------------
CREATE TABLE client_inquiries (
    id                   bigint         GENERATED ALWAYS AS IDENTITY,
    full_name            varchar(120)   NOT NULL,
    email                varchar(254)   NOT NULL,
    phone                varchar(20),
    company              varchar(120),
    inquiry_type         varchar(20)    NOT NULL,
    message              varchar(2000)  NOT NULL,
    privacy_accepted_at  timestamptz    NOT NULL,
    status               varchar(20)    NOT NULL DEFAULT 'new',
    ip_address           inet,
    user_agent           varchar(512),
    created_at           timestamptz    NOT NULL DEFAULT now(),
    updated_at           timestamptz    NOT NULL DEFAULT now(),

    CONSTRAINT pk_client_inquiries PRIMARY KEY (id),
    CONSTRAINT ck_client_inquiries_full_name CHECK (char_length(btrim(full_name)) >= 2),
    CONSTRAINT ck_client_inquiries_email_format
        CHECK (email = lower(btrim(email)) AND email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
    CONSTRAINT ck_client_inquiries_phone_format
        CHECK (phone IS NULL OR phone ~ '^\+?[0-9][0-9 ()-]{6,19}$'),
    CONSTRAINT ck_client_inquiries_company_not_blank
        CHECK (company IS NULL OR btrim(company) <> ''),
    CONSTRAINT ck_client_inquiries_inquiry_type
        CHECK (inquiry_type IN ('funding', 'partnership', 'co_investment', 'other')),
    CONSTRAINT ck_client_inquiries_message_length
        CHECK (char_length(btrim(message)) >= 10),
    CONSTRAINT ck_client_inquiries_status
        CHECK (status IN ('new', 'reviewed', 'contacted', 'archived'))
);

COMMENT ON TABLE  client_inquiries IS 'Mensajes del formulario de clientes interesados.';
COMMENT ON COLUMN client_inquiries.inquiry_type IS 'funding = busca inversión · partnership = alianza · co_investment = quiere coinvertir · other.';
COMMENT ON COLUMN client_inquiries.privacy_accepted_at IS 'Momento en que se aceptó el aviso de privacidad (obligatorio).';
COMMENT ON COLUMN client_inquiries.ip_address IS 'IP de origen, para trazabilidad ante abuso.';

CREATE INDEX ix_client_inquiries_status_created ON client_inquiries (status, created_at DESC);

CREATE TRIGGER trg_client_inquiries_updated_at
    BEFORE UPDATE ON client_inquiries
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();


-- ---------------------------------------------------------------------
-- job_applications: formulario "Trabaja con nosotros".
-- ---------------------------------------------------------------------
CREATE TABLE job_applications (
    id                   bigint         GENERATED ALWAYS AS IDENTITY,
    full_name            varchar(120)   NOT NULL,
    email                varchar(254)   NOT NULL,
    phone                varchar(20),
    area_of_interest     varchar(30)    NOT NULL,
    linkedin_url         varchar(300),
    portfolio_url        varchar(300),
    message              varchar(2000)  NOT NULL,
    privacy_accepted_at  timestamptz    NOT NULL,
    status               varchar(20)    NOT NULL DEFAULT 'new',
    ip_address           inet,
    user_agent           varchar(512),
    created_at           timestamptz    NOT NULL DEFAULT now(),
    updated_at           timestamptz    NOT NULL DEFAULT now(),

    CONSTRAINT pk_job_applications PRIMARY KEY (id),
    CONSTRAINT ck_job_applications_full_name CHECK (char_length(btrim(full_name)) >= 2),
    CONSTRAINT ck_job_applications_email_format
        CHECK (email = lower(btrim(email)) AND email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
    CONSTRAINT ck_job_applications_phone_format
        CHECK (phone IS NULL OR phone ~ '^\+?[0-9][0-9 ()-]{6,19}$'),
    CONSTRAINT ck_job_applications_area
        CHECK (area_of_interest IN ('investment_analysis', 'finance', 'legal',
                                    'technology', 'marketing', 'operations', 'other')),
    -- Solo enlaces https; LinkedIn debe pertenecer a linkedin.com.
    CONSTRAINT ck_job_applications_linkedin_url
        CHECK (linkedin_url IS NULL
               OR linkedin_url ~* '^https://([a-z0-9-]+\.)?linkedin\.com/\S+$'),
    CONSTRAINT ck_job_applications_portfolio_url
        CHECK (portfolio_url IS NULL OR portfolio_url ~* '^https://[^\s/]+\.[^\s/]+(/\S*)?$'),
    -- Se pide al menos un perfil (no se reciben CV como archivo).
    CONSTRAINT ck_job_applications_has_profile
        CHECK (linkedin_url IS NOT NULL OR portfolio_url IS NOT NULL),
    CONSTRAINT ck_job_applications_message_length
        CHECK (char_length(btrim(message)) >= 10),
    CONSTRAINT ck_job_applications_status
        CHECK (status IN ('new', 'reviewed', 'shortlisted', 'archived'))
);

COMMENT ON TABLE  job_applications IS 'Postulaciones de personas interesadas en trabajar en Grupo Ricartti.';
COMMENT ON COLUMN job_applications.privacy_accepted_at IS 'Momento en que se aceptó el aviso de privacidad (obligatorio).';

CREATE INDEX ix_job_applications_status_created ON job_applications (status, created_at DESC);

CREATE TRIGGER trg_job_applications_updated_at
    BEFORE UPDATE ON job_applications
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMIT;
