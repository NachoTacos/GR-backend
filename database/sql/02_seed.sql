-- =====================================================================
-- Grupo Ricartti — 02: datos de prueba
-- ---------------------------------------------------------------------
-- TODOS LOS DATOS SON FICTICIOS (contenido de demostración).
-- Portafolio tomado del handoff de frontend (§11, src/api/mocks/seed.json):
-- 3 categorías y 7 proyectos; "ruta-fria" está oculto y nunca debe
-- aparecer en el sitio público. Imágenes en uploads/seed/<slug>/.
--
-- Credenciales de prueba (también en el README):
--   admin@gruporicartti.test        / Ricartti#Admin2026     (activo)
--   operaciones@gruporicartti.test  / Ricartti#Ops2026       (activo)
--   inactivo@gruporicartti.test     / Ricartti#Inactivo2026  (desactivado: el login debe fallar)
-- Solo se guardan los hashes bcrypt (factor 12).
--
--   psql -U postgres -d ricartti -c "SET ROLE ricartti_app" -f database/sql/02_seed.sql
-- =====================================================================
\set ON_ERROR_STOP on
SET client_encoding = 'UTF8';
SET client_min_messages = warning;

BEGIN;

-- ---------------------------------------------------------------------
-- Administradores
-- ---------------------------------------------------------------------
INSERT INTO admins (email, full_name, password_hash, is_active) VALUES
    ('admin@gruporicartti.test',       'Andrea Ricartti',  '$2a$12$JtagFLsHZ9qb7kOXweXNauix/uXmuK9iU9tDfsAaX7VLuDCRhn6K6', true),
    ('operaciones@gruporicartti.test', 'Mateo Salgado',    '$2a$12$yN5FW266z9o0afnBFhsqNOvduXi2VJ5hANDt/YymUIzuVGFJm3xCO', true),
    ('inactivo@gruporicartti.test',    'Cuenta Inactiva',  '$2a$12$HudfQJdkMXt6CMjZ6JkEiuJpfW4AlE4/m9MXtbX8bNpEZpoNmwXGC', false);


-- ---------------------------------------------------------------------
-- Catálogos
-- ---------------------------------------------------------------------
INSERT INTO categories (slug, name_es, name_en, sort_order) VALUES
    ('fintech',    'Fintech',        'Fintech',        1),
    ('agrotech',   'Agrotech',       'Agrotech',       2),
    ('healthtech', 'Salud digital',  'Digital health', 3);

INSERT INTO support_areas (code, name_es, name_en, sort_order) VALUES
    ('marca',     'Laboratorio de marca', 'Brand laboratory', 1),
    ('legal',     'Legal',                'Legal',            2),
    ('comercial', 'Comercial',            'Commercial',       3),
    ('fiscal',    'Fiscal',               'Tax',              4);


-- ---------------------------------------------------------------------
-- Proyectos (6 visibles + Ruta Fría oculto)
-- ---------------------------------------------------------------------
INSERT INTO projects
    (category_id, slug, name, stage, year, summary_es, summary_en,
     description_es, description_en, cover_image_path, is_visible, sort_order,
     created_by, updated_by)
SELECT c.id, v.slug, v.name, v.stage, v.year, v.summary_es, v.summary_en,
       v.description_es, v.description_en, '/uploads/seed/' || v.slug || '/cover.webp',
       v.is_visible, v.sort_order, a.id, a.id
