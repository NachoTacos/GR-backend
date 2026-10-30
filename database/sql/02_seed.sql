-- =====================================================================
-- Grupo Ricartti — 02: datos de prueba
-- ---------------------------------------------------------------------
-- TODOS LOS DATOS SON FICTICIOS. Los nombres de proyectos, personas,
-- cifras y correos (dominio reservado .test) se inventaron para la
-- demostración. Cualquier parecido con entidades reales es casual.
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
-- Categorías ("Educación" está inactiva y sin proyectos: no debe
-- aparecer en el filtro público).
-- ---------------------------------------------------------------------
INSERT INTO categories (name, slug, description, sort_order, is_active) VALUES
    ('Fintech',          'fintech',         'Servicios financieros digitales para personas y pymes.',      1, true),
    ('Salud digital',    'salud-digital',   'Tecnología que acerca la atención médica a más personas.',    2, true),
    ('Energía limpia',   'energia-limpia',  'Generación renovable y eficiencia energética.',               3, true),
    ('Logística',        'logistica',       'Cadena de suministro, transporte y última milla.',            4, true),
    ('Agrotecnología',   'agrotecnologia',  'Datos y tecnología aplicados al campo.',                      5, true),
    ('Bienes raíces',    'bienes-raices',   'Desarrollos inmobiliarios y soluciones proptech.',            6, true),
    ('Educación',        'educacion',       'Plataformas de aprendizaje y formación profesional.',         7, false);


-- ---------------------------------------------------------------------
-- Proyectos
--   · 9 visibles → con pageSize 6 la galería tiene 2 páginas.
--   · "hidro-pura": borrador (oculto, sin portada, nunca publicado).
--   · "mercado-verde": publicado antes y ahora oculto (pausado).
-- ---------------------------------------------------------------------
INSERT INTO projects
    (category_id, title, slug, summary, description, cover_image_path,
     is_visible, sort_order, published_at, created_at, created_by, updated_by)
SELECT c.id, v.title, v.slug, v.summary, v.description, v.cover,
       v.is_visible, v.sort_order, v.published_at::timestamptz, v.created_at::timestamptz,
       a.id, a.id
