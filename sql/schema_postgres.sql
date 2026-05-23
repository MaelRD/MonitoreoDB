-- ============================================
-- BD ANÁLISIS PRODUCTIVIDAD CORPORATIVA (PostgreSQL)
-- ============================================

CREATE DATABASE productividad_corporativa;
\c productividad_corporativa;

-- ============================================
-- TIPOS ENUM
-- ============================================

CREATE TYPE estado_empleado AS ENUM ('Activo', 'Inactivo', 'Licencia');
CREATE TYPE categoria_enum AS ENUM ('Productiva', 'Distracción', 'Neutra', 'Peligrosa');
CREATE TYPE tipo_dispositivo AS ENUM ('Laptop', 'Desktop', 'Telefono', 'Tablet');
CREATE TYPE tipo_alerta AS ENUM ('Exceso_Distraccion', 'App_Peligrosa', 'Patrón_Inusual', 'Bajo_Productivo');
CREATE TYPE accion_auditoria AS ENUM ('INSERT', 'UPDATE', 'DELETE');

-- ============================================
-- MAESTROS
-- ============================================

CREATE TABLE departamentos (
  departamento_id SERIAL PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL UNIQUE,
  responsable_id INT,
  presupuesto_it DECIMAL(10,2),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_departamentos_nombre ON departamentos(nombre);

CREATE TABLE empleados (
  empleado_id SERIAL PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  email VARCHAR(100) UNIQUE,
  departamento_id INT NOT NULL REFERENCES departamentos(departamento_id),
  rol VARCHAR(50),
  fecha_contratacion DATE,
  estado estado_empleado DEFAULT 'Activo',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_empleados_departamento ON empleados(departamento_id);
CREATE INDEX idx_empleados_estado ON empleados(estado);
CREATE INDEX idx_empleados_email ON empleados(email);

CREATE TABLE categorias_app (
  categoria_id SERIAL PRIMARY KEY,
  nombre categoria_enum UNIQUE,
  descripcion VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE aplicaciones (
  app_id SERIAL PRIMARY KEY,
  dominio VARCHAR(255) UNIQUE NOT NULL,
  nombre_app VARCHAR(100),
  categoria_id INT NOT NULL REFERENCES categorias_app(categoria_id),
  prioridad_bloqueo BOOLEAN DEFAULT FALSE,
  notas VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_aplicaciones_dominio ON aplicaciones(dominio);
CREATE INDEX idx_aplicaciones_categoria ON aplicaciones(categoria_id);

-- ============================================
-- DATOS OPERACIONALES
-- ============================================

CREATE TABLE accesos_diarios (
  acceso_id BIGSERIAL PRIMARY KEY,
  empleado_id INT NOT NULL REFERENCES empleados(empleado_id),
  app_id INT NOT NULL REFERENCES aplicaciones(app_id),
  fecha DATE NOT NULL,
  minutos_totales INT DEFAULT 0,
  numero_accesos INT DEFAULT 0,
  primer_acceso TIME,
  ultimo_acceso TIME,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(empleado_id, app_id, fecha)
);

CREATE INDEX idx_accesos_fecha ON accesos_diarios(fecha);
CREATE INDEX idx_accesos_empleado ON accesos_diarios(empleado_id);
CREATE INDEX idx_accesos_app ON accesos_diarios(app_id);
CREATE INDEX idx_accesos_empleado_fecha ON accesos_diarios(empleado_id, fecha);

CREATE TABLE dispositivos (
  dispositivo_id SERIAL PRIMARY KEY,
  empleado_id INT NOT NULL REFERENCES empleados(empleado_id),
  mac_address VARCHAR(17) UNIQUE,
  nombre_dispositivo VARCHAR(100),
  tipo tipo_dispositivo,
  fecha_registro DATE DEFAULT CURRENT_DATE,
  activo BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_dispositivos_empleado ON dispositivos(empleado_id);
CREATE INDEX idx_dispositivos_mac ON dispositivos(mac_address);

-- ============================================
-- ANALYTICS & REPORTES
-- ============================================

CREATE TABLE kpi_mensual (
  kpi_id SERIAL PRIMARY KEY,
  departamento_id INT NOT NULL REFERENCES departamentos(departamento_id),
  mes DATE NOT NULL,
  total_empleados_activos INT,
  total_minutos_productivos BIGINT,
  total_minutos_distracciones BIGINT,
  total_minutos_neutra BIGINT,
  porcentaje_productivo DECIMAL(5,2),
  porcentaje_distraccion DECIMAL(5,2),
  app_top_1 VARCHAR(100),
  app_top_1_minutos INT,
  app_top_2 VARCHAR(100),
  app_top_2_minutos INT,
  app_top_3 VARCHAR(100),
  app_top_3_minutos INT,
  fecha_calculo TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(departamento_id, mes)
);

CREATE INDEX idx_kpi_mensual_mes ON kpi_mensual(mes);
CREATE INDEX idx_kpi_mensual_departamento ON kpi_mensual(departamento_id);

CREATE TABLE kpi_empleado_mensual (
  kpi_empleado_id SERIAL PRIMARY KEY,
  empleado_id INT NOT NULL REFERENCES empleados(empleado_id),
  mes DATE NOT NULL,
  total_minutos_productivos INT,
  total_minutos_distracciones INT,
  porcentaje_productivo DECIMAL(5,2),
  dias_activos INT,
  promedio_minutos_diarios INT,
  app_favorita VARCHAR(100),
  anomalia_detectada BOOLEAN DEFAULT FALSE,
  tipo_anomalia VARCHAR(100),
  fecha_calculo TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(empleado_id, mes)
);

CREATE INDEX idx_kpi_empleado_mes ON kpi_empleado_mensual(mes);
CREATE INDEX idx_kpi_empleado_anomalia ON kpi_empleado_mensual(anomalia_detectada);

CREATE TABLE alertas (
  alerta_id BIGSERIAL PRIMARY KEY,
  empleado_id INT NOT NULL REFERENCES empleados(empleado_id),
  tipo tipo_alerta,
  descripcion VARCHAR(255),
  fecha_alerta TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  resuelta BOOLEAN DEFAULT FALSE,
  nota_resolucion VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_alertas_empleado ON alertas(empleado_id);
CREATE INDEX idx_alertas_resuelta ON alertas(resuelta);
CREATE INDEX idx_alertas_fecha ON alertas(fecha_alerta);
CREATE INDEX idx_alertas_tipo ON alertas(tipo);

-- ============================================
-- AUDITORÍA
-- ============================================

CREATE TABLE auditoria_cambios (
  auditoria_id BIGSERIAL PRIMARY KEY,
  tabla_afectada VARCHAR(100),
  registro_id INT,
  accion accion_auditoria,
  usuario_admin VARCHAR(100),
  fecha_cambio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  detalles JSONB
);

CREATE INDEX idx_auditoria_fecha ON auditoria_cambios(fecha_cambio);
CREATE INDEX idx_auditoria_tabla ON auditoria_cambios(tabla_afectada);

-- ============================================
-- DATA INICIAL
-- ============================================

INSERT INTO categorias_app (nombre, descripcion) VALUES
('Productiva', 'Herramientas de trabajo y colaboración'),
('Distracción', 'Redes sociales, entretenimiento, streaming'),
('Neutra', 'Búsqueda general, noticias'),
('Peligrosa', 'Malware, torrents, sitios sospechosos');

INSERT INTO departamentos (nombre, responsable_id, presupuesto_it) VALUES
('Ingeniería', NULL, 50000.00),
('Ventas', NULL, 30000.00),
('Recursos Humanos', NULL, 15000.00),
('Marketing', NULL, 25000.00),
('Finanzas', NULL, 20000.00);

INSERT INTO aplicaciones (dominio, nombre_app, categoria_id, prioridad_bloqueo) VALUES
('slack.com', 'Slack', 1, FALSE),
('gmail.com', 'Gmail', 1, FALSE),
('github.com', 'GitHub', 1, FALSE),
('jira.atlassian.net', 'Jira', 1, FALSE),
('docs.google.com', 'Google Docs', 1, FALSE),
('confluence.atlassian.net', 'Confluence', 1, FALSE),
('notion.so', 'Notion', 1, FALSE),
('teams.microsoft.com', 'Microsoft Teams', 1, FALSE),
('youtube.com', 'YouTube', 2, TRUE),
('tiktok.com', 'TikTok', 2, TRUE),
('instagram.com', 'Instagram', 2, TRUE),
('facebook.com', 'Facebook', 2, TRUE),
('twitter.com', 'Twitter', 2, TRUE),
('netflix.com', 'Netflix', 2, TRUE),
('twitch.tv', 'Twitch', 2, TRUE),
('reddit.com', 'Reddit', 2, TRUE),
('google.com', 'Google Search', 3, FALSE),
('bing.com', 'Bing', 3, FALSE),
('news.google.com', 'Google News', 3, FALSE),
('thepiratebay.org', 'The Pirate Bay', 4, TRUE),
('1337x.to', '1337x Torrent', 4, TRUE),
('connectivitycheck.gstatic.com', 'Connectivity Check', 3, FALSE),
('mtalk.google.com', 'Google mtalk', 3, FALSE),
('spot-pa.googleapis.com', 'Spot Analytics', 3, FALSE),
('resolver.msg.global.xiaomi.net', 'Xiaomi Resolver', 3, FALSE),
('sdkconfig.ad.intl.xiaomi.com', 'Xiaomi SDK', 3, FALSE),
('aggr19-normal.tiktokv.com', 'TikTok CDN', 2, TRUE),
('play.googleapis.com', 'Google Play', 1, FALSE),
('chat-e2ee-mini.facebook.com', 'Facebook Chat', 2, TRUE),
('search22-normal-c-alisg.tiktokv.com', 'TikTok Search', 2, TRUE),
('webcast22-normal-c-alisg.tiktokv.com', 'TikTok Webcast', 2, TRUE),
('frontier.tiktokv.com', 'TikTok Frontier', 2, TRUE),
('pubsub.googleapis.com', 'Google Pubsub', 3, FALSE),
('zombie.duolingo.com', 'Duolingo', 1, FALSE),
('android-api-cf.duolingo.com', 'Duolingo API', 1, FALSE),
('webcast-frontier16-normal-alisg.tiktokv.com', 'TikTok Webcast 16', 2, TRUE),
('webcast-frontier22-normal-alisg.tiktokv.com', 'TikTok Webcast 22', 2, TRUE),
('api22-core-c-alisg.tiktokv.com', 'TikTok API Core', 2, TRUE),
('dls.di.atlas.samsung.com', 'Samsung DLS', 3, FALSE),
('safebrowsing.googleapis.com', 'Google Safe Browsing', 3, FALSE),
('c2paregistration.pa.googleapis.com', 'Google C2PA', 3, FALSE),
('android16.prod.ftl.netflix.com', 'Netflix FTL', 2, TRUE),
('android16.appboot.netflix.com', 'Netflix Appboot', 2, TRUE),
('android16.prod.cloud.netflix.com', 'Netflix Cloud', 2, TRUE),
('android16.logs.netflix.com', 'Netflix Logs', 2, TRUE),
('android.prod.cloud.netflix.com', 'Netflix Android', 2, TRUE),
('z-m-gateway.facebook.com', 'Facebook Gateway', 2, TRUE),
('occ-0-2971-3933.1.nflxso.net', 'Netflix OCC', 2, TRUE),
('photosdata-pa.googleapis.com', 'Google Photos Data', 1, FALSE),
('firebaselogging.googleapis.com', 'Firebase Logging', 3, FALSE),
('mon-boot.tiktokv.com', 'TikTok Monitor', 2, TRUE),
('photos.googleapis.com', 'Google Photos', 1, FALSE),
('g.whatsapp.net', 'WhatsApp', 1, FALSE),
('pagead2.googlesyndication.com', 'Google Ads', 3, FALSE),
('graph.facebook.com', 'Facebook Graph', 2, TRUE),
('myphonenumbers-pa.googleapis.com', 'Google Phone Numbers', 1, FALSE),
('www.google.com', 'Google', 3, FALSE),
('0.pool.ntp.org', 'NTP Pool 0', 3, FALSE),
('1.pool.ntp.org', 'NTP Pool 1', 3, FALSE),
('2.pool.ntp.org', 'NTP Pool 2', 3, FALSE),
('3.pool.ntp.org', 'NTP Pool 3', 3, FALSE),
('2.android.pool.ntp.org', 'Android NTP', 3, FALSE),
('www.tizen.org', 'Tizen', 3, FALSE),
('android.googleapis.com', 'Google Android', 1, FALSE),
('playatoms-pa.googleapis.com', 'Play Atoms', 1, FALSE),
('footprints-pa.googleapis.com', 'Footprints', 3, FALSE),
('geller-pa.googleapis.com', 'Geller', 3, FALSE),
('time.google.com', 'Google Time', 3, FALSE),
('www.samsung.com', 'Samsung', 3, FALSE),
('www.googleapis.com', 'Google APIs', 1, FALSE),
('taskassist-pa.googleapis.com', 'Task Assist', 1, FALSE),
('appsgrowthpromo-pa.googleapis.com', 'Apps Growth', 1, FALSE),
('android.clients.google.com', 'Android Clients', 1, FALSE),
('play-fe.googleapis.com', 'Play FE', 1, FALSE),
('inbox.google.com', 'Google Inbox', 1, FALSE),
('www.ecosia.org', 'Ecosia', 3, FALSE),
('time.cloudflare.com', 'Cloudflare Time', 3, FALSE);

INSERT INTO empleados (nombre, email, departamento_id, rol, fecha_contratacion, estado) VALUES
('Carlos García', 'carlos.garcia@empresa.com', 1, 'Senior Engineer', '2022-01-15', 'Activo'),
('María López', 'maria.lopez@empresa.com', 2, 'Sales Manager', '2022-03-20', 'Activo'),
('Juan Pérez', 'juan.perez@empresa.com', 3, 'HR Specialist', '2021-06-10', 'Activo'),
('Ana Martínez', 'ana.martinez@empresa.com', 4, 'Marketing Lead', '2023-01-05', 'Activo'),
('Luis Fernández', 'luis.fernandez@empresa.com', 5, 'Accountant', '2022-09-12', 'Activo');

INSERT INTO dispositivos (empleado_id, mac_address, nombre_dispositivo, tipo, fecha_registro, activo) VALUES
(1, '5E-DF-77-99-D6-5E', 'POCO-X7-Pro', 'Telefono', '2026-05-12', TRUE),
(2, '06-43-9E-71-92-EF', 'A56-de-Luis', 'Laptop', '2026-05-12', TRUE);

-- ============================================
-- GRANT PERMISOS PARA POSTGREST
-- ============================================

CREATE ROLE api_user NOINHERIT;
GRANT USAGE ON SCHEMA public TO api_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO api_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO api_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO api_user;