FROM (VALUES
    ('fintech', 'kuali-pagos', 'Kuali Pagos', 'venture', 2023,
     'Cobros B2B para PyMEs del Bajío, conciliados en tiempo real.',
     'B2B collections for SMBs in central Mexico, reconciled in real time.',
     'Kuali conecta facturación CFDI con cuentas bancarias para que las PyMEs cobren a tiempo. Incubada en 2023, hoy opera con capital de riesgo del grupo.',
     'Kuali links CFDI invoicing with bank accounts so SMBs get paid on time. Incubated in 2023, now running on group venture capital.',
     true, 10),

    ('fintech', 'nodo-credito', 'Nodo Crédito', 'incubacion', 2025,
     'Score crediticio alternativo para trabajadores independientes.',
     'Alternative credit scoring for independent workers.',
     'Nodo evalúa ingresos de plataformas y pagos de servicios para otorgar microcréditos a personas sin historial bancario.',
     'Nodo scores platform income and utility payments to grant micro-loans to people with no bank history.',
     true, 20),

    ('agrotech', 'raiz-analytics', 'Raíz Analytics', 'venture', 2022,
     'Sensores de humedad y riego predictivo para huertas de nogal.',
     'Moisture sensors and predictive irrigation for pecan orchards.',
     'Raíz instala sensores de bajo costo en huertas de Durango y Chihuahua y recomienda riegos según el pronóstico.',
     'Raíz installs low-cost sensors in Durango and Chihuahua orchards and schedules irrigation from the forecast.',
     true, 30),

    ('agrotech', 'cosecha-directa', 'Cosecha Directa', 'incubacion', 2025,
     'Del productor al restaurante en menos de 24 horas.',
     'From grower to restaurant in under 24 hours.',
     'Marketplace que agrupa pedidos de restaurantes y los surte directamente con productores locales.',
     'A marketplace that pools restaurant orders and fills them straight from local growers.',
     true, 40),

    ('healthtech', 'clinica-lince', 'Clínica Lince', 'venture', 2023,
     'Telemedicina para comunidades rurales con enfermería en sitio.',
     'Telemedicine for rural communities with on-site nurses.',
     'Lince combina consultas remotas con enfermeras de la comunidad y receta electrónica surtida por farmacias locales.',
     'Lince pairs remote consults with community nurses and e-prescriptions filled by local pharmacies.',
     true, 50),

    ('healthtech', 'dosis', 'Dosis', 'exit', 2021,
     'Inventario farmacéutico inteligente para cadenas regionales.',
     'Smart pharmacy inventory for regional chains.',
     'Dosis predijo la demanda de 140 sucursales. Vendida en 2025 a un operador logístico nacional.',
     'Dosis forecast demand for 140 branches. Sold in 2025 to a national logistics operator.',
     true, 60),

    ('agrotech', 'ruta-fria', 'Ruta Fría', 'incubacion', 2026,
     'Monitoreo de cadena de frío para exportadores de berries.',
     'Cold-chain monitoring for berry exporters.',
     'Proyecto en etapa temprana; oculto hasta cerrar su primer piloto.',
     'Early-stage project; hidden until its first pilot closes.',
     false, 70)
) AS v (category_slug, slug, name, stage, year, summary_es, summary_en,
        description_es, description_en, is_visible, sort_order)
JOIN categories c ON c.slug  = v.category_slug
JOIN admins     a ON a.email = 'admin@gruporicartti.test'
-- Orden explícito: los ids coinciden con los mocks del handoff (kuali-pagos = 1 … ruta-fria = 7).
ORDER BY v.sort_order;


-- ---------------------------------------------------------------------
-- Evidencias en imagen: los 7 proyectos tienen 3 imágenes con los
-- mismos pies de foto (handoff §11).
-- ---------------------------------------------------------------------
INSERT INTO project_images (project_id, image_path, caption_es, caption_en, sort_order)
SELECT p.id, '/uploads/seed/' || p.slug || '/evidence-' || e.n || '.webp',
       e.caption_es, e.caption_en, e.n
FROM projects p
CROSS JOIN (VALUES
    (1, 'Panel de operación', 'Operations dashboard'),
    (2, 'Piloto en campo',    'Field pilot'),
    (3, 'Reporte trimestral', 'Quarterly report')
) AS e (n, caption_es, caption_en);