FROM (VALUES
    ('fintech', 'Nodo Pagos', 'nodo-pagos',
     'Terminal y pasarela de pagos para pequeños comercios, con liquidación en 24 horas.',
     'Nodo Pagos ofrece a tienditas, fondas y mercados municipales una terminal de bajo costo y una pasarela en línea con liquidación al día siguiente. Grupo Ricartti lideró la ronda semilla y acompañó la expansión a tres estados, además de la integración con proveedores de facturación electrónica.',
     '/uploads/seed/nodo-pagos/portada.png', true, 10, '2025-03-12 16:00:00+00', '2025-02-20 15:00:00+00'),

    ('fintech', 'Crédito Semilla', 'credito-semilla',
     'Microcréditos para productores agrícolas con evaluación de riesgo basada en datos de cosecha.',
     'Crédito Semilla evalúa a pequeños productores con información de rendimiento histórico, clima y precios de mercado en lugar del historial crediticio tradicional. La inversión financió el fondeo de la cartera inicial y el equipo de análisis de riesgo.',
     '/uploads/seed/credito-semilla/portada.png', true, 20, '2025-06-02 16:00:00+00', '2025-05-10 15:00:00+00'),

    ('salud-digital', 'Vitalia Expediente', 'vitalia-expediente',
     'Expediente clínico en la nube para clínicas privadas medianas.',
     'Vitalia digitaliza el expediente clínico, la agenda y la receta electrónica de clínicas de 5 a 50 consultorios. Grupo Ricartti aportó capital y la red de contactos para cerrar convenios con aseguradoras médicas.',
     '/uploads/seed/vitalia-expediente/portada.png', true, 30, '2024-11-20 16:00:00+00', '2024-10-30 15:00:00+00'),

    ('salud-digital', 'Red TeleSalud Norte', 'red-telesalud-norte',
     'Red de telemedicina para comunidades rurales con especialistas a distancia.',
     'La red instala módulos de consulta en centros comunitarios y los conecta con especialistas en cardiología, pediatría y dermatología. El modelo combina financiamiento público y privado, estructurado con apoyo de Grupo Ricartti.',
     '/uploads/seed/red-telesalud-norte/portada.png', true, 40, '2025-09-15 16:00:00+00', '2025-08-25 15:00:00+00'),

    ('energia-limpia', 'Solaria Industrial', 'solaria-industrial',
     'Instalación y financiamiento de techos solares para naves industriales.',
     'Solaria diseña, instala y financia sistemas fotovoltaicos en techos de parques industriales bajo contratos de compra de energía a 10 años. Fue la primera salida exitosa del portafolio, con venta a un fondo de infraestructura.',
     '/uploads/seed/solaria-industrial/portada.png', true, 50, '2024-08-05 16:00:00+00', '2024-07-15 15:00:00+00'),

    ('logistica', 'Ruta Fría', 'ruta-fria',
     'Red de cadena de frío para distribuidores de alimentos perecederos.',
     'Ruta Fría opera centros de consolidación refrigerados y unidades con monitoreo de temperatura en tiempo real. La inversión permitió abrir dos nuevos centros y certificar la operación bajo normas de inocuidad alimentaria.',
     '/uploads/seed/ruta-fria/portada.png', true, 60, '2025-01-28 16:00:00+00', '2025-01-08 15:00:00+00'),

    ('logistica', 'Cargo Ágil', 'cargo-agil',
     'Software de optimización de rutas para flotillas de reparto urbano.',
     'Cargo Ágil calcula rutas óptimas considerando tráfico, ventanas de entrega y capacidad de cada unidad. Grupo Ricartti participó en la serie A y conectó a la empresa con cadenas de autoservicio de la región.',
     '/uploads/seed/cargo-agil/portada.png', true, 70, '2026-02-10 16:00:00+00', '2026-01-20 15:00:00+00'),

    ('agrotecnologia', 'Sensa Campo', 'sensa-campo',
     'Sensores de humedad y clima que reducen el consumo de agua en cultivos.',
     'Sensa Campo instala sensores de suelo y estaciones climáticas que recomiendan cuándo y cuánto regar. Los productores consultan las recomendaciones desde una aplicación móvil que funciona sin conexión.',
     '/uploads/seed/sensa-campo/portada.png', true, 80, '2025-04-18 16:00:00+00', '2025-03-28 15:00:00+00'),

    ('bienes-raices', 'Torre Alameda', 'torre-alameda',
     'Desarrollo de usos mixtos con oficinas, vivienda y comercio en zona centro.',
     'Torre Alameda reúne 18 niveles de oficinas, 120 departamentos y planta baja comercial a una cuadra del transporte público. Grupo Ricartti estructuró el vehículo de coinversión y coordinó a los socios desarrolladores.',
     '/uploads/seed/torre-alameda/portada.png', true, 90, '2024-05-30 16:00:00+00', '2024-05-01 15:00:00+00'),

    ('energia-limpia', 'Hidro Pura', 'hidro-pura',
     'Planta modular de tratamiento de agua para parques industriales.',
     'Proyecto en evaluación: plantas modulares que tratan y reutilizan el agua de proceso de parques industriales. Pendiente de due diligence técnica y financiera.',
     NULL, false, 100, NULL, '2026-09-01 15:00:00+00'),

    ('agrotecnologia', 'Mercado Verde', 'mercado-verde',
     'Marketplace que conecta productores locales con restaurantes.',
     'Mercado Verde conecta a productores de la región con restaurantes que buscan insumos frescos. La publicación está pausada mientras la empresa reestructura su operación logística.',
     '/uploads/seed/mercado-verde/portada.png', false, 110, '2025-07-01 16:00:00+00', '2025-06-10 15:00:00+00')
) AS v (category_slug, title, slug, summary, description, cover,
        is_visible, sort_order, published_at, created_at)
