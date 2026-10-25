-- ============================================================
-- MAMORU — ESQUEMA COMPLETO DE BASE DE DATOS (v2)
-- Un solo script: crea la base de datos completa desde cero.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. USUARIOS
-- Gestión de usuarios y roles. El adulto mayor no usa correo/contraseña
-- (accede mediante invitaciones_vinculacion); familiar y cuidador sí.
CREATE TABLE usuarios (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre VARCHAR(150) NOT NULL,
    apellido VARCHAR(150),
    email VARCHAR(150) UNIQUE,
    password_hash VARCHAR(255),

    rol VARCHAR(20) NOT NULL CHECK (
        rol IN (
            'adulto_mayor',
            'familiar',
            'cuidador',
            'administrador'
        )
    ),

    telefono VARCHAR(20),
    activo BOOLEAN DEFAULT TRUE,

    codigo_verificacion VARCHAR(10),
    codigo_verificacion_expira TIMESTAMP,
    email_verificado BOOLEAN DEFAULT FALSE,

    fecha_creacion TIMESTAMP DEFAULT NOW()
);

-- 2. PERFILES DE CUIDADOR
-- Información adicional de los cuidadores
CREATE TABLE perfiles_cuidador (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    usuario_id UUID NOT NULL
        REFERENCES usuarios(id)
        ON DELETE CASCADE,

    experiencia TEXT,
    servicios_ofrecidos TEXT,
    ubicacion VARCHAR(150),
    tarifa_hora NUMERIC(10,2),
    es_area_salud BOOLEAN DEFAULT FALSE,

    disponible BOOLEAN DEFAULT TRUE,
    valoracion_promedio NUMERIC(2,1) DEFAULT 0.0,

    estado_validacion VARCHAR(20) DEFAULT 'pendiente'
        CHECK (
            estado_validacion IN (
                'pendiente',
                'aprobado',
                'rechazado'
            )
        ),

    profesion VARCHAR(150),
    documento_url VARCHAR(500),
    fecha_validacion TIMESTAMP,
    motivo_rechazo TEXT,

    fecha_creacion TIMESTAMP DEFAULT NOW()
);

-- 3. PERFILES DE ADULTO MAYOR
-- Datos médicos y personales que ingresa el familiar al crear la invitación
CREATE TABLE perfiles_adulto_mayor (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    usuario_id UUID UNIQUE NOT NULL
        REFERENCES usuarios(id)
        ON DELETE CASCADE,

    fecha_nacimiento DATE,
    enfermedades TEXT,
    alergia_medicamentos TEXT,
    alergia_alimentos TEXT,
    intolerancia_alimentaria TEXT,

    fecha_creacion TIMESTAMP DEFAULT NOW()
);

-- 4. CONTACTOS DE EMERGENCIA
-- Hasta 3 por adulto mayor; visibles para el cuidador, notificados ante SOS
CREATE TABLE contactos_emergencia (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    adulto_mayor_id UUID NOT NULL
        REFERENCES usuarios(id)
        ON DELETE CASCADE,

    nombre VARCHAR(150) NOT NULL,
    telefono VARCHAR(20) NOT NULL,
    parentesco VARCHAR(50),
    orden INTEGER NOT NULL CHECK (orden BETWEEN 1 AND 3),

    fecha_creacion TIMESTAMP DEFAULT NOW()
);

-- 5. INVITACIONES DE VINCULACIÓN
-- Acceso del adulto mayor sin correo/contraseña: código/QR temporal, de un
-- solo uso, revocable y trazable, generado por el familiar.
CREATE TABLE invitaciones_vinculacion (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    adulto_mayor_id UUID NOT NULL
        REFERENCES usuarios(id)
        ON DELETE CASCADE,

    creado_por_familiar_id UUID NOT NULL
        REFERENCES usuarios(id),

    token_hash VARCHAR(255),
    codigo VARCHAR(10) NOT NULL,

    estado VARCHAR(20) DEFAULT 'pendiente'
        CHECK (
            estado IN (
                'pendiente',
                'usado',
                'expirado',
                'revocado'
            )
        ),

    expira_en TIMESTAMP NOT NULL,
    utilizado_en TIMESTAMP,
    creado_en TIMESTAMP DEFAULT NOW()
);