-- ---------------------------------------------------------------------
-- Resultados (Ruta Fría no tiene: la sección se oculta en el detalle)
-- ---------------------------------------------------------------------
INSERT INTO project_results (project_id, value, label_es, label_en, sort_order)
SELECT p.id, v.value, v.label_es, v.label_en, v.sort_order
FROM (VALUES
    ('kuali-pagos',     '+38%',   'cobranza puntual',          'on-time collections',     1),
    ('kuali-pagos',     '1,200',  'PyMEs activas',             'active SMBs',             2),
    ('kuali-pagos',     '$84 M',  'MXN conciliados al mes',    'MXN reconciled monthly',  3),
    ('nodo-credito',    '4,300',  'solicitudes en piloto',     'pilot applications',      1),
    ('nodo-credito',    '2.1%',   'morosidad a 90 días',       '90-day delinquency',      2),
    ('nodo-credito',    '6 sem',  'hasta el primer crédito',   'to first loan',           3),
    ('raiz-analytics',  '−27%',   'consumo de agua',           'water use',               1),
    ('raiz-analytics',  '310',    'hectáreas monitoreadas',    'hectares monitored',      2),
    ('raiz-analytics',  '+12%',   'rendimiento por árbol',     'yield per tree',          3),
    ('cosecha-directa', '48',     'restaurantes en piloto',    'pilot restaurants',       1),
    ('cosecha-directa', '19 h',   'tiempo medio de entrega',   'average delivery time',   2),
    ('cosecha-directa', '+22%',   'ingreso al productor',      'grower income',           3),
    ('clinica-lince',   '22 mil', 'consultas al año',          'consults per year',       1),
    ('clinica-lince',   '37',     'comunidades atendidas',     'communities served',      2),
    ('clinica-lince',   '4.8/5',  'satisfacción',              'satisfaction',            3),
    ('dosis',           '−31%',   'merma de inventario',       'inventory shrink',        1),
    ('dosis',           '140',    'sucursales',                'branches',                2),
    ('dosis',           '2025',   'año de venta',              'year sold',               3)
) AS v (project_slug, value, label_es, label_en, sort_order)
JOIN projects p ON p.slug = v.project_slug;


-- ---------------------------------------------------------------------
-- Áreas de respaldo de cada proyecto
-- ---------------------------------------------------------------------
INSERT INTO project_support_areas (project_id, area_code)
SELECT p.id, v.area_code
FROM (VALUES
    ('kuali-pagos', 'legal'), ('kuali-pagos', 'fiscal'), ('kuali-pagos', 'comercial'),
    ('nodo-credito', 'marca'), ('nodo-credito', 'legal'),
    ('raiz-analytics', 'comercial'), ('raiz-analytics', 'fiscal'),
    ('cosecha-directa', 'marca'), ('cosecha-directa', 'comercial'),
    ('clinica-lince', 'legal'), ('clinica-lince', 'fiscal'), ('clinica-lince', 'marca'),
    ('dosis', 'legal'), ('dosis', 'fiscal'), ('dosis', 'comercial'), ('dosis', 'marca'),
    ('ruta-fria', 'marca')
) AS v (project_slug, area_code)
JOIN projects p ON p.slug = v.project_slug;


-- ---------------------------------------------------------------------
-- Blog: etiquetas
-- ---------------------------------------------------------------------
INSERT INTO blog_tags (slug, name_es, name_en) VALUES
    ('inversion',        'Inversión',         'Investment'),
    ('venture-building', 'Venture building',  'Venture building'),
    ('agrotech',         'Agrotech',          'Agrotech'),
    ('salud-digital',    'Salud digital',     'Digital health'),
    ('noticias',         'Noticias',          'News'),
    ('guias',            'Guías',             'Guides');


-- ---------------------------------------------------------------------
-- Blog: entradas (ES/EN)
--   · 3 publicadas (visibles en el sitio).
--   · 1 programada (published con fecha futura → todavía no es pública).
--   · 1 borrador SIN versión en inglés (se permite hasta publicar).
--   · 1 archivada.
-- ---------------------------------------------------------------------
INSERT INTO blog_posts
    (slug, title_es, title_en, excerpt_es, excerpt_en,
     content_markdown_es, content_markdown_en, cover_image_path, status,
     published_at, reading_minutes, created_at, author_id, created_by, updated_by)