JOIN categories c ON c.slug  = v.category_slug
JOIN admins     a ON a.email = 'admin@gruporicartti.test';


-- ---------------------------------------------------------------------
-- Evidencias (imágenes y resultados)
-- ---------------------------------------------------------------------
INSERT INTO project_evidences
    (project_id, kind, title, description, image_path, alt_text,
     metric_value, metric_label, sort_order)
SELECT p.id, v.kind, v.title, v.description, v.image_path, v.alt_text,
       v.metric_value, v.metric_label, v.sort_order
FROM (VALUES
    -- Nodo Pagos
    ('nodo-pagos', 'result', NULL, 'Comparativo 2024 contra 2025.', NULL, NULL, '+38 %', 'Crecimiento anual del volumen procesado', 1),
    ('nodo-pagos', 'result', NULL, NULL, NULL, NULL, '12,000', 'Comercios activos', 2),
    ('nodo-pagos', 'image', 'Piloto en mercados municipales', 'Primer despliegue en 40 locales.',
        '/uploads/seed/nodo-pagos/evidencia-1.png', 'Comerciante cobrando con la terminal de Nodo Pagos', NULL, NULL, 3),

    -- Crédito Semilla
    ('credito-semilla', 'result', NULL, 'Por debajo del promedio del sector.', NULL, NULL, '3.1 %', 'Cartera vencida a 12 meses', 1),
    ('credito-semilla', 'result', NULL, NULL, NULL, NULL, '4,800', 'Créditos otorgados', 2),

    -- Vitalia Expediente
    ('vitalia-expediente', 'image', 'Panel del médico', NULL,
        '/uploads/seed/vitalia-expediente/evidencia-1.png', 'Pantalla del expediente clínico de Vitalia en una computadora', NULL, NULL, 1),
    ('vitalia-expediente', 'result', NULL, NULL, NULL, NULL, '-45 %', 'Tiempo de registro por consulta', 2),
    ('vitalia-expediente', 'result', NULL, NULL, NULL, NULL, '86', 'Clínicas usando la plataforma', 3),

    -- Red TeleSalud Norte
    ('red-telesalud-norte', 'image', 'Módulo comunitario', 'Centro de consulta remota en operación.',
        '/uploads/seed/red-telesalud-norte/evidencia-1.png', 'Módulo de telemedicina instalado en un centro comunitario', NULL, NULL, 1),
    ('red-telesalud-norte', 'result', NULL, 'Primer año de operación.', NULL, NULL, '21,000', 'Consultas remotas realizadas', 2),

    -- Solaria Industrial
    ('solaria-industrial', 'image', 'Parque industrial', NULL,
        '/uploads/seed/solaria-industrial/evidencia-1.png', 'Paneles solares sobre el techo de una nave industrial', NULL, NULL, 1),
    ('solaria-industrial', 'image', 'Centro de monitoreo', NULL,
        '/uploads/seed/solaria-industrial/evidencia-2.png', 'Tablero de monitoreo de generación solar', NULL, NULL, 2),
    ('solaria-industrial', 'result', 'Salida', 'Venta a un fondo de infraestructura.', NULL, NULL, '4.2x', 'Múltiplo sobre capital invertido', 3),
    ('solaria-industrial', 'result', NULL, NULL, NULL, NULL, '18 MW', 'Capacidad instalada', 4),

    -- Ruta Fría
    ('ruta-fria', 'image', 'Centro de consolidación', NULL,
        '/uploads/seed/ruta-fria/evidencia-1.png', 'Interior de un almacén refrigerado con tarimas de producto', NULL, NULL, 1),
    ('ruta-fria', 'result', NULL, NULL, NULL, NULL, '-30 %', 'Merma de producto en tránsito', 2),

    -- Cargo Ágil
    ('cargo-agil', 'result', NULL, NULL, NULL, NULL, '-22 %', 'Kilómetros recorridos por entrega', 1),
    ('cargo-agil', 'result', NULL, NULL, NULL, NULL, '35', 'Flotillas cliente', 2),

    -- Sensa Campo
    ('sensa-campo', 'image', 'Estación en campo', NULL,
        '/uploads/seed/sensa-campo/evidencia-1.png', 'Sensor de humedad instalado entre surcos de cultivo', NULL, NULL, 1),
    ('sensa-campo', 'result', NULL, 'Promedio de 60 parcelas.', NULL, NULL, '-40 %', 'Consumo de agua de riego', 2),

    -- Torre Alameda
    ('torre-alameda', 'image', 'Fachada', NULL,
        '/uploads/seed/torre-alameda/evidencia-1.png', 'Fachada de la Torre Alameda al atardecer', NULL, NULL, 1),
    ('torre-alameda', 'image', 'Planta baja comercial', NULL,
        '/uploads/seed/torre-alameda/evidencia-2.png', 'Locales comerciales en la planta baja de la torre', NULL, NULL, 2),
    ('torre-alameda', 'result', NULL, NULL, NULL, NULL, '92 %', 'Ocupación al cierre del primer año', 3),

    -- Hidro Pura (borrador)
    ('hidro-pura', 'result', NULL, NULL, NULL, NULL, 'Fase 1', 'Due diligence en curso', 1),

    -- Mercado Verde (pausado)
    ('mercado-verde', 'result', NULL, NULL, NULL, NULL, '1,200', 'Productores registrados', 1)
) AS v (project_slug, kind, title, description, image_path, alt_text,
        metric_value, metric_label, sort_order)