-- 6. VINCULACIONES
-- Relación permanente familiar <-> adulto mayor (la relación con el
-- cuidador es temporal y se maneja en solicitudes_servicio).
CREATE TABLE vinculaciones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    adulto_mayor_id UUID NOT NULL
        REFERENCES usuarios(id)
        ON DELETE CASCADE,

    familiar_id UUID NOT NULL
        REFERENCES usuarios(id)
        ON DELETE CASCADE,

    estado VARCHAR(20) DEFAULT 'activa'
        CHECK (
            estado IN (
                'activa',
                'revocada'
            )
        ),

    fecha_vinculacion TIMESTAMP DEFAULT NOW()
);

-- 7. SOLICITUDES DE SERVICIO
-- Marketplace de cuidadores: contratación de un servicio para un adulto
-- mayor específico, con su propio período, tipo de servicio y resolución.
CREATE TABLE solicitudes_servicio (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    solicitante_id UUID NOT NULL
        REFERENCES usuarios(id)
        ON DELETE CASCADE,

    adulto_mayor_id UUID NOT NULL
        REFERENCES usuarios(id)
        ON DELETE CASCADE,

    cuidador_id UUID NOT NULL
        REFERENCES perfiles_cuidador(id)
        ON DELETE CASCADE,

    estado VARCHAR(20) DEFAULT 'pendiente'
        CHECK (
            estado IN (
                'pendiente',
                'aceptada',
                'rechazada',
                'finalizada'
            )
        ),

    direccion VARCHAR(255),
    fecha_inicio DATE,
    hora_inicio TIME,
    fecha_termino DATE,
    hora_termino TIME,

    tipo_servicio VARCHAR(50)
        CHECK (
            tipo_servicio IN (
                'acompanamiento_apoyo_emocional',
                'cuidado_fisico_personal',
                'control_medicamentos',
                'alimentacion',
                'cuidador_integral',
                'cuidado_puertas_adentro'
            )
        ),

    informacion_adicional TEXT,
    mensaje TEXT,

    motivo_rechazo VARCHAR(50)
        CHECK (
            motivo_rechazo IN (
                'no_tengo_disponibilidad',
                'horario_no_acomoda',
                'ubicacion_fuera_zona',
                'tipo_cuidado_no_corresponde',
                'otros'
            )
        ),
    motivo_rechazo_detalle TEXT,

    fecha_solicitud TIMESTAMP DEFAULT NOW(),
    fecha_resolucion TIMESTAMP
);

-- 8. TAREAS Y RECORDATORIOS
-- Pertenecen al adulto mayor (no a un servicio específico). El familiar
-- las crea; durante un servicio activo, el cuidador también accede a ellas.
CREATE TABLE tareas_recordatorios (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    adulto_mayor_id UUID NOT NULL
        REFERENCES usuarios(id)
        ON DELETE CASCADE,

    creado_por_id UUID
        REFERENCES usuarios(id),

    titulo VARCHAR(150) NOT NULL,
    categoria VARCHAR(50),
    descripcion TEXT,

    estado VARCHAR(20) DEFAULT 'pendiente'
        CHECK (
            estado IN (
                'pendiente',
                'realizada',
                'no_realizada'
            )
        ),

    fecha_programada TIMESTAMP NOT NULL,
    fecha_confirmacion TIMESTAMP
);