SELECT v.slug, v.title_es, v.title_en, v.excerpt_es, v.excerpt_en,
       v.content_es, v.content_en, v.cover, v.status,
       v.published_at::timestamptz, v.reading_minutes, v.created_at::timestamptz,
       a.id, a.id, a.id
FROM (VALUES
    ('como-elegimos-que-empresa-construir',
     'Cómo elegimos qué empresa construir',
     'How we decide which company to build',
     'Antes de crear una empresa nos hacemos cuatro preguntas. Así decidimos qué proyectos nacen dentro del grupo.',
     'Before we create a company we ask four questions. This is how we decide which ventures are born inside the group.',
     $md$En Grupo Ricartti no esperamos a que lleguen las ideas: **creamos nuestras propias empresas**. Antes de empezar, cada oportunidad pasa por cuatro preguntas.

## 1. ¿El problema es real y frecuente?

Buscamos problemas que una persona o empresa enfrenta cada semana, no una vez al año.

## 2. ¿Podemos ganar en nuestra región?

Durango y el norte del país nos dan acceso a sectores como el agro, la salud y los servicios financieros para PyMEs.

## 3. ¿El grupo aporta una ventaja?

Cada proyecto recibe desde el primer día:

- Laboratorio de marca
- Equipo legal
- Equipo comercial
- Equipo fiscal

![Sesión de trabajo del comité de proyectos](/uploads/seed/blog/como-elegimos-que-empresa-construir/imagen-1.png)

## 4. ¿Tiene un comprador natural?

Construimos pensando en la salida. [Kuali Pagos](/proyectos/kuali-pagos) nació con esa lógica.$md$,
     $md$At Grupo Ricartti we don't wait for ideas to arrive: **we create our own companies**. Before we start, every opportunity goes through four questions.

## 1. Is the problem real and frequent?

We look for problems a person or company faces every week, not once a year.

## 2. Can we win in our region?

Durango and northern Mexico give us access to sectors such as agriculture, health and financial services for SMBs.

## 3. Does the group bring an edge?

Every venture gets, from day one:

- Brand laboratory
- Legal team
- Commercial team
- Tax team

![Working session of the ventures committee](/uploads/seed/blog/como-elegimos-que-empresa-construir/imagen-1.png)

## 4. Does it have a natural buyer?

We build with the exit in mind. [Kuali Pagos](/proyectos/kuali-pagos) was born with that logic.$md$,
     '/uploads/seed/blog/como-elegimos-que-empresa-construir/cover.png', 'published',
     '2026-08-20 15:00:00+00', 3, '2026-08-12 15:00:00+00', 'admin@gruporicartti.test'),

    ('lo-que-aprendimos-al-vender-dosis',
     'Lo que aprendimos al vender Dosis',
     'What we learned selling Dosis',
     'Dosis fue nuestra primera salida. Compartimos tres lecciones sobre cómo preparar una empresa para su nuevo dueño.',
     'Dosis was our first exit. Three lessons on preparing a company for its new owner.',
     $md$En 2025 vendimos [Dosis](/proyectos/dosis) a un operador logístico nacional. Estas son tres lecciones del proceso.

1. **Ordenar la información desde el inicio.** Con la contabilidad y los contratos al día, la revisión del comprador tomó semanas, no meses.
2. **Medir lo que el comprador valora.** Las 140 sucursales y la reducción de merma fueron el centro de la negociación.
3. **Preparar al equipo.** Una buena transición protege a los clientes y a las personas.

> Vender no es el final del proyecto: es el momento en que puede crecer con un nuevo dueño.$md$,
     $md$In 2025 we sold [Dosis](/proyectos/dosis) to a national logistics operator. These are three lessons from the process.

1. **Keep the records in order from the start.** With up-to-date accounting and contracts, the buyer's review took weeks, not months.
2. **Measure what the buyer values.** The 140 branches and the drop in shrink were the core of the negotiation.
3. **Prepare the team.** A good handover protects customers and people.

> Selling is not the end of a venture: it is when it can grow with a new owner.$md$,
     '/uploads/seed/blog/lo-que-aprendimos-al-vender-dosis/cover.png', 'published',
     '2026-09-10 15:00:00+00', 2, '2026-09-01 15:00:00+00', 'operaciones@gruporicartti.test'),

    ('respaldo-legal-y-fiscal-desde-el-dia-uno',
     'Respaldo legal y fiscal desde el día uno',
     'Legal and tax backing from day one',
     'Por qué cada proyecto del grupo nace con su constitución, contratos y contabilidad resueltos.',
     'Why every group venture is born with its incorporation, contracts and accounting already in place.',
     $md$Muchas empresas jóvenes fracasan por trámites, no por su producto. Por eso, en Grupo Ricartti **el papeleo ya está resuelto** antes de buscar clientes.

## Lo que recibe cada proyecto

- Constitución, contratos y propiedad intelectual
- Contabilidad, cumplimiento y auditoría
- Primeros clientes y canales de venta$md$,
     $md$Many young companies fail because of paperwork, not their product. That is why at Grupo Ricartti **the paperwork is already done** before we look for customers.

## What every venture gets

- Incorporation, contracts and IP
- Accounting, compliance and audit
- First customers and sales channels$md$,
     '/uploads/seed/blog/respaldo-legal-y-fiscal-desde-el-dia-uno/cover.png', 'published',
     '2026-10-05 15:00:00+00', 1, '2026-10-01 15:00:00+00', 'admin@gruporicartti.test'),

    ('agrotech-en-el-norte-de-mexico',
     'Agrotech en el norte de México',
     'Agrotech in northern Mexico',
     'Las oportunidades que vemos en riego, cadena de frío y venta directa para productores.',
     'The opportunities we see in irrigation, cold chain and direct sales for growers.',
     $md$Esta entrada está **programada**: su fecha de publicación es futura, por lo que todavía no aparece en el sitio.$md$,
     $md$This post is **scheduled**: its publication date is in the future, so it does not appear on the site yet.$md$,
     '/uploads/seed/blog/agrotech-en-el-norte-de-mexico/cover.png', 'published',
     '2030-01-15 15:00:00+00', 1, '2026-10-20 15:00:00+00', 'admin@gruporicartti.test'),

    ('guia-para-presentar-tu-proyecto',
     'Guía para presentar tu proyecto al grupo',
     NULL,
     'Qué información preparar antes de pedir que incubemos tu proyecto.',
     NULL,
     $md$Borrador en preparación. Falta la versión en inglés.

## Información básica

- Problema que resuelve
- Primeros clientes o pilotos
- Equipo fundador$md$,
     NULL,
     NULL, 'draft',
     NULL, 1, '2026-10-25 15:00:00+00', 'operaciones@gruporicartti.test'),

    ('resultados-del-portafolio-2025',
     'Resultados del portafolio 2025',
     'Portfolio results 2025',
     'Resumen del año: una salida, dos proyectos en venture y dos nuevas incubaciones.',
     'The year in review: one exit, two ventures scaling and two new incubations.',
     $md$Durante 2025 vendimos **Dosis** e incubamos Nodo Crédito y Cosecha Directa. Esta entrada está archivada y ya no se muestra en el sitio.$md$,
     $md$In 2025 we sold **Dosis** and incubated Nodo Crédito and Cosecha Directa. This post is archived and no longer shown on the site.$md$,
     '/uploads/seed/blog/resultados-del-portafolio-2025/cover.png', 'archived',
     '2026-01-20 15:00:00+00', 1, '2026-01-15 15:00:00+00', 'admin@gruporicartti.test')
) AS v (slug, title_es, title_en, excerpt_es, excerpt_en, content_es, content_en,
        cover, status, published_at, reading_minutes, created_at, author_email)
