-- =====================================================================
--  NAILART - Base de datos (MySQL 8 / MariaDB 10.2+)
--  Contenido: DDL, datos de prueba (DML), consultas con JOIN y
--  subconsultas, reportes, sesiones y modificaciones.
-- =====================================================================

SET NAMES utf8mb4;
CREATE DATABASE IF NOT EXISTS nailart CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE nailart;


-- =====================================================================
--  DDL: CREACIÓN DE TABLAS
-- =====================================================================

-- USUARIOS: clientes y administradores. La contraseña se guarda como hash scrypt, nunca en texto plano.
-- El correo es único sin distinguir mayúsculas (collation _ci).
CREATE TABLE IF NOT EXISTS users (
  id            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  name          VARCHAR(80)  NOT NULL,
  email         VARCHAR(120) NOT NULL,
  phone         VARCHAR(20)  NOT NULL,
  role          ENUM('cliente','administrador') NOT NULL DEFAULT 'cliente',
  password_hash VARCHAR(255) NOT NULL,
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY ux_users_email (email),
  KEY ix_users_role (role)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- SESIONES: inicio de sesión. Se guarda el hash del token (no el token). expires_at en milisegundos (hora UNIX).
CREATE TABLE IF NOT EXISTS sessions (
  token_hash CHAR(64)        NOT NULL,
  user_id    INT UNSIGNED    NOT NULL,
  expires_at BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (token_hash),
  KEY ix_sessions_user (user_id),
  KEY ix_sessions_exp (expires_at),
  CONSTRAINT fk_sessions_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- SERVICIOS: catálogo (precio en pesos COP, duración en minutos).
CREATE TABLE IF NOT EXISTS services (
  id          VARCHAR(20)       NOT NULL,
  name        VARCHAR(80)       NOT NULL,
  description VARCHAR(255)      NOT NULL,
  price       INT UNSIGNED      NOT NULL,
  duration    SMALLINT UNSIGNED NOT NULL,
  icon        VARCHAR(8)        NOT NULL,
  `position`  TINYINT UNSIGNED  NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  CONSTRAINT ck_services_price    CHECK (price > 0),
  CONSTRAINT ck_services_duration CHECK (duration > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- CITAS. active_slot es una columna generada: vale "fecha hora" mientras la cita NO esté cancelada
-- y NULL cuando se cancela. Como tiene índice UNIQUE, MySQL impide dos citas activas en el mismo horario
-- (los NULL no chocan entre sí), incluso si dos personas reservan al mismo tiempo.
--
-- NOTAS DE DISEÑO:
--  * name, phone, email y service_name se guardan a propósito como COPIA HISTÓRICA de la cita:
--    si luego el cliente cambia su teléfono o el servicio cambia de nombre, la cita conserva
--    los datos tal como se agendó. Los datos "vivos" están en users y services (user_id, service_id).
--  * La restricción única solo evita el MISMO inicio exacto. No detecta traslapes por duración
--    (ej.: una cita de 120 min a las 10:00 no bloquea otra a las 11:00). Esa validación se hace en
--    la aplicación; en la sección de consultas hay una consulta de ejemplo para detectar traslapes.
CREATE TABLE IF NOT EXISTS appointments (
  id           CHAR(36)     NOT NULL,
  user_id      INT UNSIGNED NOT NULL,
  name         VARCHAR(80)  NOT NULL,
  phone        VARCHAR(20)  NOT NULL,
  email        VARCHAR(120) NOT NULL DEFAULT '',
  service_id   VARCHAR(20)  NOT NULL,
  service_name VARCHAR(80)  NOT NULL,
  `date`       DATE         NOT NULL,
  `time`       TIME         NOT NULL,
  notes        VARCHAR(500) NOT NULL DEFAULT '',
  status       ENUM('Pendiente','Confirmada','Cancelada') NOT NULL DEFAULT 'Pendiente',
  created_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  active_slot  VARCHAR(20) GENERATED ALWAYS AS (IF(status <> 'Cancelada', CONCAT(`date`, ' ', `time`), NULL)) STORED,
  PRIMARY KEY (id),
  UNIQUE KEY ux_appt_slot (active_slot),
  KEY ix_appt_user (user_id),
  KEY ix_appt_date (`date`, `time`),
  CONSTRAINT fk_appt_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_appt_service FOREIGN KEY (service_id) REFERENCES services(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- =====================================================================
--  SERVICIOS iniciales (catálogo)
-- =====================================================================
INSERT INTO services (id, name, description, price, duration, icon, `position`) VALUES
  ('s1', 'Manicure tradicional', 'Limpieza, limado, cuidado de cutícula y esmaltado clásico.',        25000,  45, '✿', 0),
  ('s2', 'Semipermanente',       'Esmaltado de larga duración con acabado brillante.',               45000,  60, '♡', 1),
  ('s3', 'Uñas acrílicas',       'Extensión y construcción de uñas con acabado personalizado.',      85000, 120, '✧', 2),
  ('s4', 'Pedicure',             'Cuidado de pies, uñas y esmaltado tradicional.',                   35000,  60, '❀', 3),
  ('s5', 'Diseño de uñas',       'Decoración personalizada para darle un toque único a tus uñas.',   15000,  30, '✦', 4),
  ('s6', 'Retiro de producto',   'Retiro cuidadoso del producto aplicado anteriormente.',            18000,  30, '❋', 5)
ON DUPLICATE KEY UPDATE id = id;   -- si ya existe, no hace nada (permite ejecutar el script varias veces)


-- =====================================================================
--  DATOS DE PRUEBA (solo para desarrollo, NO los uses en producción)
--
--  Contraseñas de prueba:
--    Administrador:  maria@example.com                 contraseña  Admin2026x
--    Clientes:       laura@ / camila@ / andrea@ /
--                    valentina@ / sofia@ example.com   contraseña  Cliente123
-- =====================================================================

INSERT INTO users (id, name, email, phone, role, password_hash) VALUES
  (1, 'María Salamanca', 'maria@example.com', '3109998877', 'administrador',
   'scrypt$KubNJnmZvxaK00UrFRtozQ==$X6IU/ZFt3z03g1P/Xa8tdescYuatgPGBI04yFktPmgX2zWS1fGVi+tfnkV7s9CVgR/EnWvJMsqWNjtquafPbOA=='),
  (2, 'Laura Gómez', 'laura@example.com', '3001234567', 'cliente',
   'scrypt$oUogU9adhIookOyAb7afbA==$kQkH6xW9EZXgEzkeFw/DlyGuP1LSpg9/DEJPTsmyBRxvJ+p9P2M7wkHfMwU224+TRyVd5zjtfwRHYNK8tbJ8QA=='),
  (3, 'Camila Rojas', 'camila@example.com', '3012223344', 'cliente',
   'scrypt$tIPyx6YPNfqdcrhuBLdZ6g==$8uuj68SXygBaTa2qZ19Wy4GytVeoN8OokutZOc8us/ZqIwS3szfjr+cyDjL82slLHlNHATrEJaWxQv549cT8iA=='),
  (4, 'Andrea Pérez', 'andrea@example.com', '3023334455', 'cliente',
   'scrypt$jrwbohMfLeGzD+c14+vWgQ==$BIG99lteeYmxmCbEC/ncuSg/WjEfNeqC00zLU+TlqJYaGYoPbmUGlDEQQUi1tqOenk2/e+a9Egk1GIghB8bEow=='),
  (5, 'Valentina Díaz', 'valentina@example.com', '3034445566', 'cliente',
   'scrypt$zFCqUfqDv7vY5cYb/t5oYg==$BOP+I+y96Mm3j6Qa9SQ5oxbY/+1HhSET2K0/Y/4LbB5YglR9APmcf5RyB15k+WZ9/1put56UqEs/uc5QxhX9kQ=='),
  (6, 'Sofía Torres', 'sofia@example.com', '3045556677', 'cliente',
   'scrypt$mMXHweRVhhT+mDyuVoCqWQ==$0rs3eggRz6lrLsZZkp9FJ2jY9GMwNWi8mv2ias8K49tfYFaxXwVKuz0+YitrHgUifXy5sqJZBFyJArgRSiRhPA==')
ON DUPLICATE KEY UPDATE id = id;

INSERT INTO appointments (id, user_id, name, phone, email, service_id, service_name, `date`, `time`, notes, status) VALUES
  ('a0000000-0000-4000-8000-000000000001', 2, 'Laura Gómez', '3001234567', 'laura@example.com', 's2', 'Semipermanente', DATE_SUB(CURDATE(), INTERVAL 7 DAY), '10:00:00', 'Color rosa pastel', 'Confirmada'),
  ('a0000000-0000-4000-8000-000000000002', 3, 'Camila Rojas', '3012223344', 'camila@example.com', 's1', 'Manicure tradicional', DATE_SUB(CURDATE(), INTERVAL 3 DAY), '14:30:00', '', 'Confirmada'),
  ('a0000000-0000-4000-8000-000000000003', 4, 'Andrea Pérez', '3023334455', 'andrea@example.com', 's4', 'Pedicure', DATE_SUB(CURDATE(), INTERVAL 1 DAY), '09:00:00', 'Cancelada por la clienta', 'Cancelada'),
  ('a0000000-0000-4000-8000-000000000004', 2, 'Laura Gómez', '3001234567', 'laura@example.com', 's3', 'Uñas acrílicas', DATE_ADD(CURDATE(), INTERVAL 1 DAY), '10:00:00', 'Diseño con flores', 'Confirmada'),
  ('a0000000-0000-4000-8000-000000000005', 5, 'Valentina Díaz', '3034445566', 'valentina@example.com', 's5', 'Diseño de uñas', DATE_ADD(CURDATE(), INTERVAL 1 DAY), '15:00:00', 'Quiero algo minimalista', 'Pendiente'),
  ('a0000000-0000-4000-8000-000000000006', 3, 'Camila Rojas', '3012223344', 'camila@example.com', 's2', 'Semipermanente', DATE_ADD(CURDATE(), INTERVAL 2 DAY), '11:30:00', '', 'Pendiente'),
  ('a0000000-0000-4000-8000-000000000007', 6, 'Sofía Torres', '3045556677', 'sofia@example.com', 's1', 'Manicure tradicional', DATE_ADD(CURDATE(), INTERVAL 3 DAY), '09:30:00', '', 'Confirmada'),
  ('a0000000-0000-4000-8000-000000000008', 4, 'Andrea Pérez', '3023334455', 'andrea@example.com', 's4', 'Pedicure', DATE_ADD(CURDATE(), INTERVAL 3 DAY), '16:00:00', 'Esmaltado rojo', 'Pendiente'),
  ('a0000000-0000-4000-8000-000000000009', 5, 'Valentina Díaz', '3034445566', 'valentina@example.com', 's3', 'Uñas acrílicas', DATE_ADD(CURDATE(), INTERVAL 5 DAY), '10:00:00', 'Uñas almendra largas', 'Pendiente'),
  ('a0000000-0000-4000-8000-000000000010', 2, 'Laura Gómez', '3001234567', 'laura@example.com', 's6', 'Retiro de producto', DATE_ADD(CURDATE(), INTERVAL 6 DAY), '13:00:00', '', 'Pendiente'),
  ('a0000000-0000-4000-8000-000000000011', 6, 'Sofía Torres', '3045556677', 'sofia@example.com', 's2', 'Semipermanente', DATE_ADD(CURDATE(), INTERVAL 8 DAY), '09:00:00', 'Cambió de planes', 'Cancelada'),
  ('a0000000-0000-4000-8000-000000000012', 3, 'Camila Rojas', '3012223344', 'camila@example.com', 's2', 'Semipermanente', DATE_ADD(CURDATE(), INTERVAL 8 DAY), '09:00:00', 'Reutiliza el horario de una cita cancelada', 'Pendiente')
ON DUPLICATE KEY UPDATE id = id;

-- Sesiones de prueba (se guarda el HASH del token, no el token).
-- Token de ejemplo para Laura: 'token-de-prueba-laura' | para María: 'token-de-prueba-maria'
-- Vencen en 24 horas (expires_at en milisegundos).
INSERT INTO sessions (token_hash, user_id, expires_at) VALUES
  (SHA2('token-de-prueba-laura', 256), 2, (UNIX_TIMESTAMP() + 86400) * 1000),
  (SHA2('token-de-prueba-maria', 256), 1, (UNIX_TIMESTAMP() + 86400) * 1000)
ON DUPLICATE KEY UPDATE token_hash = token_hash;


-- =====================================================================
--  CONSULTAS
-- =====================================================================

-- 1. Usuarios
-- Todos los usuarios (sin mostrar el hash de la contraseña)
SELECT id, name, email, phone, role, created_at FROM users;

-- Solo clientes / solo administradores
SELECT * FROM users WHERE role = 'cliente';
SELECT * FROM users WHERE role = 'administrador';

-- Buscar por correo (no distingue mayúsculas)
SELECT id, name, phone FROM users WHERE email = 'laura@example.com';

-- Buscar por nombre parcial
SELECT id, name, email FROM users WHERE name LIKE '%Gómez%';

-- Cuántos usuarios hay por rol
SELECT role, COUNT(*) AS total FROM users GROUP BY role;

-- Clientes registrados en los últimos 30 días
SELECT name, email, created_at FROM users
WHERE created_at >= NOW() - INTERVAL 30 DAY;


-- 2. Servicios
SELECT * FROM services ORDER BY `position`;
SELECT name, price FROM services ORDER BY price DESC;              -- del más caro al más barato
SELECT name, duration FROM services WHERE duration <= 45;           -- servicios rápidos
SELECT name, price FROM services WHERE price BETWEEN 20000 AND 50000;
SELECT AVG(price) AS precio_promedio, MIN(price), MAX(price) FROM services;


-- 3. Citas
-- Todas las citas, ordenadas por fecha y hora
SELECT * FROM appointments ORDER BY `date`, `time`;

-- Por estado
SELECT * FROM appointments WHERE status = 'Pendiente';
SELECT * FROM appointments WHERE status = 'Confirmada';
SELECT * FROM appointments WHERE status = 'Cancelada';

-- Citas de hoy
SELECT name, service_name, `time`, status FROM appointments
WHERE `date` = CURDATE() AND status <> 'Cancelada' ORDER BY `time`;

-- Citas de la semana
SELECT * FROM appointments
WHERE `date` BETWEEN CURDATE() AND CURDATE() + INTERVAL 7 DAY
  AND status <> 'Cancelada' ORDER BY `date`, `time`;

-- Próximas citas por confirmar
SELECT name, phone, service_name, `date`, `time` FROM appointments
WHERE status = 'Pendiente' AND `date` >= CURDATE() ORDER BY `date`, `time`;

-- Citas pasadas
SELECT * FROM appointments WHERE `date` < CURDATE();

-- Citas de un cliente (equivale a "Mis citas")
SELECT service_name, `date`, `time`, status FROM appointments
WHERE user_id = 2 ORDER BY `date` DESC;

-- ¿Está libre un horario?
SELECT COUNT(*) AS ocupado FROM appointments
WHERE `date` = '2026-11-20' AND `time` = '10:00:00' AND status <> 'Cancelada';
-- 0 = libre, 1 = ocupado

-- ¿Un horario nuevo se traslapa con otra cita por duración?
-- (ejemplo: cita nueva el 2026-11-20 a las 10:30 que dura 60 min)
-- Devuelve las citas activas de ese día que chocan; si no devuelve filas, hay espacio.
SELECT a.id, a.name, s.name AS servicio, a.`time` AS inicio,
       ADDTIME(a.`time`, SEC_TO_TIME(s.duration * 60)) AS fin
FROM appointments a JOIN services s ON s.id = a.service_id
WHERE a.`date` = '2026-11-20' AND a.status <> 'Cancelada'
  AND a.`time` < ADDTIME('10:30:00', SEC_TO_TIME(60 * 60))      -- empieza antes de que termine la nueva
  AND ADDTIME(a.`time`, SEC_TO_TIME(s.duration * 60)) > '10:30:00'; -- termina después de que empieza la nueva


-- 4. Consultas con JOIN (relacionan tablas)
-- Citas con los datos del servicio y la cuenta del cliente
SELECT a.`date`, a.`time`, u.name AS cliente, u.email, s.name AS servicio, s.price, a.status
FROM appointments a
JOIN users u    ON u.id = a.user_id
JOIN services s ON s.id = a.service_id
ORDER BY a.`date`, a.`time`;

-- Clientes que nunca han agendado
SELECT u.name, u.email FROM users u
LEFT JOIN appointments a ON a.user_id = u.id
WHERE u.role = 'cliente' AND a.id IS NULL;

-- Citas con hora de finalización estimada
SELECT a.name, s.name AS servicio, a.`time` AS inicio,
       ADDTIME(a.`time`, SEC_TO_TIME(s.duration * 60)) AS fin
FROM appointments a JOIN services s ON s.id = a.service_id
WHERE a.status <> 'Cancelada';


-- 5. Subconsultas (consulta dentro de otra consulta)
-- Servicios más caros que el precio promedio
SELECT name, price FROM services
WHERE price > (SELECT AVG(price) FROM services);

-- Clientes que nunca han agendado (con NOT IN)
SELECT name, email FROM users
WHERE role = 'cliente' AND id NOT IN (SELECT user_id FROM appointments);

-- Servicios que nadie ha reservado (con NOT EXISTS)
SELECT s.name FROM services s
WHERE NOT EXISTS (SELECT 1 FROM appointments a WHERE a.service_id = s.id);

-- Clientes con más citas que el promedio por cliente (subconsulta en HAVING)
SELECT u.name, COUNT(*) AS citas
FROM appointments a JOIN users u ON u.id = a.user_id
GROUP BY u.id, u.name
HAVING COUNT(*) > (SELECT COUNT(*) / COUNT(DISTINCT user_id) FROM appointments);

-- Citas del servicio más caro (subconsulta escalar con MAX)
SELECT a.name, a.service_name, a.`date`, a.`time`, a.status
FROM appointments a
WHERE a.service_id = (SELECT id FROM services ORDER BY price DESC LIMIT 1);

-- Total de citas activas de cada cliente (subconsulta en el SELECT)
SELECT u.name,
       (SELECT COUNT(*) FROM appointments a
        WHERE a.user_id = u.id AND a.status <> 'Cancelada') AS citas_activas
FROM users u
WHERE u.role = 'cliente'
ORDER BY citas_activas DESC;


-- 6. Reportes y estadísticas
-- Servicio más solicitado
SELECT service_name, COUNT(*) AS veces FROM appointments
WHERE status <> 'Cancelada' GROUP BY service_name ORDER BY veces DESC;

-- Citas por estado
SELECT status, COUNT(*) FROM appointments GROUP BY status;

-- Ingresos de citas confirmadas
SELECT SUM(s.price) AS ingresos
FROM appointments a JOIN services s ON s.id = a.service_id
WHERE a.status = 'Confirmada';

-- Ingresos por servicio
SELECT s.name, COUNT(*) AS citas, SUM(s.price) AS total
FROM appointments a JOIN services s ON s.id = a.service_id
WHERE a.status = 'Confirmada' GROUP BY s.id, s.name ORDER BY total DESC;

-- Ingresos por mes
SELECT DATE_FORMAT(a.`date`, '%Y-%m') AS mes, SUM(s.price) AS total
FROM appointments a JOIN services s ON s.id = a.service_id
WHERE a.status = 'Confirmada' GROUP BY mes ORDER BY mes;

-- Mejores clientes (más citas)
SELECT u.name, COUNT(*) AS citas FROM appointments a
JOIN users u ON u.id = a.user_id
WHERE a.status <> 'Cancelada' GROUP BY u.id, u.name ORDER BY citas DESC;

-- Tasa de cancelación
SELECT ROUND(100 * SUM(status = 'Cancelada') / COUNT(*), 1) AS porcentaje_canceladas
FROM appointments;

-- Días con más citas
SELECT `date`, COUNT(*) FROM appointments
WHERE status <> 'Cancelada' GROUP BY `date` ORDER BY 2 DESC;


-- 7. Sesiones
-- Sesiones activas (expires_at está en milisegundos)
SELECT s.user_id, u.name, FROM_UNIXTIME(s.expires_at/1000) AS vence
FROM sessions s JOIN users u ON u.id = s.user_id
WHERE s.expires_at > UNIX_TIMESTAMP() * 1000;

-- Limpiar sesiones vencidas
DELETE FROM sessions WHERE expires_at < UNIX_TIMESTAMP() * 1000;


-- 8. Modificaciones (INSERT / UPDATE / DELETE)
-- OJO: esta sección CAMBIA los datos de prueba. Ejecútala solo cuando quieras demostrar el DML.

-- Confirmar o cancelar una cita
UPDATE appointments SET status = 'Confirmada'
WHERE id = 'a0000000-0000-4000-8000-000000000005';
UPDATE appointments SET status = 'Cancelada'
WHERE id = 'a0000000-0000-4000-8000-000000000005';

-- Cambiar precio de un servicio
UPDATE services SET price = 50000 WHERE id = 's2';

-- Agregar un servicio nuevo
INSERT INTO services (id, name, description, price, duration, icon, `position`)
VALUES ('s7', 'Uñas en gel', 'Construcción en gel.', 70000, 90, '✨', 6)
ON DUPLICATE KEY UPDATE id = id;

-- Crear una cita
-- (id fijo y ON DUPLICATE KEY para poder ejecutar el script varias veces sin error 1062)
INSERT INTO appointments (id, user_id, name, phone, email, service_id, service_name, `date`, `time`)
VALUES ('a0000000-0000-4000-8000-000000000014', 2, 'Laura Gómez', '3001234567', 'laura@example.com', 's1', 'Manicure tradicional', '2026-11-25', '10:00:00')
ON DUPLICATE KEY UPDATE id = id;

-- Eliminar una cita (se crea una de ejemplo con id fijo y luego se elimina)
INSERT INTO appointments (id, user_id, name, phone, email, service_id, service_name, `date`, `time`, notes)
VALUES ('a0000000-0000-4000-8000-000000000013', 4, 'Andrea Pérez', '3023334455', 'andrea@example.com',
        's5', 'Diseño de uñas', '2026-12-01', '11:00:00', 'Cita de ejemplo para eliminar')
ON DUPLICATE KEY UPDATE id = id;
DELETE FROM appointments WHERE id = 'a0000000-0000-4000-8000-000000000013';


-- =====================================================================
--  9. SEGURIDAD DE LA BASE DE DATOS (ejecutar con el usuario root)
-- =====================================================================

-- 9.1 Evidencia de contraseñas cifradas: se ve el hash, no la contraseña real
SELECT id, name, email, password_hash FROM users;

-- 9.2 Vista pública de usuarios SIN la contraseña y SIN el teléfono
--     (el teléfono es un dato sensible: solo se consulta cifrado/descifrado en la sección 10)
CREATE OR REPLACE VIEW v_users_publico AS
SELECT id, name, email, role, created_at FROM users;

-- 9.3 Usuario de la aplicación: solo puede leer y modificar datos (no borrar tablas)
--     Cambia las claves de ejemplo por las tuyas.
CREATE USER IF NOT EXISTS 'nailart_app'@'localhost' IDENTIFIED BY 'CambiaEstaClave_2026!';
GRANT SELECT, INSERT, UPDATE, DELETE ON nailart.* TO 'nailart_app'@'localhost';

-- 9.4 Usuario de solo lectura: ve servicios y la vista pública, nunca el hash
CREATE USER IF NOT EXISTS 'nailart_lectura'@'localhost' IDENTIFIED BY 'OtraClave_2026!';
GRANT SELECT ON nailart.services TO 'nailart_lectura'@'localhost';
GRANT SELECT ON nailart.v_users_publico TO 'nailart_lectura'@'localhost';

-- 9.5 Evidencia de los permisos
SHOW GRANTS FOR 'nailart_app'@'localhost';
SHOW GRANTS FOR 'nailart_lectura'@'localhost';

-- 9.6 Evidencia de la vista sin contraseña
SELECT * FROM v_users_publico;

-- =====================================================================
-- 8. SUBCONSULTAS
-- =====================================================================

-- 8.1 Subconsulta escalar: servicios más caros que el precio promedio
SELECT name, price
FROM services
WHERE price > (SELECT AVG(price) FROM services);

-- 8.2 Subconsulta con IN: clientes que tienen al menos una cita confirmada
SELECT name, email
FROM users
WHERE id IN (SELECT user_id FROM appointments WHERE status = 'Confirmada');

-- 8.3 Subconsulta con NOT IN: clientes que nunca han agendado
SELECT name, email
FROM users
WHERE role = 'cliente'
  AND id NOT IN (SELECT user_id FROM appointments);

-- 8.4 Subconsulta con NOT EXISTS: servicios que nunca se han agendado
SELECT s.name
FROM services s
WHERE NOT EXISTS (SELECT 1 FROM appointments a WHERE a.service_id = s.id);

-- 8.5 Subconsulta con EXISTS: servicios que tienen al menos una cita activa
SELECT s.name, s.price
FROM services s
WHERE EXISTS (SELECT 1 FROM appointments a
              WHERE a.service_id = s.id AND a.status <> 'Cancelada');

-- 8.6 Subconsulta dentro del SELECT: citas activas por cada cliente
SELECT u.name,
       (SELECT COUNT(*)
        FROM appointments a
        WHERE a.user_id = u.id AND a.status <> 'Cancelada') AS citas_activas
FROM users u
WHERE u.role = 'cliente'
ORDER BY citas_activas DESC;

-- 8.7 Subconsulta en FROM (tabla derivada): promedio de citas por cliente
SELECT ROUND(AVG(total), 2) AS promedio_citas_por_cliente
FROM (SELECT user_id, COUNT(*) AS total
      FROM appointments
      GROUP BY user_id) AS conteo;

-- 8.8 Subconsulta con ALL: servicios más caros que todos los servicios rápidos (30 a 45 min)
SELECT name, price, duration
FROM services
WHERE price > ALL (SELECT price FROM services WHERE duration <= 45);

-- 8.9 Subconsulta correlacionada: la próxima cita activa de cada cliente
SELECT a.name, a.service_name, a.`date`, a.`time`
FROM appointments a
WHERE a.status <> 'Cancelada'
  AND a.`date` >= CURDATE()
  AND a.`date` = (SELECT MIN(b.`date`)
                  FROM appointments b
                  WHERE b.user_id = a.user_id
                    AND b.status <> 'Cancelada'
                    AND b.`date` >= CURDATE())
ORDER BY a.`date`, a.`time`;

-- 8.10 Subconsulta en HAVING: clientes con más citas activas que el promedio
SELECT u.name, COUNT(*) AS citas
FROM users u
JOIN appointments a ON a.user_id = u.id
WHERE a.status <> 'Cancelada'
GROUP BY u.id, u.name
HAVING COUNT(*) > (SELECT COUNT(*) / COUNT(DISTINCT user_id)
                   FROM appointments
                   WHERE status <> 'Cancelada');
                   
                   
-- =====================================================================
--  10. CIFRADO REVERSIBLE (AES) DE DATOS SENSIBLES
--  Las contraseñas usan HASH (no reversible, lo correcto para claves).
--  Los datos que SÍ hay que poder leer después (ej.: el teléfono) se
--  protegen con cifrado AES: sin la clave son bytes ilegibles.
-- =====================================================================

-- 10.1 Clave de cifrado (cámbiala por la tuya)
SET @clave_cifrado = 'ClaveSecreta_NailArt_2026';

-- 10.2 Tabla para datos sensibles cifrados (el teléfono se guarda cifrado)
CREATE TABLE IF NOT EXISTS users_sensibles (
  user_id   INT UNSIGNED  NOT NULL,
  phone_enc VARBINARY(255) NOT NULL,
  PRIMARY KEY (user_id),
  CONSTRAINT fk_sens_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 10.3 Cifrar el teléfono de cada usuario
INSERT INTO users_sensibles (user_id, phone_enc)
SELECT id, AES_ENCRYPT(phone, @clave_cifrado) FROM users
ON DUPLICATE KEY UPDATE user_id = user_id;

-- 10.4 EVIDENCIA 1: lo que ve alguien SIN la clave (bytes ilegibles)
SELECT user_id, HEX(phone_enc) AS telefono_cifrado FROM users_sensibles;

-- 10.5 EVIDENCIA 2: con la clave correcta se descifra
SELECT u.name, CAST(AES_DECRYPT(s.phone_enc, @clave_cifrado) AS CHAR) AS telefono_descifrado
FROM users_sensibles s JOIN users u ON u.id = s.user_id;

-- 10.6 EVIDENCIA 3: con una clave incorrecta no se puede leer (normalmente devuelve NULL)
SELECT user_id, CAST(AES_DECRYPT(phone_enc, 'clave_equivocada') AS CHAR) AS con_clave_incorrecta
FROM users_sensibles;

-- ---------------------------------------------------------------------
--  10.7 CIFRADO DEL NÚMERO DE DOCUMENTO (dato personal sensible)
--  Se guarda en una tabla aparte, cifrado con AES. Los números de abajo
--  son FICTICIOS, solo para la demostración.
--  Ejecútalo en la misma pestaña donde definiste @clave_cifrado (10.1).
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users_documentos (
  user_id      INT UNSIGNED   NOT NULL,
  document_enc VARBINARY(255) NOT NULL,
  PRIMARY KEY (user_id),
  CONSTRAINT fk_doc_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO users_documentos (user_id, document_enc) VALUES
  (1, AES_ENCRYPT('52000111',   @clave_cifrado)),
  (2, AES_ENCRYPT('1012345678', @clave_cifrado)),
  (3, AES_ENCRYPT('1023456789', @clave_cifrado)),
  (4, AES_ENCRYPT('1034567890', @clave_cifrado)),
  (5, AES_ENCRYPT('1045678901', @clave_cifrado)),
  (6, AES_ENCRYPT('1056789012', @clave_cifrado))
ON DUPLICATE KEY UPDATE user_id = user_id;

-- 10.8 EVIDENCIA 1: el documento guardado es ilegible sin la clave
SELECT user_id, HEX(document_enc) AS documento_cifrado FROM users_documentos;

-- 10.9 EVIDENCIA 2: con la clave se descifra
SELECT u.name, CAST(AES_DECRYPT(d.document_enc, @clave_cifrado) AS CHAR) AS documento
FROM users_documentos d JOIN users u ON u.id = d.user_id;

-- 10.10 EVIDENCIA 3: enmascarado (solo los últimos 4 dígitos), buena práctica al mostrarlo
SELECT u.name,
       CONCAT('******', RIGHT(CAST(AES_DECRYPT(d.document_enc, @clave_cifrado) AS CHAR), 4)) AS documento_enmascarado
FROM users_documentos d JOIN users u ON u.id = d.user_id;

-- ---------------------------------------------------------------------
--  10.11 VER TELÉFONO Y DOCUMENTO JUNTOS
--  (ejecutar en la misma pestaña donde definiste @clave_cifrado)
-- ---------------------------------------------------------------------

-- Lo que vería alguien que robe la base de datos SIN la clave: todo ilegible
SELECT u.name,
       HEX(s.phone_enc)    AS telefono_cifrado,
       HEX(d.document_enc) AS documento_cifrado
FROM users u
JOIN users_sensibles  s ON s.user_id = u.id
JOIN users_documentos d ON d.user_id = u.id;

-- Lo que ve la aplicación CON la clave: teléfono completo y documento enmascarado
SELECT u.id, u.name, u.email,
       CAST(AES_DECRYPT(s.phone_enc, @clave_cifrado) AS CHAR) AS telefono,
       CONCAT('******', RIGHT(CAST(AES_DECRYPT(d.document_enc, @clave_cifrado) AS CHAR), 4)) AS documento_enmascarado
FROM users u
JOIN users_sensibles  s ON s.user_id = u.id
JOIN users_documentos d ON d.user_id = u.id;

-- ---------------------------------------------------------------------
--  10.12 DATOS SENSIBLES DE UN SOLO CLIENTE
--  Cada cliente solo debe ver SUS datos. MySQL no tiene seguridad por
--  fila, así que esta regla la aplica el backend: el id sale del token de
--  sesión (nunca de lo que el usuario escriba) y la consulta filtra por él.
--  Ejemplo para el cliente con id 2 (Laura):
-- ---------------------------------------------------------------------
SELECT u.name, u.email,
       CAST(AES_DECRYPT(s.phone_enc, @clave_cifrado) AS CHAR)    AS telefono,
       CAST(AES_DECRYPT(d.document_enc, @clave_cifrado) AS CHAR) AS documento
FROM users u
JOIN users_sensibles  s ON s.user_id = u.id
JOIN users_documentos d ON d.user_id = u.id
WHERE u.id = 2;