JOIN projects p ON p.slug = v.project_slug;


-- ---------------------------------------------------------------------
-- Blog: etiquetas
-- ---------------------------------------------------------------------
INSERT INTO blog_tags (name, slug) VALUES
    ('Inversión',       'inversion'),
    ('Startups',        'startups'),
    ('Sostenibilidad',  'sostenibilidad'),
    ('Tecnología',      'tecnologia'),
    ('Noticias',        'noticias'),
    ('Guías',           'guias');


-- ---------------------------------------------------------------------
-- Blog: entradas
--   · 3 publicadas (visibles en el sitio).
--   · 1 programada (published con fecha futura → todavía no es pública).
--   · 1 borrador y 1 archivada (solo en el panel).
-- ---------------------------------------------------------------------
INSERT INTO blog_posts
    (title, slug, excerpt, content_markdown, cover_image_path, status,
     published_at, reading_minutes, created_at, author_id, created_by, updated_by)
SELECT v.title, v.slug, v.excerpt, v.content, v.cover, v.status,
       v.published_at::timestamptz, v.reading_minutes, v.created_at::timestamptz,
       a.id, a.id, a.id
FROM (VALUES
    ('Cómo evaluamos una startup antes de invertir', 'como-evaluamos-una-startup',
     'Los cinco criterios que revisamos en cada oportunidad, desde el equipo fundador hasta la economía unitaria.',
     $md$Cada año revisamos cientos de propuestas y solo invertimos en unas cuantas. Estos son los criterios que aplicamos en **todas** las evaluaciones.

## 1. El equipo fundador

Buscamos equipos que conozcan a fondo el problema que resuelven y que hayan demostrado capacidad de ejecución.

## 2. El tamaño del mercado

Preferimos mercados grandes o en crecimiento acelerado, donde una empresa pueda escalar sin depender de un solo cliente.

## 3. La economía unitaria

- Costo de adquisición de clientes
- Valor de vida del cliente
- Margen bruto por unidad vendida

![Sesión de evaluación del comité de inversión](/uploads/seed/blog/como-evaluamos-una-startup/imagen-1.png)

## 4. La tracción

Las cifras de uso y de ingresos pesan más que las proyecciones.

## 5. El encaje con nuestro portafolio

Valoramos las sinergias con empresas en las que ya invertimos, como [Nodo Pagos](/proyectos/nodo-pagos).

Si tu empresa cumple con estos criterios, escríbenos desde el formulario de contacto.$md$,
     '/uploads/seed/blog/como-evaluamos-una-startup/portada.png', 'published',
     '2026-08-20 15:00:00+00', 4, '2026-08-12 15:00:00+00', 'admin@gruporicartti.test'),

    ('Energía limpia: por qué apostamos por la generación distribuida', 'energia-limpia-generacion-distribuida',
     'La generación solar en techos industriales reduce costos y emisiones. Te contamos qué aprendimos con Solaria Industrial.',
     $md$La generación distribuida produce la energía cerca de donde se consume. Para la industria significa **costos predecibles** y menor dependencia de la red.

## Lo que aprendimos

1. Los contratos de compra de energía a largo plazo dan certidumbre a ambas partes.
2. El mantenimiento preventivo es tan importante como la instalación.
3. Los parques industriales permiten escalar rápido con un solo interlocutor.

Nuestra experiencia con [Solaria Industrial](/proyectos/solaria-industrial) confirmó que el modelo es rentable y replicable.$md$,
     '/uploads/seed/blog/energia-limpia-generacion-distribuida/portada.png', 'published',
     '2026-09-10 15:00:00+00', 3, '2026-09-01 15:00:00+00', 'operaciones@gruporicartti.test'),

    ('Grupo Ricartti cierra su primer fondo de coinversión', 'primer-fondo-de-coinversion',
     'El nuevo vehículo permitirá a inversionistas ángel participar junto a Grupo Ricartti en rondas semilla y serie A.',
     $md$Grupo Ricartti anunció el cierre de su primer fondo de coinversión, abierto a inversionistas ángel de la región.

El fondo participará en rondas **semilla** y **serie A** de empresas de fintech, salud digital, energía limpia y logística.

> Queremos que más personas inviertan en las empresas que están transformando la región.

Las personas interesadas pueden escribirnos eligiendo la opción *coinversión* en el formulario de contacto.$md$,
     '/uploads/seed/blog/primer-fondo-de-coinversion/portada.png', 'published',
     '2026-10-05 15:00:00+00', 2, '2026-10-01 15:00:00+00', 'admin@gruporicartti.test'),

    ('Tendencias fintech para la próxima década', 'tendencias-fintech-proxima-decada',
     'Pagos instantáneos, crédito con datos alternativos y finanzas integradas: las tendencias que seguiremos de cerca.',
     $md$Esta entrada está **programada**: tiene estado *publicada* pero su fecha de publicación es futura, por lo que todavía no aparece en el sitio.

## Tendencias

- Pagos instantáneos entre cuentas
- Crédito basado en datos alternativos
- Finanzas integradas en plataformas no financieras$md$,
     '/uploads/seed/blog/tendencias-fintech-proxima-decada/portada.png', 'published',
     '2030-01-15 15:00:00+00', 2, '2026-10-20 15:00:00+00', 'admin@gruporicartti.test'),

    ('Guía para preparar tu primera ronda de inversión', 'guia-primera-ronda-de-inversion',
     'Documentos, métricas y errores comunes antes de presentar tu startup a un fondo.',
     $md$Borrador en preparación.

## Documentos básicos

- Presentación para inversionistas
- Modelo financiero a tres años
- Tabla de capitalización$md$,
     NULL, 'draft',
     NULL, 1, '2026-10-25 15:00:00+00', 'operaciones@gruporicartti.test'),

    ('Resultados del portafolio 2024', 'resultados-portafolio-2024',
     'Resumen del desempeño del portafolio durante 2024.',
     $md$Durante 2024 el portafolio creció en ingresos y logramos la primera salida con **Solaria Industrial**.

Esta entrada está archivada y ya no se muestra en el sitio.$md$,
     '/uploads/seed/blog/resultados-portafolio-2024/portada.png', 'archived',
     '2025-01-20 15:00:00+00', 1, '2025-01-15 15:00:00+00', 'admin@gruporicartti.test')
) AS v (title, slug, excerpt, content, cover, status,
        published_at, reading_minutes, created_at, author_email)
