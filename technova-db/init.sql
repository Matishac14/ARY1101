-- TechNova Solutions — Schema inicial
-- El alumno debe completar ALUMNO_RUT en el .env (DB_NAME=tienda_<RUT>)

SET NAMES utf8mb4;
SET CHARACTER SET utf8mb4;

CREATE DATABASE IF NOT EXISTS technova CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE technova;

CREATE TABLE IF NOT EXISTS productos (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  nombre     VARCHAR(255)   NOT NULL,
  precio     DECIMAL(10,2)  NOT NULL,
  stock      INT            NOT NULL DEFAULT 0,
  categoria  VARCHAR(100),
  creado_en  TIMESTAMP      DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP  DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS pedidos (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  producto_id  INT            NOT NULL,
  cantidad     INT            NOT NULL,
  estado       ENUM('pendiente','procesado','enviado','cancelado') NOT NULL DEFAULT 'pendiente',
  creado_en    TIMESTAMP      DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP   DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (producto_id) REFERENCES productos(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Datos de muestra
INSERT INTO productos (nombre, precio, stock, categoria) VALUES
  ('Notebook ASUS VivoBook 15', 649990, 10, 'Computadores'),
  ('Monitor LG 27" 4K',          399990,  5, 'Monitores'),
  ('Teclado Mecánico Redragon',   49990, 25, 'Periféricos'),
  ('Mouse Logitech MX Master 3',  89990, 15, 'Periféricos'),
  ('SSD Samsung 1TB NVMe',        79990, 30, 'Almacenamiento');

INSERT INTO pedidos (producto_id, cantidad, estado) VALUES
  (1, 2, 'procesado'),
  (3, 5, 'enviado'),
  (2, 1, 'pendiente');
