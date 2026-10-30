--
-- PostgreSQL database dump
--

\restrict qoMalqLqwL012wfQ9mDfQJgCj4IDKiWtCukG982n2AGqTPPRRZ89ezsJYDfVhIb

-- Dumped from database version 17.11
-- Dumped by pg_dump version 17.11

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: unaccent; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;


--
-- Name: EXTENSION unaccent; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION unaccent IS 'text search dictionary that removes accents';


--
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: admin_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_sessions (
    id bigint NOT NULL,
    admin_id bigint NOT NULL,
    token_hash bytea NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    last_seen_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    absolute_expires_at timestamp with time zone NOT NULL,
    revoked_at timestamp with time zone,
    ip_address inet,
    user_agent character varying(512),
    CONSTRAINT ck_admin_sessions_expiry_order CHECK (((created_at < expires_at) AND (expires_at <= absolute_expires_at))),
    CONSTRAINT ck_admin_sessions_last_seen CHECK ((last_seen_at >= created_at)),
    CONSTRAINT ck_admin_sessions_revoked_at CHECK (((revoked_at IS NULL) OR (revoked_at >= created_at))),
    CONSTRAINT ck_admin_sessions_token_hash_length CHECK ((octet_length(token_hash) = 32))
);


--
-- Name: TABLE admin_sessions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.admin_sessions IS 'Sesiones activas e históricas. Revocar = fijar revoked_at.';


--
-- Name: COLUMN admin_sessions.token_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.admin_sessions.token_hash IS 'SHA-256 (32 bytes) del token aleatorio enviado en la cookie.';


--
-- Name: COLUMN admin_sessions.expires_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.admin_sessions.expires_at IS 'Expiración deslizante (inactividad).';


--
-- Name: COLUMN admin_sessions.absolute_expires_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.admin_sessions.absolute_expires_at IS 'Límite máximo de vida de la sesión.';


--
-- Name: admin_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.admin_sessions ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.admin_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: admins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admins (
    id bigint NOT NULL,
    email character varying(254) NOT NULL,
    full_name character varying(120) NOT NULL,
    password_hash character varying(100) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    failed_login_count smallint DEFAULT 0 NOT NULL,
    lockout_until timestamp with time zone,
    last_login_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_admins_email_format CHECK ((((email)::text = lower(btrim((email)::text))) AND ((email)::text ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'::text))),
    CONSTRAINT ck_admins_failed_login_count CHECK ((failed_login_count >= 0)),
    CONSTRAINT ck_admins_full_name_not_blank CHECK ((btrim((full_name)::text) <> ''::text)),
    CONSTRAINT ck_admins_password_hash_bcrypt CHECK (((password_hash)::text ~ '^\$2[aby]\$[0-9]{2}\$[./A-Za-z0-9]{53}$'::text))
);


--
-- Name: TABLE admins; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.admins IS 'Administradores del panel. Se crean desde el script de datos (sin pantalla de gestión).';


--
-- Name: COLUMN admins.password_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.admins.password_hash IS 'Hash bcrypt. La contraseña en texto plano nunca se almacena.';


--
-- Name: COLUMN admins.lockout_until; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.admins.lockout_until IS 'Bloqueo temporal tras demasiados intentos fallidos.';


--
-- Name: admins_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.admins ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.admins_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: blog_post_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.blog_post_tags (
    post_id bigint NOT NULL,
    tag_id smallint NOT NULL
);


--
-- Name: TABLE blog_post_tags; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.blog_post_tags IS 'Etiquetas asignadas a cada entrada (máximo 5 por entrada, regla de la API).';


--
-- Name: blog_posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.blog_posts (
    id bigint NOT NULL,
    slug character varying(190) NOT NULL,
    title_es character varying(180) NOT NULL,
    title_en character varying(180),
    excerpt_es character varying(300) NOT NULL,
    excerpt_en character varying(300),
    content_markdown_es text NOT NULL,
    content_markdown_en text,
    cover_image_path character varying(300),
    status character varying(10) DEFAULT 'draft'::character varying NOT NULL,
    published_at timestamp with time zone,
    reading_minutes smallint DEFAULT 1 NOT NULL,
    author_id bigint,
    created_by bigint,
    updated_by bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_blog_posts_content_length CHECK (((char_length(content_markdown_es) <= 50000) AND ((content_markdown_en IS NULL) OR (char_length(content_markdown_en) <= 50000)))),
    CONSTRAINT ck_blog_posts_cover_path_format CHECK (((cover_image_path IS NULL) OR ((cover_image_path)::text ~ '^/uploads/[A-Za-z0-9_/-]+\.(jpg|jpeg|png|webp)$'::text))),
    CONSTRAINT ck_blog_posts_published_requires_content CHECK ((((status)::text <> 'published'::text) OR ((published_at IS NOT NULL) AND (cover_image_path IS NOT NULL) AND (title_en IS NOT NULL) AND (excerpt_en IS NOT NULL) AND (content_markdown_en IS NOT NULL)))),
    CONSTRAINT ck_blog_posts_reading_minutes CHECK (((reading_minutes >= 1) AND (reading_minutes <= 600))),
    CONSTRAINT ck_blog_posts_slug_format CHECK (((slug)::text ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text)),
    CONSTRAINT ck_blog_posts_status CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'published'::character varying, 'archived'::character varying])::text[]))),
    CONSTRAINT ck_blog_posts_texts_not_blank CHECK (((btrim((title_es)::text) <> ''::text) AND (btrim((excerpt_es)::text) <> ''::text) AND (btrim(content_markdown_es) <> ''::text) AND ((title_en IS NULL) OR (btrim((title_en)::text) <> ''::text)) AND ((excerpt_en IS NULL) OR (btrim((excerpt_en)::text) <> ''::text)) AND ((content_markdown_en IS NULL) OR (btrim(content_markdown_en) <> ''::text))))
);


--
-- Name: TABLE blog_posts; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.blog_posts IS 'Entradas del blog (ES/EN). No se borran: se archivan.';