JOIN admins a ON a.email = v.author_email;


-- ---------------------------------------------------------------------
-- Blog: etiquetas de cada entrada
-- ---------------------------------------------------------------------
INSERT INTO blog_post_tags (post_id, tag_id)
SELECT p.id, t.id
FROM (VALUES
    ('como-evaluamos-una-startup',            'inversion'),
    ('como-evaluamos-una-startup',            'startups'),
    ('como-evaluamos-una-startup',            'guias'),
    ('energia-limpia-generacion-distribuida', 'sostenibilidad'),
    ('energia-limpia-generacion-distribuida', 'inversion'),
    ('primer-fondo-de-coinversion',           'noticias'),
    ('tendencias-fintech-proxima-decada',     'tecnologia'),
    ('tendencias-fintech-proxima-decada',     'startups'),
    ('guia-primera-ronda-de-inversion',       'guias'),
    ('guia-primera-ronda-de-inversion',       'startups'),
    ('resultados-portafolio-2024',            'noticias')
) AS v (post_slug, tag_slug)
JOIN blog_posts p ON p.slug = v.post_slug
JOIN blog_tags  t ON t.slug = v.tag_slug;


-- ---------------------------------------------------------------------
-- Formularios (ejemplos para la bandeja del panel).
-- IPs del rango de documentación 192.0.2.0/24 (RFC 5737).
-- ---------------------------------------------------------------------
INSERT INTO client_inquiries
    (full_name, email, phone, company, inquiry_type, message,
     privacy_accepted_at, status, ip_address, user_agent, created_at)