JOIN admins a ON a.email = v.author_email;


-- ---------------------------------------------------------------------
-- Blog: etiquetas de cada entrada
-- ---------------------------------------------------------------------
INSERT INTO blog_post_tags (post_id, tag_id)
SELECT p.id, t.id
FROM (VALUES
    ('como-elegimos-que-empresa-construir',      'venture-building'),
    ('como-elegimos-que-empresa-construir',      'inversion'),
    ('como-elegimos-que-empresa-construir',      'guias'),
    ('lo-que-aprendimos-al-vender-dosis',        'salud-digital'),
    ('lo-que-aprendimos-al-vender-dosis',        'inversion'),
    ('lo-que-aprendimos-al-vender-dosis',        'noticias'),
    ('respaldo-legal-y-fiscal-desde-el-dia-uno', 'venture-building'),
    ('agrotech-en-el-norte-de-mexico',           'agrotech'),
    ('guia-para-presentar-tu-proyecto',          'guias'),
    ('resultados-del-portafolio-2025',           'noticias')
) AS v (post_slug, tag_slug)
JOIN blog_posts p ON p.slug = v.post_slug
JOIN blog_tags  t ON t.slug = v.tag_slug;


-- ---------------------------------------------------------------------
-- Formularios (ejemplos para la bandeja del panel).
-- IPs del rango de documentación 192.0.2.0/24 (RFC 5737).
-- ---------------------------------------------------------------------
INSERT INTO client_leads
    (full_name, company, email, phone, interest, message, lang,
     privacy_accepted_at, status, ip_address, user_agent, created_at)