--
-- Name: COLUMN blog_posts.content_markdown_es; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.blog_posts.content_markdown_es IS 'Fuente en Markdown. El HTML se genera y sanea en la API (HTML crudo deshabilitado).';


--
-- Name: COLUMN blog_posts.published_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.blog_posts.published_at IS 'Fecha de publicación. Si es futura y status = published, la entrada está programada.';


--
-- Name: COLUMN blog_posts.reading_minutes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.blog_posts.reading_minutes IS 'Tiempo estimado de lectura (versión en español), calculado por la API al guardar.';


--
-- Name: blog_posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.blog_posts ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.blog_posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: blog_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.blog_tags (
    id smallint NOT NULL,
    slug character varying(40) NOT NULL,
    name_es character varying(40) NOT NULL,
    name_en character varying(40) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_blog_tags_names_not_blank CHECK (((btrim((name_es)::text) <> ''::text) AND (btrim((name_en)::text) <> ''::text))),
    CONSTRAINT ck_blog_tags_slug_format CHECK (((slug)::text ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text))
);


--
-- Name: TABLE blog_tags; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.blog_tags IS 'Etiquetas del blog. Se crean desde el editor de entradas.';


--
-- Name: blog_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.blog_tags ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.blog_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categories (
    id smallint NOT NULL,
    slug character varying(40) NOT NULL,
    name_es character varying(60) NOT NULL,
    name_en character varying(60) NOT NULL,
    sort_order smallint DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_categories_names_not_blank CHECK (((btrim((name_es)::text) <> ''::text) AND (btrim((name_en)::text) <> ''::text))),
    CONSTRAINT ck_categories_slug_format CHECK (((slug)::text ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text)),
    CONSTRAINT ck_categories_sort_order CHECK ((sort_order >= 0))
);


--
-- Name: TABLE categories; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.categories IS 'Categorías de proyectos. Las inactivas no aparecen en el filtro público.';


--
-- Name: COLUMN categories.slug; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.categories.slug IS 'Identificador público (Category.id en el contrato, ?categoria=<slug>).';