VALUES
    ('Laura Méndez', 'laura.mendez@ejemplo.test', '+52 55 1234 5678', 'Agua Clara Tech',
     'funding', 'Buscamos una ronda semilla para escalar nuestra solución de medición inteligente de agua.',
     '2026-10-01 17:20:00+00', 'new', '192.0.2.10', 'Mozilla/5.0 (seed)', '2026-10-01 17:20:00+00'),
    ('Jorge Ibarra', 'jorge.ibarra@ejemplo.test', NULL, 'Grupo Logístico del Bajío',
     'partnership', 'Nos interesa una alianza para integrar a Ruta Fría en nuestra red de distribución.',
     '2026-10-12 19:05:00+00', 'reviewed', '192.0.2.11', 'Mozilla/5.0 (seed)', '2026-10-12 19:05:00+00'),
    ('Sofía Treviño', 'sofia.trevino@ejemplo.test', '+52 81 8765 4321', NULL,
     'co_investment', 'Soy inversionista ángel y me gustaría conocer las próximas oportunidades de coinversión.',
     '2026-10-20 14:45:00+00', 'contacted', '192.0.2.12', 'Mozilla/5.0 (seed)', '2026-10-20 14:45:00+00');

INSERT INTO job_applications
    (full_name, email, phone, area_of_interest, linkedin_url, portfolio_url, message,
     privacy_accepted_at, status, ip_address, user_agent, created_at)
VALUES
    ('Daniel Ortega', 'daniel.ortega@ejemplo.test', '+52 33 2222 3333', 'investment_analysis',
     'https://www.linkedin.com/in/daniel-ortega-ejemplo', NULL,
     'Tengo cuatro años de experiencia en análisis de inversiones y me interesa el sector de energía limpia.',
     '2026-10-05 16:10:00+00', 'new', '192.0.2.20', 'Mozilla/5.0 (seed)', '2026-10-05 16:10:00+00'),
    ('Valeria Cruz', 'valeria.cruz@ejemplo.test', NULL, 'technology',
     NULL, 'https://portafolio-valeria.ejemplo.test',
     'Desarrolladora fullstack con interés en apoyar la evaluación técnica de startups del portafolio.',
     '2026-10-18 21:30:00+00', 'shortlisted', '192.0.2.21', 'Mozilla/5.0 (seed)', '2026-10-18 21:30:00+00');

COMMIT;