VALUES
    ('Laura Méndez', 'Fondo Altiplano', 'laura.mendez@ejemplo.test', '+52 618 123 4567',
     'acquire', 'Nos interesa conocer las condiciones para adquirir Raíz Analytics.', 'es',
     '2026-10-01 17:20:00+00', 'new', '192.0.2.10', 'Mozilla/5.0 (seed)', '2026-10-01 17:20:00+00'),
    ('Jorge Ibarra', 'Ibarra Capital', 'jorge.ibarra@ejemplo.test', NULL,
     'coinvest', 'Quisiera participar en la próxima ronda de Kuali Pagos.', 'es',
     '2026-10-12 19:05:00+00', 'reviewed', '192.0.2.11', 'Mozilla/5.0 (seed)', '2026-10-12 19:05:00+00'),
    ('Emily Carter', 'Northbridge Foods', 'emily.carter@example.test', '+1 512 555 0142',
     'incubate', 'We have a cold-storage concept for Durango growers and would like the group to incubate it.', 'en',
     '2026-10-20 14:45:00+00', 'contacted', '192.0.2.12', 'Mozilla/5.0 (seed)', '2026-10-20 14:45:00+00');

INSERT INTO talent_applications
    (full_name, email, area, profile_url, message, lang,
     privacy_accepted_at, status, ip_address, user_agent, created_at)
VALUES
    ('Daniel Ortega', 'daniel.ortega@ejemplo.test', 'engineering',
     'https://www.linkedin.com/in/daniel-ortega-ejemplo',
     'Desarrollador backend con cuatro años de experiencia en fintech.', 'es',
     '2026-10-05 16:10:00+00', 'new', '192.0.2.20', 'Mozilla/5.0 (seed)', '2026-10-05 16:10:00+00'),
    ('Valeria Cruz', 'valeria.cruz@ejemplo.test', 'brand',
     NULL, NULL, 'es',
     '2026-10-18 21:30:00+00', 'shortlisted', '192.0.2.21', 'Mozilla/5.0 (seed)', '2026-10-18 21:30:00+00');

COMMIT;
