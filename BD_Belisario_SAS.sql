IF DB_ID('belisario_sas') IS NOT NULL
    DROP DATABASE belisario_sas;
GO

CREATE DATABASE belisario_sas;
GO

USE belisario_sas;
GO

-- CREACIÓN DE TABLAS 
CREATE TABLE clientes (
    id_cliente INT IDENTITY(1,1) PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    tipo_documento VARCHAR(20),
    documento VARCHAR(30) UNIQUE,
    telefono VARCHAR(20),
    correo VARCHAR(150)
);

CREATE TABLE profesionales (
    id_profesional INT IDENTITY(1,1) PRIMARY KEY,
    nombre VARCHAR(150),
    especialidad VARCHAR(50),
    telefono VARCHAR(20),
    correo VARCHAR(150)
);

CREATE TABLE casos_juridicos (
    id_caso INT IDENTITY(1,1) PRIMARY KEY,
    id_cliente INT,
    id_profesional INT,
    tipo_caso VARCHAR(100),
    fecha_apertura DATE,
    estado VARCHAR(50),
    descripcion VARCHAR(MAX),
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
    FOREIGN KEY (id_profesional) REFERENCES profesionales(id_profesional)
);

CREATE TABLE facturacion (
    id_factura INT IDENTITY(1,1) PRIMARY KEY,
    id_caso INT,
    fecha DATE,
    valor DECIMAL(10,2),
    impuestos DECIMAL(10,2),
    total AS (valor + impuestos),
    FOREIGN KEY (id_caso) REFERENCES casos_juridicos(id_caso)
);

 -- DATOS DE PRUEBA 
 INSERT INTO clientes (nombre, tipo_documento, documento, telefono, correo) VALUES
('Carlos Gómez', 'CC', '1012345678', '3201112233', 'carlos@email.com'),
('María Fernanda López', 'CC', '1029384756', '3112203344', 'maria.lopez@gmail.com'),
('Empresa ABC SAS', 'NIT', '900123456', '3155558899', 'contacto@abc.com'),
('Jorge Rodríguez', 'CC', '9876543210', '3005678899', 'jorger@gmail.com'),
('Luisa Martínez', 'CC', '1034567890', '3019988776', 'luisa.martinez@hotmail.com'),
('Servicios Integrales LTDA', 'NIT', '901223344', '3176655443', 'info@serviciosintegrales.com'),
('Pedro Silva', 'CC', '1100220033', '3001122334', 'pedro.silva@yahoo.com'),
('Claudia Ramírez', 'CC', '1099887766', '3205566778', 'claudia.ramirez@gmail.com'),
('Cliente Prueba Error', 'CC', NULL, NULL, 'malcorreo.com'),
('Marcos Prieto', 'CC', '1019988776', '3123456789', 'marcosprieto@empresa.com');

INSERT INTO profesionales (nombre, especialidad, telefono, correo) VALUES
('Ana Torres', 'Derecho Laboral', '3105552233', 'atorres@belisario.com'),
('Juan Ruiz', 'SST', '3124441122', 'jruiz@belisario.com'),
('Error user', NULL, '3110000000', 'correo_mal');

INSERT INTO casos_juridicos (id_cliente, id_profesional, tipo_caso, fecha_apertura, estado, descripcion) VALUES
(1, 1, 'Despido sin justa causa', '2025-01-10', 'En trámite', 'Demanda laboral por despido injustificado'),
(2, 2, 'Accidente laboral SST', '2025-01-15', 'Finalizado', 'Investigación accidente laboral'),
(NULL, 1, 'Error caso', '2025-02-01', 'Pendiente', 'Caso sin cliente');

INSERT INTO facturacion (id_caso, fecha, valor, impuestos) VALUES
(1, '2025-02-01', 850000, 161500),
(1, '2025-02-15', 920000, 174800),
(2, '2025-01-28', 1300000, 247000),
(2, '2025-02-10', 1150000, 218500),
(3, '2025-03-05', 600000, 114000),
(1, '2025-03-10', 750000, 142500),
(2, '2025-03-15', 1400000, 266000),
(3, '2025-03-20', 500000, -20000),       -- con error para ETL
(1, '2025-04-01', 830000, 157000),
(2, '2028-01-10', 500000, 25000);       -- fecha futura

--TABLA DE ERRORES 
CREATE TABLE log_errores (
    id INT IDENTITY(1,1) PRIMARY KEY,
    tabla_afectada VARCHAR(100),
    id_registro INT,
    descripcion_error VARCHAR(255),
    fecha_error DATETIME DEFAULT GETDATE()
);

