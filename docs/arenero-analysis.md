# Análisis del Arenero Automático (MSP-01A)

## Estado Actual de Implementación

### DPs Mapeados (Confirmados)

#### Controles Principales
- **DP3**: `start` - Botón limpiar
- **DP4**: `auto_clean` - Limpieza automática ON/OFF
- **DP17**: `deodorization` - Deodorización ON/OFF
- **DP111**: `replace_litter` - Cambiar arena
- **DP117**: `replace_bag` - Cambiar bolsa

#### Configuración
- **DP5**: `delay_clean_time` - Tiempo para comenzar limpieza (0-60 min)
- **DP103**: `child_lock` - Bloqueo infantil
- **DP104**: `infrared` - Sensor infrarrojo ON/OFF
- **DP105**: `cleaning_interval` - Intervalo entre limpiezas (0-120 min)
- **DP106**: `panel_light` - Luz del panel (invertido)
- **DP114**: `full_bag_threshold` - Umbral bolsa llena (0-15)
- **DP115**: `initialize_litter_box` - Inicializar arenero
- **DP118**: `calibrate_weight` - Calibrar peso

#### Sensores de Uso
- **DP6**: `cat_weight` - Peso del gato (g)
- **DP7**: `excretion_times_day` - Excreciones del día (contador)
- **DP8**: `excretion_time` - Tiempo última excreción (s)

#### Sensores Ambientales
- **DP101**: `temperature` - Temperatura (°C)
- **DP102**: `humidity` - Humedad (%)

#### Otros Sensores
- **DP116**: `real_time_weight` - Peso en tiempo real (g)

### DPs Pendientes de Análisis

#### ✅ NUEVOS DPs Descubiertos en el Boot
- **DP21**: bitmask (valor: 0) - ¿Estados/banderas del sistema?
- **DP22**: bitmask (valor: 0) - ¿Configuración/flags?
- **DP24**: enum (valor: 255) - ¿Estado especial?
- **DP109**: int (valor: 10) - ¿Temporizador o configuración?
- **DP110**: int (valor: 3) - ¿Contador o ajuste?
- **DP112**: switch (OFF) - ¿Función no identificada?
- **DP113**: enum (valor: 0) - ¿Estado/modo?
- **DP119**: switch (OFF) - ¿Nueva función?

#### DPs Sin Mapear (requieren captura con debug)
- **DP1, DP2**: No aparecen en boot - probablemente RAW/STRING (horarios)
- **DP9**: No aparece - posiblemente estado general (enum)
- **DP10**: No aparece - posiblemente faults/errores (enum)

### Funcionalidades del Manual No Implementadas

#### 1. Horarios Programados (Clean Timing)
**Funcionalidad**: Configurar hasta 5 horarios diarios para limpieza automática
- Probablemente DP no identificado o múltiples DPs
- Similar a DP1 del comedero (formato complejo RAW)
- **Acción**: Capturar tráfico al configurar horarios en app

#### 2. Horarios de Deodorización (Deodo Timing)
**Funcionalidad**: Programar cuándo activar deodorización
- Posiblemente otro DP tipo RAW/STRING
- **Acción**: Capturar tráfico al configurar en app

#### 3. Modo No Molestar (Do Not Disturb Timing)
**Funcionalidad**: Horario en el que no se ejecutan operaciones
- Configuración de rango horario (inicio-fin)
- **Acción**: Buscar DP relacionado con DND/Sleep mode

#### 4. Calibración Superficie Arena (Sand Surface Calibration)
**Funcionalidad**: Ajuste 0-6 para tipo de arena
- Probablemente un number DP no descubierto (rango 0-6)
- **Acción**: Verificar si es DP112 o similar

#### 5. Estado de Limpieza Actual
**Funcionalidad**: Indicador visual del progreso/estado
- DP9 parece ser el candidato (enum)
- Estados posibles: "idle", "cleaning", "homing", "paused", "error"

#### 6. Códigos de Error/Fault
**Funcionalidad**: Diagnóstico de problemas
- DP10 parece ser el candidato
- **Acción**: Provocar errores controlados para mapear códigos

### Mejoras de UX Propuestas

#### 1. Binary Sensors
- **Limpiando**: Estado basado en DP9
- **Bolsa llena**: Basado en DP116 vs DP114 threshold
- **Gato dentro**: Basado en cambios en peso en tiempo real
- **Error/Fault**: Basado en DP10

#### 2. Automations Helper
- **Notificación bolsa llena**: Cuando threshold alcanzado
- **Alerta gato atrapado**: Si peso detectado >5min sin cambio durante limpieza
- **Recordatorio cambio arena**: Cada N limpiezas

#### 3. Dashboard Cards
- **Actividad diaria**: Gráfico excreciones por día
- **Peso histórico**: Tracking peso por gato
- **Estado mantenimiento**: Última limpieza, última bolsa, días desde última arena

#### 4. Scripts útiles
- **Limpieza profunda**: Secuencia: limpiar → deodorizar → calibrar
- **Mantenimiento completo**: Secuencia: cambiar arena → cambiar bolsa → calibrar → test

### Plan de Trabajo

#### Fase 1: Captura de DPs (AHORA)
1. ✅ Añadir logger tuya debug
2. ⏳ Compilar y actualizar firmware
3. ⏳ Ejecutar todas las funciones desde app
4. ⏳ Revisar logs para DPs no mapeados

#### Fase 2: Análisis de Horarios
1. Configurar clean timing en app
2. Capturar DPs tipo RAW/STRING
3. Implementar decodificación si es formato complejo
4. Crear entidades text o datetime según formato

#### Fase 3: Estados y Diagnóstico
1. Mapear DP9 (estado)
2. Mapear DP10 (faults)
3. Crear binary_sensors derivados
4. Crear text_sensors para estados legibles

#### Fase 4: UX y Automations
1. Crear helpers de notificación
2. Implementar automations sugeridas
3. Crear dashboard cards
4. Documentar configuración HA

## Notas Técnicas

### Peso Multi-Gato
Implementación actual usa rangos fijos:
- Simba: 5001-8000g
- Fada: 3500-5000g

**Mejora sugerida**: 
- Usar ML/estadística para identificar automáticamente
- Histograma de pesos para detectar agrupaciones
- Permitir configuración dinámica de rangos

### Sensor Infrarrojo
- DP104 permite desactivar
- Útil si se coloca en jaula/espacio reducido
- Evita falsas detecciones

### Calibración de Peso
- DP118 ejecuta calibración
- Requiere arenero vacío
- Afecta precisión de DP6, DP116

### Batería Auxiliar
- NO parece tener batería según manual
- Diferente del comedero

## Referencias
- Manual: MSP-01A (páginas compartidas)
- Baud rate: 115200 (vs 9600 del comedero)
- Chip: ESP12F (ESP8266)