-- 9. BITÁCORA DE CUIDADOS
-- Observaciones por actividad específica (hasta 2 por tarea, a nivel de
-- aplicación), con trazabilidad de bajo qué servicio se hizo.
CREATE TABLE bitacora_cuidados (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    tarea_id UUID NOT NULL
        REFERENCES tareas_recordatorios(id)
        ON DELETE CASCADE,

    solicitud_servicio_id UUID
        REFERENCES solicitudes_servicio(id)
        ON DELETE SET NULL,

    autor_id UUID NOT NULL
        REFERENCES usuarios(id),

    observacion TEXT NOT NULL,
    tipo_incidencia VARCHAR(50) DEFAULT 'general',

    fecha_registro TIMESTAMP DEFAULT NOW()
);

-- 10. ALERTAS SOS
CREATE TABLE alertas_sos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    usuario_id UUID NOT NULL
        REFERENCES usuarios(id)
        ON DELETE CASCADE,

    estado VARCHAR(20) DEFAULT 'activa'
        CHECK (
            estado IN (
                'activa',
                'atendida',
                'cancelada'
            )
        ),

    fecha_alerta TIMESTAMP DEFAULT NOW(),
    fecha_atencion TIMESTAMP
);

-- 11. NOTIFICACIONES
CREATE TABLE notificaciones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    usuario_id UUID NOT NULL
        REFERENCES usuarios(id)
        ON DELETE CASCADE,

    tipo VARCHAR(30) NOT NULL,
    mensaje TEXT NOT NULL,
    leida BOOLEAN DEFAULT FALSE,

    fecha_envio TIMESTAMP DEFAULT NOW()
);

-- 12. VALORACIONES
-- Reseñas de los cuidadores, anónimas, con flujo de reporte/moderación.
CREATE TABLE valoraciones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    solicitud_id UUID NOT NULL
        REFERENCES solicitudes_servicio(id)
        ON DELETE CASCADE,

    puntuacion INTEGER NOT NULL
        CHECK (puntuacion BETWEEN 1 AND 5),

    comentario TEXT,
    fecha TIMESTAMP DEFAULT NOW(),

    reportada BOOLEAN DEFAULT FALSE,
    motivo_reporte TEXT,
    habilitada BOOLEAN DEFAULT TRUE
);

-- 13. AUDITORÍA
-- Registro de acciones administrativas (aprobar/rechazar cuidadores,
-- moderar reseñas, etc.), generado automáticamente por el backend.
CREATE TABLE auditoria (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    administrador_id UUID NOT NULL
        REFERENCES usuarios(id),

    accion VARCHAR(100) NOT NULL,
    entidad_tipo VARCHAR(50) NOT NULL,
    entidad_id UUID,
    detalle TEXT,

    fecha TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- ÍNDICES
-- ============================================================
CREATE INDEX idx_usuarios_email ON usuarios(email);
CREATE INDEX idx_usuarios_rol ON usuarios(rol);

CREATE INDEX idx_perfiles_cuidador_ubicacion ON perfiles_cuidador(ubicacion);
CREATE INDEX idx_perfiles_cuidador_estado_validacion ON perfiles_cuidador(estado_validacion);

CREATE INDEX idx_vinculaciones_adulto_mayor ON vinculaciones(adulto_mayor_id);
CREATE INDEX idx_vinculaciones_familiar ON vinculaciones(familiar_id);

CREATE INDEX idx_tareas_adulto_mayor ON tareas_recordatorios(adulto_mayor_id);
CREATE INDEX idx_tareas_estado ON tareas_recordatorios(estado);

CREATE INDEX idx_bitacora_tarea ON bitacora_cuidados(tarea_id);

CREATE INDEX idx_notificaciones_usuario_leida ON notificaciones(usuario_id, leida);

CREATE INDEX idx_solicitudes_cuidador ON solicitudes_servicio(cuidador_id);
CREATE INDEX idx_solicitudes_adulto_mayor ON solicitudes_servicio(adulto_mayor_id);

CREATE INDEX idx_contactos_adulto_mayor ON contactos_emergencia(adulto_mayor_id);
CREATE INDEX idx_invitaciones_codigo ON invitaciones_vinculacion(codigo);
