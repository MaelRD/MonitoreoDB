-- ============================================
-- BD ANÁLISIS PRODUCTIVIDAD CORPORATIVA
-- ============================================

CREATE DATABASE IF NOT EXISTS productividad_corporativa;
USE productividad_corporativa;

-- ============================================
-- MAESTROS
-- ============================================

CREATE TABLE departamentos (
  departamento_id INT PRIMARY KEY AUTO_INCREMENT,
  nombre VARCHAR(100) NOT NULL UNIQUE,
  responsable_id INT,
  presupuesto_it DECIMAL(10,2),
  INDEX (nombre)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE empleados (
  empleado_id INT PRIMARY KEY AUTO_INCREMENT,
  nombre VARCHAR(100) NOT NULL,
  email VARCHAR(100) UNIQUE,
  departamento_id INT NOT NULL,
  rol VARCHAR(50),
  fecha_contratacion DATE,
  estado ENUM('Activo', 'Inactivo', 'Licencia') DEFAULT 'Activo',
  FOREIGN KEY (departamento_id) REFERENCES departamentos(departamento_id),
  INDEX (departamento_id, estado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE categorias_app (
  categoria_id INT PRIMARY KEY AUTO_INCREMENT,
  nombre ENUM('Productiva', 'Distracción', 'Neutra', 'Peligrosa'),
  descripcion VARCHAR(255),
  UNIQUE (nombre)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE aplicaciones (
  app_id INT PRIMARY KEY AUTO_INCREMENT,
  dominio VARCHAR(255) UNIQUE NOT NULL,
  nombre_app VARCHAR(100),
  categoria_id INT NOT NULL,
  prioridad_bloqueo TINYINT(1) DEFAULT 0,
  notas VARCHAR(255),
  FOREIGN KEY (categoria_id) REFERENCES categorias_app(categoria_id),
  INDEX (dominio, categoria_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- DATOS OPERACIONALES
-- ============================================

CREATE TABLE accesos_diarios (
  acceso_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  empleado_id INT NOT NULL,
  app_id INT NOT NULL,
  fecha DATE NOT NULL,
  minutos_totales INT DEFAULT 0,
  numero_accesos INT DEFAULT 0,
  primer_acceso TIME,
  ultimo_acceso TIME,
  FOREIGN KEY (empleado_id) REFERENCES empleados(empleado_id),
  FOREIGN KEY (app_id) REFERENCES aplicaciones(app_id),
  UNIQUE KEY (empleado_id, app_id, fecha),
  INDEX (fecha, empleado_id),
  INDEX (app_id, fecha)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE dispositivos (
  dispositivo_id INT PRIMARY KEY AUTO_INCREMENT,
  empleado_id INT NOT NULL,
  mac_address VARCHAR(17) UNIQUE,
  nombre_dispositivo VARCHAR(100),
  tipo ENUM('Laptop', 'Desktop', 'Telefono', 'Tablet'),
  fecha_registro DATE DEFAULT CURDATE(),
  activo BOOLEAN DEFAULT TRUE,
  FOREIGN KEY (empleado_id) REFERENCES empleados(empleado_id),
  INDEX (empleado_id, activo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- ANALYTICS & REPORTES
-- ============================================

CREATE TABLE kpi_mensual (
  kpi_id INT PRIMARY KEY AUTO_INCREMENT,
  departamento_id INT NOT NULL,
  mes DATE,
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
  fecha_calculo DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (departamento_id) REFERENCES departamentos(departamento_id),
  UNIQUE KEY (departamento_id, mes),
  INDEX (mes)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE kpi_empleado_mensual (
  kpi_empleado_id INT PRIMARY KEY AUTO_INCREMENT,
  empleado_id INT NOT NULL,
  mes DATE,
  total_minutos_productivos INT,
  total_minutos_distracciones INT,
  porcentaje_productivo DECIMAL(5,2),
  dias_activos INT,
  promedio_minutos_diarios INT,
  app_favorita VARCHAR(100),
  anomalia_detectada BOOLEAN DEFAULT FALSE,
  tipo_anomalia VARCHAR(100),
  fecha_calculo DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (empleado_id) REFERENCES empleados(empleado_id),
  UNIQUE KEY (empleado_id, mes),
  INDEX (mes, anomalia_detectada)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE alertas (
  alerta_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  empleado_id INT NOT NULL,
  tipo ENUM('Exceso_Distraccion', 'App_Peligrosa', 'Patrón_Inusual', 'Bajo_Productivo'),
  descripcion VARCHAR(255),
  fecha_alerta DATETIME DEFAULT CURRENT_TIMESTAMP,
  resuelta BOOLEAN DEFAULT FALSE,
  nota_resolucion VARCHAR(255),
  FOREIGN KEY (empleado_id) REFERENCES empleados(empleado_id),
  INDEX (empleado_id, resuelta, fecha_alerta),
  INDEX (tipo, fecha_alerta)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- AUDITORÍA
-- ============================================

CREATE TABLE auditoria_cambios (
  auditoria_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  tabla_afectada VARCHAR(100),
  registro_id INT,
  accion ENUM('INSERT', 'UPDATE', 'DELETE'),
  usuario_admin VARCHAR(100),
  fecha_cambio DATETIME DEFAULT CURRENT_TIMESTAMP,
  detalles JSON,
  INDEX (fecha_cambio, tabla_afectada)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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
-- Productivas
('slack.com', 'Slack', 1, 0),
('gmail.com', 'Gmail', 1, 0),
('github.com', 'GitHub', 1, 0),
('jira.atlassian.net', 'Jira', 1, 0),
('docs.google.com', 'Google Docs', 1, 0),
('confluence.atlassian.net', 'Confluence', 1, 0),
('notion.so', 'Notion', 1, 0),
('teams.microsoft.com', 'Microsoft Teams', 1, 0),

-- Distracciones
('youtube.com', 'YouTube', 2, 1),
('tiktok.com', 'TikTok', 2, 1),
('instagram.com', 'Instagram', 2, 1),
('facebook.com', 'Facebook', 2, 1),
('twitter.com', 'Twitter', 2, 1),
('netflix.com', 'Netflix', 2, 1),
('twitch.tv', 'Twitch', 2, 1),
('reddit.com', 'Reddit', 2, 1),

-- Neutrales
('google.com', 'Google Search', 3, 0),
('bing.com', 'Bing', 3, 0),
('news.google.com', 'Google News', 3, 0),

-- Peligrosas
('thepiratebay.org', 'The Pirate Bay', 4, 1),
('1337x.to', '1337x Torrent', 4, 1),
('malwarebytes.com', 'Malware Sites', 4, 1);

INSERT INTO empleados (nombre, email, departamento_id, rol, fecha_contratacion, estado) VALUES
('Carlos García', 'carlos.garcia@empresa.com', 1, 'Senior Engineer', '2022-01-15', 'Activo'),
('María López', 'maria.lopez@empresa.com', 2, 'Sales Manager', '2022-03-20', 'Activo'),
('Juan Pérez', 'juan.perez@empresa.com', 3, 'HR Specialist', '2021-06-10', 'Activo'),
('Ana Martínez', 'ana.martinez@empresa.com', 4, 'Marketing Lead', '2023-01-05', 'Activo'),
('Luis Fernández', 'luis.fernandez@empresa.com', 5, 'Accountant', '2022-09-12', 'Activo');

INSERT INTO dispositivos (empleado_id, mac_address, nombre_dispositivo, tipo, fecha_registro) VALUES
(1, '5E-DF-77-99-D6-5E', 'POCO-X7-Pro', 'Telefono', '2026-05-12'),
(2, '06-43-9E-71-92-EF', 'A56-de-Luis', 'Laptop', '2026-05-12');