--
-- Name: categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.categories ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: client_leads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_leads (
    id bigint NOT NULL,
    full_name character varying(120) NOT NULL,
    company character varying(120) NOT NULL,
    email character varying(254) NOT NULL,
    phone character varying(20),
    interest character varying(12) NOT NULL,
    message character varying(2000) NOT NULL,
    lang character varying(2) DEFAULT 'es'::character varying NOT NULL,
    privacy_accepted_at timestamp with time zone NOT NULL,
    status character varying(20) DEFAULT 'new'::character varying NOT NULL,
    ip_address inet,
    user_agent character varying(512),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_client_leads_company CHECK ((btrim((company)::text) <> ''::text)),
    CONSTRAINT ck_client_leads_email_format CHECK ((((email)::text = lower(btrim((email)::text))) AND ((email)::text ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'::text))),
    CONSTRAINT ck_client_leads_full_name CHECK ((char_length(btrim((full_name)::text)) >= 2)),
    CONSTRAINT ck_client_leads_interest CHECK (((interest)::text = ANY ((ARRAY['acquire'::character varying, 'coinvest'::character varying, 'incubate'::character varying, 'services'::character varying])::text[]))),
    CONSTRAINT ck_client_leads_lang CHECK (((lang)::text = ANY ((ARRAY['es'::character varying, 'en'::character varying])::text[]))),
    CONSTRAINT ck_client_leads_message CHECK ((btrim((message)::text) <> ''::text)),
    CONSTRAINT ck_client_leads_phone_format CHECK (((phone IS NULL) OR ((phone)::text ~ '^\+?[0-9][0-9 ()-]{6,19}$'::text))),
    CONSTRAINT ck_client_leads_status CHECK (((status)::text = ANY ((ARRAY['new'::character varying, 'reviewed'::character varying, 'contacted'::character varying, 'archived'::character varying])::text[])))
);


--
-- Name: TABLE client_leads; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.client_leads IS 'Formulario de clientes, inversionistas y compradores.';


--
-- Name: COLUMN client_leads.interest; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.client_leads.interest IS 'acquire = adquirir un proyecto · coinvest = coinvertir · incubate = incubar · services = servicios legales/comerciales/fiscales.';


--
-- Name: COLUMN client_leads.lang; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.client_leads.lang IS 'Idioma en que se envió el formulario, para responder en el mismo.';


--
-- Name: COLUMN client_leads.privacy_accepted_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.client_leads.privacy_accepted_at IS 'Momento en que se aceptó el aviso de privacidad (obligatorio).';


--
-- Name: COLUMN client_leads.ip_address; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.client_leads.ip_address IS 'IP de origen, para trazabilidad ante abuso.';


--
-- Name: client_leads_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.client_leads ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.client_leads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: project_images; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_images (
    id bigint NOT NULL,
    project_id bigint NOT NULL,
    image_path character varying(300) NOT NULL,
    caption_es character varying(150) NOT NULL,
    caption_en character varying(150),
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_project_images_captions_not_blank CHECK (((btrim((caption_es)::text) <> ''::text) AND ((caption_en IS NULL) OR (btrim((caption_en)::text) <> ''::text)))),
    CONSTRAINT ck_project_images_path_format CHECK (((image_path)::text ~ '^/uploads/[A-Za-z0-9_/-]+\.(jpg|jpeg|png|webp)$'::text)),
    CONSTRAINT ck_project_images_sort_order CHECK ((sort_order >= 0))
);


--
-- Name: TABLE project_images; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.project_images IS 'Evidencias en imagen del detalle. El pie de foto se usa como alt.';


--
-- Name: project_images_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.project_images ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.project_images_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: project_results; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_results (
    id bigint NOT NULL,
    project_id bigint NOT NULL,
    value character varying(30) NOT NULL,
    label_es character varying(100) NOT NULL,
    label_en character varying(100),
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_project_results_sort_order CHECK ((sort_order >= 0)),
    CONSTRAINT ck_project_results_texts_not_blank CHECK (((btrim((value)::text) <> ''::text) AND (btrim((label_es)::text) <> ''::text) AND ((label_en IS NULL) OR (btrim((label_en)::text) <> ''::text))))
);


--
-- Name: TABLE project_results; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.project_results IS 'Resultados del detalle. value es texto de presentación, no un número.';


--
-- Name: project_results_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.project_results ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.project_results_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: project_support_areas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_support_areas (
    project_id bigint NOT NULL,
    area_code character varying(20) NOT NULL
);


--
-- Name: projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projects (
    id bigint NOT NULL,
    category_id smallint NOT NULL,
    slug character varying(80) NOT NULL,
    name character varying(120) NOT NULL,
    stage character varying(12) NOT NULL,
    year smallint NOT NULL,
    summary_es character varying(120),
    summary_en character varying(120),
    description_es text,
    description_en text,
    cover_image_path character varying(300),
    is_visible boolean DEFAULT false NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_by bigint,
    updated_by bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_projects_cover_path_format CHECK (((cover_image_path IS NULL) OR ((cover_image_path)::text ~ '^/uploads/[A-Za-z0-9_/-]+\.(jpg|jpeg|png|webp)$'::text))),
    CONSTRAINT ck_projects_description_length CHECK ((((description_es IS NULL) OR (char_length(description_es) <= 5000)) AND ((description_en IS NULL) OR (char_length(description_en) <= 5000)))),
    CONSTRAINT ck_projects_name_not_blank CHECK ((btrim((name)::text) <> ''::text)),
    CONSTRAINT ck_projects_slug_format CHECK (((slug)::text ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text)),
    CONSTRAINT ck_projects_sort_order CHECK ((sort_order >= 0)),
    CONSTRAINT ck_projects_stage CHECK (((stage)::text = ANY ((ARRAY['incubacion'::character varying, 'venture'::character varying, 'exit'::character varying])::text[]))),
    CONSTRAINT ck_projects_texts_not_blank CHECK ((((summary_es IS NULL) OR (btrim((summary_es)::text) <> ''::text)) AND ((summary_en IS NULL) OR (btrim((summary_en)::text) <> ''::text)) AND ((description_es IS NULL) OR (btrim(description_es) <> ''::text)) AND ((description_en IS NULL) OR (btrim(description_en) <> ''::text)))),
    CONSTRAINT ck_projects_visible_requires_content CHECK (((NOT is_visible) OR ((cover_image_path IS NOT NULL) AND (summary_es IS NOT NULL) AND (summary_en IS NOT NULL) AND (description_es IS NOT NULL) AND (description_en IS NOT NULL)))),
    CONSTRAINT ck_projects_year CHECK (((year >= 1990) AND (year <= 2100)))
);


--
-- Name: TABLE projects; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.projects IS 'Proyectos del portafolio. No se borran: se ocultan (is_visible = false).';


--
-- Name: COLUMN projects.slug; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.projects.slug IS 'Identificador público en la URL (/proyectos/:slug). Único y editable desde el panel.';


--
-- Name: COLUMN projects.stage; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.projects.stage IS 'incubacion · venture · exit (vendido).';


--
-- Name: COLUMN projects.summary_es; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.projects.summary_es IS 'Descripción breve de la tarjeta (≤ 120 caracteres).';


--
-- Name: COLUMN projects.description_es; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.projects.description_es IS 'Texto plano del detalle (sin HTML).';


--
-- Name: projects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.projects ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.projects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: support_areas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.support_areas (
    code character varying(20) NOT NULL,
    name_es character varying(60) NOT NULL,
    name_en character varying(60) NOT NULL,
    sort_order smallint DEFAULT 0 NOT NULL,
    CONSTRAINT ck_support_areas_code_format CHECK (((code)::text ~ '^[a-z]+$'::text)),
    CONSTRAINT ck_support_areas_names_not_blank CHECK (((btrim((name_es)::text) <> ''::text) AND (btrim((name_en)::text) <> ''::text)))
);


--
-- Name: TABLE support_areas; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.support_areas IS 'Áreas con las que el grupo respalda a cada proyecto (legal, fiscal, comercial, marca).';


--
-- Name: talent_applications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.talent_applications (
    id bigint NOT NULL,
    full_name character varying(120) NOT NULL,
    email character varying(254) NOT NULL,
    area character varying(12) NOT NULL,
    profile_url character varying(300),
    cv_storage_key character varying(80),
    cv_original_name character varying(255),
    cv_size_bytes integer,
    message character varying(2000),
    lang character varying(2) DEFAULT 'es'::character varying NOT NULL,
    privacy_accepted_at timestamp with time zone NOT NULL,
    status character varying(20) DEFAULT 'new'::character varying NOT NULL,
    ip_address inet,
    user_agent character varying(512),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_talent_applications_area CHECK (((area)::text = ANY ((ARRAY['engineering'::character varying, 'brand'::character varying, 'legal'::character varying, 'tax'::character varying, 'commercial'::character varying])::text[]))),
    CONSTRAINT ck_talent_applications_cv_consistency CHECK ((((cv_storage_key IS NULL) AND (cv_original_name IS NULL) AND (cv_size_bytes IS NULL)) OR ((cv_storage_key IS NOT NULL) AND (cv_original_name IS NOT NULL) AND ((cv_size_bytes >= 1) AND (cv_size_bytes <= 5242880))))),
    CONSTRAINT ck_talent_applications_cv_key CHECK (((cv_storage_key IS NULL) OR ((cv_storage_key)::text ~ '^cv/[0-9a-f]{32}\.pdf$'::text))),
    CONSTRAINT ck_talent_applications_email_format CHECK ((((email)::text = lower(btrim((email)::text))) AND ((email)::text ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'::text))),
    CONSTRAINT ck_talent_applications_full_name CHECK ((char_length(btrim((full_name)::text)) >= 2)),
    CONSTRAINT ck_talent_applications_lang CHECK (((lang)::text = ANY ((ARRAY['es'::character varying, 'en'::character varying])::text[]))),
    CONSTRAINT ck_talent_applications_message CHECK (((message IS NULL) OR (btrim((message)::text) <> ''::text))),
    CONSTRAINT ck_talent_applications_profile_url CHECK (((profile_url IS NULL) OR ((profile_url)::text ~* '^https?://[^\s/]+\.[^\s/]+(/\S*)?$'::text))),
    CONSTRAINT ck_talent_applications_status CHECK (((status)::text = ANY ((ARRAY['new'::character varying, 'reviewed'::character varying, 'shortlisted'::character varying, 'archived'::character varying])::text[])))
);


--
-- Name: TABLE talent_applications; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.talent_applications IS 'Postulaciones de personas interesadas en trabajar en Grupo Ricartti.';


--
-- Name: COLUMN talent_applications.area; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.talent_applications.area IS 'engineering · brand · legal · tax · commercial.';


--
-- Name: COLUMN talent_applications.cv_storage_key; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.talent_applications.cv_storage_key IS 'Ruta relativa en el almacenamiento privado (PRIVATE_FILES_PATH). No se sirve en /uploads.';


--
-- Name: COLUMN talent_applications.cv_original_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.talent_applications.cv_original_name IS 'Nombre original, solo para mostrarlo en el panel (saneado).';


--
-- Name: talent_applications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.talent_applications ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.talent_applications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Data for Name: admin_sessions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.admin_sessions (id, admin_id, token_hash, created_at, last_seen_at, expires_at, absolute_expires_at, revoked_at, ip_address, user_agent) FROM stdin;
\.


--
-- Data for Name: admins; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.admins (id, email, full_name, password_hash, is_active, failed_login_count, lockout_until, last_login_at, created_at, updated_at) FROM stdin;
1	admin@gruporicartti.test	Andrea Ricartti	$2a$12$JtagFLsHZ9qb7kOXweXNauix/uXmuK9iU9tDfsAaX7VLuDCRhn6K6	t	0	\N	\N	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
2	operaciones@gruporicartti.test	Mateo Salgado	$2a$12$yN5FW266z9o0afnBFhsqNOvduXi2VJ5hANDt/YymUIzuVGFJm3xCO	t	0	\N	\N	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
3	inactivo@gruporicartti.test	Cuenta Inactiva	$2a$12$HudfQJdkMXt6CMjZ6JkEiuJpfW4AlE4/m9MXtbX8bNpEZpoNmwXGC	f	0	\N	\N	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
\.


--
-- Data for Name: blog_post_tags; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.blog_post_tags (post_id, tag_id) FROM stdin;
6	1
4	1
3	2
4	2
2	3
6	4
1	5
6	5
5	6
4	6
\.


--
-- Data for Name: blog_posts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.blog_posts (id, slug, title_es, title_en, excerpt_es, excerpt_en, content_markdown_es, content_markdown_en, cover_image_path, status, published_at, reading_minutes, author_id, created_by, updated_by, created_at, updated_at) FROM stdin;
1	resultados-del-portafolio-2025	Resultados del portafolio 2025	Portfolio results 2025	Resumen del año: una salida, dos proyectos en venture y dos nuevas incubaciones.	The year in review: one exit, two ventures scaling and two new incubations.	Durante 2025 vendimos **Dosis** e incubamos Nodo Crédito y Cosecha Directa. Esta entrada está archivada y ya no se muestra en el sitio.	In 2025 we sold **Dosis** and incubated Nodo Crédito and Cosecha Directa. This post is archived and no longer shown on the site.	/uploads/seed/blog/resultados-del-portafolio-2025/cover.png	archived	2026-01-20 15:00:00+00	1	1	1	1	2026-01-15 15:00:00+00	2026-10-30 05:15:25.740614+00
2	agrotech-en-el-norte-de-mexico	Agrotech en el norte de México	Agrotech in northern Mexico	Las oportunidades que vemos en riego, cadena de frío y venta directa para productores.	The opportunities we see in irrigation, cold chain and direct sales for growers.	Esta entrada está **programada**: su fecha de publicación es futura, por lo que todavía no aparece en el sitio.	This post is **scheduled**: its publication date is in the future, so it does not appear on the site yet.	/uploads/seed/blog/agrotech-en-el-norte-de-mexico/cover.png	published	2030-01-15 15:00:00+00	1	1	1	1	2026-10-20 15:00:00+00	2026-10-30 05:15:25.740614+00
3	respaldo-legal-y-fiscal-desde-el-dia-uno	Respaldo legal y fiscal desde el día uno	Legal and tax backing from day one	Por qué cada proyecto del grupo nace con su constitución, contratos y contabilidad resueltos.	Why every group venture is born with its incorporation, contracts and accounting already in place.	Muchas empresas jóvenes fracasan por trámites, no por su producto. Por eso, en Grupo Ricartti **el papeleo ya está resuelto** antes de buscar clientes.\n\n## Lo que recibe cada proyecto\n\n- Constitución, contratos y propiedad intelectual\n- Contabilidad, cumplimiento y auditoría\n- Primeros clientes y canales de venta	Many young companies fail because of paperwork, not their product. That is why at Grupo Ricartti **the paperwork is already done** before we look for customers.\n\n## What every venture gets\n\n- Incorporation, contracts and IP\n- Accounting, compliance and audit\n- First customers and sales channels	/uploads/seed/blog/respaldo-legal-y-fiscal-desde-el-dia-uno/cover.png	published	2026-10-05 15:00:00+00	1	1	1	1	2026-10-01 15:00:00+00	2026-10-30 05:15:25.740614+00
4	como-elegimos-que-empresa-construir	Cómo elegimos qué empresa construir	How we decide which company to build	Antes de crear una empresa nos hacemos cuatro preguntas. Así decidimos qué proyectos nacen dentro del grupo.	Before we create a company we ask four questions. This is how we decide which ventures are born inside the group.	En Grupo Ricartti no esperamos a que lleguen las ideas: **creamos nuestras propias empresas**. Antes de empezar, cada oportunidad pasa por cuatro preguntas.\n\n## 1. ¿El problema es real y frecuente?\n\nBuscamos problemas que una persona o empresa enfrenta cada semana, no una vez al año.\n\n## 2. ¿Podemos ganar en nuestra región?\n\nDurango y el norte del país nos dan acceso a sectores como el agro, la salud y los servicios financieros para PyMEs.\n\n## 3. ¿El grupo aporta una ventaja?\n\nCada proyecto recibe desde el primer día:\n\n- Laboratorio de marca\n- Equipo legal\n- Equipo comercial\n- Equipo fiscal\n\n![Sesión de trabajo del comité de proyectos](/uploads/seed/blog/como-elegimos-que-empresa-construir/imagen-1.png)\n\n## 4. ¿Tiene un comprador natural?\n\nConstruimos pensando en la salida. [Kuali Pagos](/proyectos/kuali-pagos) nació con esa lógica.	At Grupo Ricartti we don't wait for ideas to arrive: **we create our own companies**. Before we start, every opportunity goes through four questions.\n\n## 1. Is the problem real and frequent?\n\nWe look for problems a person or company faces every week, not once a year.\n\n## 2. Can we win in our region?\n\nDurango and northern Mexico give us access to sectors such as agriculture, health and financial services for SMBs.\n\n## 3. Does the group bring an edge?\n\nEvery venture gets, from day one:\n\n- Brand laboratory\n- Legal team\n- Commercial team\n- Tax team\n\n![Working session of the ventures committee](/uploads/seed/blog/como-elegimos-que-empresa-construir/imagen-1.png)\n\n## 4. Does it have a natural buyer?\n\nWe build with the exit in mind. [Kuali Pagos](/proyectos/kuali-pagos) was born with that logic.	/uploads/seed/blog/como-elegimos-que-empresa-construir/cover.png	published	2026-08-20 15:00:00+00	3	1	1	1	2026-08-12 15:00:00+00	2026-10-30 05:15:25.740614+00
5	guia-para-presentar-tu-proyecto	Guía para presentar tu proyecto al grupo	\N	Qué información preparar antes de pedir que incubemos tu proyecto.	\N	Borrador en preparación. Falta la versión en inglés.\n\n## Información básica\n\n- Problema que resuelve\n- Primeros clientes o pilotos\n- Equipo fundador	\N	\N	draft	\N	1	2	2	2	2026-10-25 15:00:00+00	2026-10-30 05:15:25.740614+00
6	lo-que-aprendimos-al-vender-dosis	Lo que aprendimos al vender Dosis	What we learned selling Dosis	Dosis fue nuestra primera salida. Compartimos tres lecciones sobre cómo preparar una empresa para su nuevo dueño.	Dosis was our first exit. Three lessons on preparing a company for its new owner.	En 2025 vendimos [Dosis](/proyectos/dosis) a un operador logístico nacional. Estas son tres lecciones del proceso.\n\n1. **Ordenar la información desde el inicio.** Con la contabilidad y los contratos al día, la revisión del comprador tomó semanas, no meses.\n2. **Medir lo que el comprador valora.** Las 140 sucursales y la reducción de merma fueron el centro de la negociación.\n3. **Preparar al equipo.** Una buena transición protege a los clientes y a las personas.\n\n> Vender no es el final del proyecto: es el momento en que puede crecer con un nuevo dueño.	In 2025 we sold [Dosis](/proyectos/dosis) to a national logistics operator. These are three lessons from the process.\n\n1. **Keep the records in order from the start.** With up-to-date accounting and contracts, the buyer's review took weeks, not months.\n2. **Measure what the buyer values.** The 140 branches and the drop in shrink were the core of the negotiation.\n3. **Prepare the team.** A good handover protects customers and people.\n\n> Selling is not the end of a venture: it is when it can grow with a new owner.	/uploads/seed/blog/lo-que-aprendimos-al-vender-dosis/cover.png	published	2026-09-10 15:00:00+00	2	2	2	2	2026-09-01 15:00:00+00	2026-10-30 05:15:25.740614+00
\.


--
-- Data for Name: blog_tags; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.blog_tags (id, slug, name_es, name_en, created_at) FROM stdin;
1	inversion	Inversión	Investment	2026-10-30 05:15:25.740614+00
2	venture-building	Venture building	Venture building	2026-10-30 05:15:25.740614+00
3	agrotech	Agrotech	Agrotech	2026-10-30 05:15:25.740614+00
4	salud-digital	Salud digital	Digital health	2026-10-30 05:15:25.740614+00
5	noticias	Noticias	News	2026-10-30 05:15:25.740614+00
6	guias	Guías	Guides	2026-10-30 05:15:25.740614+00
\.


--
-- Data for Name: categories; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.categories (id, slug, name_es, name_en, sort_order, is_active, created_at, updated_at) FROM stdin;
1	fintech	Fintech	Fintech	1	t	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
2	agrotech	Agrotech	Agrotech	2	t	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
3	healthtech	Salud digital	Digital health	3	t	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
\.


--
-- Data for Name: client_leads; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.client_leads (id, full_name, company, email, phone, interest, message, lang, privacy_accepted_at, status, ip_address, user_agent, created_at, updated_at) FROM stdin;
1	Laura Méndez	Fondo Altiplano	laura.mendez@ejemplo.test	+52 618 123 4567	acquire	Nos interesa conocer las condiciones para adquirir Raíz Analytics.	es	2026-10-01 17:20:00+00	new	192.0.2.10	Mozilla/5.0 (seed)	2026-10-01 17:20:00+00	2026-10-30 05:15:25.740614+00
2	Jorge Ibarra	Ibarra Capital	jorge.ibarra@ejemplo.test	\N	coinvest	Quisiera participar en la próxima ronda de Kuali Pagos.	es	2026-10-12 19:05:00+00	reviewed	192.0.2.11	Mozilla/5.0 (seed)	2026-10-12 19:05:00+00	2026-10-30 05:15:25.740614+00
3	Emily Carter	Northbridge Foods	emily.carter@example.test	+1 512 555 0142	incubate	We have a cold-storage concept for Durango growers and would like the group to incubate it.	en	2026-10-20 14:45:00+00	contacted	192.0.2.12	Mozilla/5.0 (seed)	2026-10-20 14:45:00+00	2026-10-30 05:15:25.740614+00
\.


--
-- Data for Name: project_images; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.project_images (id, project_id, image_path, caption_es, caption_en, sort_order, created_at, updated_at) FROM stdin;
1	1	/uploads/seed/kuali-pagos/evidence-1.webp	Panel de operación	Operations dashboard	1	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
2	1	/uploads/seed/kuali-pagos/evidence-2.webp	Piloto en campo	Field pilot	2	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
3	1	/uploads/seed/kuali-pagos/evidence-3.webp	Reporte trimestral	Quarterly report	3	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
4	2	/uploads/seed/nodo-credito/evidence-1.webp	Panel de operación	Operations dashboard	1	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
5	2	/uploads/seed/nodo-credito/evidence-2.webp	Piloto en campo	Field pilot	2	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
6	2	/uploads/seed/nodo-credito/evidence-3.webp	Reporte trimestral	Quarterly report	3	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
7	3	/uploads/seed/raiz-analytics/evidence-1.webp	Panel de operación	Operations dashboard	1	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
8	3	/uploads/seed/raiz-analytics/evidence-2.webp	Piloto en campo	Field pilot	2	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
9	3	/uploads/seed/raiz-analytics/evidence-3.webp	Reporte trimestral	Quarterly report	3	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
10	4	/uploads/seed/cosecha-directa/evidence-1.webp	Panel de operación	Operations dashboard	1	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
11	4	/uploads/seed/cosecha-directa/evidence-2.webp	Piloto en campo	Field pilot	2	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
12	4	/uploads/seed/cosecha-directa/evidence-3.webp	Reporte trimestral	Quarterly report	3	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
13	5	/uploads/seed/clinica-lince/evidence-1.webp	Panel de operación	Operations dashboard	1	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
14	5	/uploads/seed/clinica-lince/evidence-2.webp	Piloto en campo	Field pilot	2	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
15	5	/uploads/seed/clinica-lince/evidence-3.webp	Reporte trimestral	Quarterly report	3	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
16	6	/uploads/seed/dosis/evidence-1.webp	Panel de operación	Operations dashboard	1	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
17	6	/uploads/seed/dosis/evidence-2.webp	Piloto en campo	Field pilot	2	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
18	6	/uploads/seed/dosis/evidence-3.webp	Reporte trimestral	Quarterly report	3	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
19	7	/uploads/seed/ruta-fria/evidence-1.webp	Panel de operación	Operations dashboard	1	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
20	7	/uploads/seed/ruta-fria/evidence-2.webp	Piloto en campo	Field pilot	2	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
21	7	/uploads/seed/ruta-fria/evidence-3.webp	Reporte trimestral	Quarterly report	3	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
\.


--
-- Data for Name: project_results; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.project_results (id, project_id, value, label_es, label_en, sort_order, created_at, updated_at) FROM stdin;
1	1	$84 M	MXN conciliados al mes	MXN reconciled monthly	3	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
2	1	1,200	PyMEs activas	active SMBs	2	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
3	1	+38%	cobranza puntual	on-time collections	1	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
4	2	6 sem	hasta el primer crédito	to first loan	3	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
5	2	2.1%	morosidad a 90 días	90-day delinquency	2	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
6	2	4,300	solicitudes en piloto	pilot applications	1	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
7	3	+12%	rendimiento por árbol	yield per tree	3	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
8	3	310	hectáreas monitoreadas	hectares monitored	2	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
9	3	−27%	consumo de agua	water use	1	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
10	4	+22%	ingreso al productor	grower income	3	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
11	4	19 h	tiempo medio de entrega	average delivery time	2	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
12	4	48	restaurantes en piloto	pilot restaurants	1	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
13	5	4.8/5	satisfacción	satisfaction	3	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
14	5	37	comunidades atendidas	communities served	2	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
15	5	22 mil	consultas al año	consults per year	1	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
16	6	2025	año de venta	year sold	3	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
17	6	140	sucursales	branches	2	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
18	6	−31%	merma de inventario	inventory shrink	1	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
\.


--
-- Data for Name: project_support_areas; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.project_support_areas (project_id, area_code) FROM stdin;
1	comercial
1	fiscal
1	legal
2	legal
2	marca
3	fiscal
3	comercial
4	comercial
4	marca
5	marca
5	fiscal
5	legal
6	marca
6	comercial
6	fiscal
6	legal
7	marca
\.


--
-- Data for Name: projects; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.projects (id, category_id, slug, name, stage, year, summary_es, summary_en, description_es, description_en, cover_image_path, is_visible, sort_order, created_by, updated_by, created_at, updated_at) FROM stdin;
1	1	kuali-pagos	Kuali Pagos	venture	2023	Cobros B2B para PyMEs del Bajío, conciliados en tiempo real.	B2B collections for SMBs in central Mexico, reconciled in real time.	Kuali conecta facturación CFDI con cuentas bancarias para que las PyMEs cobren a tiempo. Incubada en 2023, hoy opera con capital de riesgo del grupo.	Kuali links CFDI invoicing with bank accounts so SMBs get paid on time. Incubated in 2023, now running on group venture capital.	/uploads/seed/kuali-pagos/cover.webp	t	10	1	1	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
2	1	nodo-credito	Nodo Crédito	incubacion	2025	Score crediticio alternativo para trabajadores independientes.	Alternative credit scoring for independent workers.	Nodo evalúa ingresos de plataformas y pagos de servicios para otorgar microcréditos a personas sin historial bancario.	Nodo scores platform income and utility payments to grant micro-loans to people with no bank history.	/uploads/seed/nodo-credito/cover.webp	t	20	1	1	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
3	2	raiz-analytics	Raíz Analytics	venture	2022	Sensores de humedad y riego predictivo para huertas de nogal.	Moisture sensors and predictive irrigation for pecan orchards.	Raíz instala sensores de bajo costo en huertas de Durango y Chihuahua y recomienda riegos según el pronóstico.	Raíz installs low-cost sensors in Durango and Chihuahua orchards and schedules irrigation from the forecast.	/uploads/seed/raiz-analytics/cover.webp	t	30	1	1	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
4	2	cosecha-directa	Cosecha Directa	incubacion	2025	Del productor al restaurante en menos de 24 horas.	From grower to restaurant in under 24 hours.	Marketplace que agrupa pedidos de restaurantes y los surte directamente con productores locales.	A marketplace that pools restaurant orders and fills them straight from local growers.	/uploads/seed/cosecha-directa/cover.webp	t	40	1	1	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
5	3	clinica-lince	Clínica Lince	venture	2023	Telemedicina para comunidades rurales con enfermería en sitio.	Telemedicine for rural communities with on-site nurses.	Lince combina consultas remotas con enfermeras de la comunidad y receta electrónica surtida por farmacias locales.	Lince pairs remote consults with community nurses and e-prescriptions filled by local pharmacies.	/uploads/seed/clinica-lince/cover.webp	t	50	1	1	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
6	3	dosis	Dosis	exit	2021	Inventario farmacéutico inteligente para cadenas regionales.	Smart pharmacy inventory for regional chains.	Dosis predijo la demanda de 140 sucursales. Vendida en 2025 a un operador logístico nacional.	Dosis forecast demand for 140 branches. Sold in 2025 to a national logistics operator.	/uploads/seed/dosis/cover.webp	t	60	1	1	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
7	2	ruta-fria	Ruta Fría	incubacion	2026	Monitoreo de cadena de frío para exportadores de berries.	Cold-chain monitoring for berry exporters.	Proyecto en etapa temprana; oculto hasta cerrar su primer piloto.	Early-stage project; hidden until its first pilot closes.	/uploads/seed/ruta-fria/cover.webp	f	70	1	1	2026-10-30 05:15:25.740614+00	2026-10-30 05:15:25.740614+00
\.


--
-- Data for Name: support_areas; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.support_areas (code, name_es, name_en, sort_order) FROM stdin;
marca	Laboratorio de marca	Brand laboratory	1
legal	Legal	Legal	2
comercial	Comercial	Commercial	3
fiscal	Fiscal	Tax	4
\.


--
-- Data for Name: talent_applications; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.talent_applications (id, full_name, email, area, profile_url, cv_storage_key, cv_original_name, cv_size_bytes, message, lang, privacy_accepted_at, status, ip_address, user_agent, created_at, updated_at) FROM stdin;
1	Daniel Ortega	daniel.ortega@ejemplo.test	engineering	https://www.linkedin.com/in/daniel-ortega-ejemplo	\N	\N	\N	Desarrollador backend con cuatro años de experiencia en fintech.	es	2026-10-05 16:10:00+00	new	192.0.2.20	Mozilla/5.0 (seed)	2026-10-05 16:10:00+00	2026-10-30 05:15:25.740614+00
2	Valeria Cruz	valeria.cruz@ejemplo.test	brand	\N	\N	\N	\N	\N	es	2026-10-18 21:30:00+00	shortlisted	192.0.2.21	Mozilla/5.0 (seed)	2026-10-18 21:30:00+00	2026-10-30 05:15:25.740614+00
\.


--
-- Name: admin_sessions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.admin_sessions_id_seq', 1, false);


--
-- Name: admins_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.admins_id_seq', 3, true);


--
-- Name: blog_posts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.blog_posts_id_seq', 6, true);


--
-- Name: blog_tags_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.blog_tags_id_seq', 6, true);


--
-- Name: categories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.categories_id_seq', 3, true);


--
-- Name: client_leads_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.client_leads_id_seq', 3, true);


--
-- Name: project_images_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.project_images_id_seq', 21, true);


--
-- Name: project_results_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.project_results_id_seq', 18, true);


--
-- Name: projects_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.projects_id_seq', 7, true);


--
-- Name: talent_applications_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.talent_applications_id_seq', 2, true);


--
-- Name: admin_sessions pk_admin_sessions; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_sessions
    ADD CONSTRAINT pk_admin_sessions PRIMARY KEY (id);


--
-- Name: admins pk_admins; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admins
    ADD CONSTRAINT pk_admins PRIMARY KEY (id);


--
-- Name: blog_post_tags pk_blog_post_tags; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blog_post_tags
    ADD CONSTRAINT pk_blog_post_tags PRIMARY KEY (post_id, tag_id);


--
-- Name: blog_posts pk_blog_posts; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blog_posts
    ADD CONSTRAINT pk_blog_posts PRIMARY KEY (id);


--
-- Name: blog_tags pk_blog_tags; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blog_tags
    ADD CONSTRAINT pk_blog_tags PRIMARY KEY (id);


--
-- Name: categories pk_categories; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT pk_categories PRIMARY KEY (id);


--
-- Name: client_leads pk_client_leads; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_leads
    ADD CONSTRAINT pk_client_leads PRIMARY KEY (id);


--
-- Name: project_images pk_project_images; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_images
    ADD CONSTRAINT pk_project_images PRIMARY KEY (id);


--
-- Name: project_results pk_project_results; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_results
    ADD CONSTRAINT pk_project_results PRIMARY KEY (id);


--
-- Name: project_support_areas pk_project_support_areas; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_support_areas
    ADD CONSTRAINT pk_project_support_areas PRIMARY KEY (project_id, area_code);


--
-- Name: projects pk_projects; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT pk_projects PRIMARY KEY (id);


--
-- Name: support_areas pk_support_areas; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.support_areas
    ADD CONSTRAINT pk_support_areas PRIMARY KEY (code);


--
-- Name: talent_applications pk_talent_applications; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.talent_applications
    ADD CONSTRAINT pk_talent_applications PRIMARY KEY (id);


--
-- Name: admin_sessions uq_admin_sessions_token_hash; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_sessions
    ADD CONSTRAINT uq_admin_sessions_token_hash UNIQUE (token_hash);


--
-- Name: admins uq_admins_email; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admins
    ADD CONSTRAINT uq_admins_email UNIQUE (email);


--
-- Name: blog_posts uq_blog_posts_slug; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blog_posts
    ADD CONSTRAINT uq_blog_posts_slug UNIQUE (slug);


--
-- Name: blog_tags uq_blog_tags_slug; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blog_tags
    ADD CONSTRAINT uq_blog_tags_slug UNIQUE (slug);


--
-- Name: categories uq_categories_slug; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT uq_categories_slug UNIQUE (slug);


--
-- Name: projects uq_projects_slug; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT uq_projects_slug UNIQUE (slug);


--
-- Name: ix_admin_sessions_absolute_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_admin_sessions_absolute_expires_at ON public.admin_sessions USING btree (absolute_expires_at);


--
-- Name: ix_admin_sessions_admin_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_admin_sessions_admin_id ON public.admin_sessions USING btree (admin_id);


--
-- Name: ix_blog_post_tags_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_blog_post_tags_tag_id ON public.blog_post_tags USING btree (tag_id);


--
-- Name: ix_blog_posts_author_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_blog_posts_author_id ON public.blog_posts USING btree (author_id);


--
-- Name: ix_blog_posts_public_listing; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_blog_posts_public_listing ON public.blog_posts USING btree (published_at DESC) WHERE ((status)::text = 'published'::text);


--
-- Name: ix_blog_posts_status_updated; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_blog_posts_status_updated ON public.blog_posts USING btree (status, updated_at DESC);


--
-- Name: ix_client_leads_status_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_client_leads_status_created ON public.client_leads USING btree (status, created_at DESC);


--
-- Name: ix_project_images_project_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_project_images_project_order ON public.project_images USING btree (project_id, sort_order);


--
-- Name: ix_project_results_project_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_project_results_project_order ON public.project_results USING btree (project_id, sort_order);


--
-- Name: ix_project_support_areas_area; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_project_support_areas_area ON public.project_support_areas USING btree (area_code);


--
-- Name: ix_projects_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_projects_category_id ON public.projects USING btree (category_id);


--
-- Name: ix_projects_public_listing; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_projects_public_listing ON public.projects USING btree (sort_order, year DESC) WHERE is_visible;


--
-- Name: ix_talent_applications_status_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_talent_applications_status_created ON public.talent_applications USING btree (status, created_at DESC);


--
-- Name: uq_blog_tags_name_es_ci; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_blog_tags_name_es_ci ON public.blog_tags USING btree (lower((name_es)::text));


--
-- Name: uq_categories_name_en_ci; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_categories_name_en_ci ON public.categories USING btree (lower((name_en)::text));


--
-- Name: uq_categories_name_es_ci; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_categories_name_es_ci ON public.categories USING btree (lower((name_es)::text));


--
-- Name: admins trg_admins_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_admins_updated_at BEFORE UPDATE ON public.admins FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: blog_posts trg_blog_posts_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_blog_posts_updated_at BEFORE UPDATE ON public.blog_posts FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: categories trg_categories_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_categories_updated_at BEFORE UPDATE ON public.categories FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: client_leads trg_client_leads_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_client_leads_updated_at BEFORE UPDATE ON public.client_leads FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: project_images trg_project_images_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_project_images_updated_at BEFORE UPDATE ON public.project_images FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: project_results trg_project_results_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_project_results_updated_at BEFORE UPDATE ON public.project_results FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: projects trg_projects_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_projects_updated_at BEFORE UPDATE ON public.projects FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: talent_applications trg_talent_applications_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_talent_applications_updated_at BEFORE UPDATE ON public.talent_applications FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: admin_sessions fk_admin_sessions_admin; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_sessions
    ADD CONSTRAINT fk_admin_sessions_admin FOREIGN KEY (admin_id) REFERENCES public.admins(id) ON DELETE CASCADE;


--
-- Name: blog_post_tags fk_blog_post_tags_post; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blog_post_tags
    ADD CONSTRAINT fk_blog_post_tags_post FOREIGN KEY (post_id) REFERENCES public.blog_posts(id) ON DELETE CASCADE;


--
-- Name: blog_post_tags fk_blog_post_tags_tag; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blog_post_tags
    ADD CONSTRAINT fk_blog_post_tags_tag FOREIGN KEY (tag_id) REFERENCES public.blog_tags(id) ON DELETE RESTRICT;


--
-- Name: blog_posts fk_blog_posts_author; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blog_posts
    ADD CONSTRAINT fk_blog_posts_author FOREIGN KEY (author_id) REFERENCES public.admins(id) ON DELETE SET NULL;


--
-- Name: blog_posts fk_blog_posts_created_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blog_posts
    ADD CONSTRAINT fk_blog_posts_created_by FOREIGN KEY (created_by) REFERENCES public.admins(id) ON DELETE SET NULL;


--
-- Name: blog_posts fk_blog_posts_updated_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blog_posts
    ADD CONSTRAINT fk_blog_posts_updated_by FOREIGN KEY (updated_by) REFERENCES public.admins(id) ON DELETE SET NULL;


--
-- Name: project_images fk_project_images_project; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_images
    ADD CONSTRAINT fk_project_images_project FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: project_results fk_project_results_project; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_results
    ADD CONSTRAINT fk_project_results_project FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: project_support_areas fk_project_support_areas_area; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_support_areas
    ADD CONSTRAINT fk_project_support_areas_area FOREIGN KEY (area_code) REFERENCES public.support_areas(code) ON DELETE RESTRICT;


--
-- Name: project_support_areas fk_project_support_areas_project; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_support_areas
    ADD CONSTRAINT fk_project_support_areas_project FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: projects fk_projects_category; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT fk_projects_category FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE RESTRICT;


--
-- Name: projects fk_projects_created_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT fk_projects_created_by FOREIGN KEY (created_by) REFERENCES public.admins(id) ON DELETE SET NULL;


--
-- Name: projects fk_projects_updated_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT fk_projects_updated_by FOREIGN KEY (updated_by) REFERENCES public.admins(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

\unrestrict qoMalqLqwL012wfQ9mDfQJgCj4IDKiWtCukG982n2AGqTPPRRZ89ezsJYDfVhIb

