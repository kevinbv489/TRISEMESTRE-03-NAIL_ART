SET NAMES utf8mb4;
CREATE DATABASE IF NOT EXISTS nailart CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE nailart;


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
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- CITAS. active_slot es una columna generada: vale "fecha hora" mientras la cita NO esté cancelada
-- y NULL cuando se cancela. Como tiene índice UNIQUE, MySQL impide dos citas activas en el mismo horario
-- (los NULL no chocan entre sí), incluso si dos personas reservan al mismo tiempo.
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
ON DUPLICATE KEY UPDATE name = VALUES(name);


--  DATOS DE PRUEBA (solo para desarrollo, NO los uses en producción)
--
--  Contraseñas de prueba:
--    Administrador:  maria@example.com                 contraseña  Admin2026x
--    Clientes:       laura@ / camila@ / andrea@ /
--                    valentina@ / sofia@ example.com   contraseña  Cliente123

SET NAMES utf8mb4;

INSERT IGNORE INTO users (id, name, email, phone, role, password_hash) VALUES
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
   'scrypt$mMXHweRVhhT+mDyuVoCqWQ==$0rs3eggRz6lrLsZZkp9FJ2jY9GMwNWi8mv2ias8K49tfYFaxXwVKuz0+YitrHgUifXy5sqJZBFyJArgRSiRhPA==');

INSERT IGNORE INTO appointments (id, user_id, name, phone, email, service_id, service_name, `date`, `time`, notes, status) VALUES
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
  ('a0000000-0000-4000-8000-000000000012', 3, 'Camila Rojas', '3012223344', 'camila@example.com', 's2', 'Semipermanente', DATE_ADD(CURDATE(), INTERVAL 8 DAY), '09:00:00', 'Reutiliza el horario de una cita cancelada', 'Pendiente');
  
  -- ==========================================================================================================================================

  -- CONSULTAS
  
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


-- 5. Reportes y estadísticas
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


-- 6. Sesiones
-- Sesiones activas (expires_at está en milisegundos)
SELECT s.user_id, u.name, FROM_UNIXTIME(s.expires_at/1000) AS vence
FROM sessions s JOIN users u ON u.id = s.user_id
WHERE s.expires_at > UNIX_TIMESTAMP() * 1000;

-- Limpiar sesiones vencidas
DELETE FROM sessions WHERE expires_at < UNIX_TIMESTAMP() * 1000;


-- 7. Modificaciones (INSERT / UPDATE / DELETE)
-- Confirmar o cancelar una cita
UPDATE appointments SET status = 'Confirmada'
WHERE id = 'a0000000-0000-4000-8000-000000000005';
UPDATE appointments SET status = 'Cancelada'
WHERE id = 'a0000000-0000-4000-8000-000000000005';

-- Cambiar precio de un servicio
UPDATE services SET price = 50000 WHERE id = 's2';

-- Agregar un servicio nuevo
INSERT INTO services (id, name, description, price, duration, icon, `position`)
VALUES ('s7', 'Uñas en gel', 'Construcción en gel.', 70000, 90, '✨', 6);

-- Crear una cita
INSERT INTO appointments (id, user_id, name, phone, email, service_id, service_name, `date`, `time`)
VALUES (UUID(), 2, 'Laura Gómez', '3001234567', 'laura@example.com', 's1', 'Manicure tradicional', '2026-11-25', '10:00:00');

-- Eliminar una cita
DELETE FROM appointments WHERE id = '...';


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