-- VALIDACIÓN ETL
--Total incorrecto
INSERT INTO log_errores (tabla_afectada, id_registro, descripcion_error)
SELECT 'facturacion', id_factura, 'Total incorrecto'
FROM facturacion
WHERE valor + impuestos <> total;

-- Valores negativos 
INSERT INTO log_errores (tabla_afectada, id_registro, descripcion_error)
SELECT 'facturacion', id_factura, 'Valor/impuestos negativos'
FROM facturacion
WHERE valor < 0 OR impuestos < 0;

-- Fechas 
INSERT INTO log_errores (tabla_afectada, id_registro, descripcion_error)
SELECT 'facturacion', id_factura, 'Fecha futura'
FROM facturacion
WHERE fecha > CAST(GETDATE() AS DATE);

-- Facturas sin caso 
INSERT INTO log_errores (tabla_afectada, id_registro, descripcion_error)
SELECT 'facturacion', id_factura, 'Factura sin caso'
FROM facturacion
WHERE id_caso IS NULL;

-- Casos si cliente 
INSERT INTO log_errores (tabla_afectada, id_registro, descripcion_error)
SELECT 'casos_juridicos', id_caso, 'Caso sin cliente'
FROM casos_juridicos
WHERE id_cliente IS NULL;

-- Correos 
INSERT INTO log_errores (tabla_afectada, id_registro, descripcion_error)
SELECT 'clientes', id_cliente, 'Correo inválido'
FROM clientes
WHERE correo NOT LIKE '%@%';

-- Doc vacio 
INSERT INTO log_errores (tabla_afectada, id_registro, descripcion_error)
SELECT 'clientes', id_cliente, 'Documento vacío'
FROM clientes
WHERE documento IS NULL OR documento = '';

-- Profesional sin especialidad
INSERT INTO log_errores (tabla_afectada, id_registro, descripcion_error)
SELECT 'profesionales', id_profesional, 'Especialidad vacía'
FROM profesionales
WHERE especialidad IS NULL OR especialidad = '';

-- LIMPIEZA AUTOMATICA ETL 
--Valores negativos 
UPDATE f
SET valor = ABS(valor),
    impuestos = ABS(impuestos)
FROM facturacion f
WHERE valor < 0 OR impuestos < 0;

-- Fechas 
UPDATE facturacion
SET fecha = CAST(GETDATE() AS DATE)
WHERE fecha > CAST(GETDATE() AS DATE);

-- Correos 
UPDATE clientes
SET correo = 'correo_invalido_' + CAST(id_cliente AS VARCHAR(10)) + '@dominio.com'
WHERE correo NOT LIKE '%@%';

-- Crear cliente generico 
INSERT INTO clientes (nombre, tipo_documento, documento, telefono, correo)
VALUES ('CLIENTE NO REGISTRADO', 'NA', 'GEN_' + CAST(ABS(CHECKSUM(NEWID())) AS VARCHAR(10)), NULL, 'noreply@empresa.com');

DECLARE @cliente_generico INT = SCOPE_IDENTITY();

UPDATE casos_juridicos
SET id_cliente = @cliente_generico
WHERE id_cliente IS NULL;

-- Vista de datos limpios 
GO 
DROP VIEW IF EXISTS vw_facturacion_limpia;
GO

CREATE VIEW v_facturacion_limpia AS
SELECT DISTINCT
    f.id_factura,
    f.fecha,
    c.nombre AS cliente,
    c.documento,
    c.telefono,
    c.correo,
    cj.id_caso,
    cj.tipo_caso,
    cj.estado,
    p.nombre AS profesional,
    f.valor,
    f.impuestos,
    f.total,
    COALESCE(le.descripcion_error, 'SIN ERRORES') AS descripcion_error
FROM facturacion f
LEFT JOIN casos_juridicos cj ON f.id_caso = cj.id_caso
LEFT JOIN clientes c ON cj.id_cliente = c.id_cliente
LEFT JOIN profesionales p ON cj.id_profesional = p.id_profesional
LEFT JOIN (
        SELECT id_registro, descripcion_error
        FROM log_errores
        WHERE tabla_afectada = 'facturacion'
) le ON f.id_factura = le.id_registro;
GO

GO 

SELECT COUNT(*) AS total_errores FROM log_errores;

SELECT * FROM v_facturacion_limpia;

SELECT estado, COUNT(*) AS cantidad
FROM casos_juridicos
GROUP BY estado;

SELECT 
    FORMAT(fecha, 'yyyy-MM') AS mes,
    SUM(total) AS total_mes
FROM facturacion
GROUP BY FORMAT(fecha, 'yyyy-MM')
ORDER BY mes;


select * from log_errores



