# Análisis del Arenero Automático (MSP-01A)

## Estado Actual de Implementación

### DPs Mapeados (Confirmados)

#### Controles Principales
- **DP3**: `start` - Botón limpiar (manual)
- **DP4**: `auto_clean` - Limpieza automática ON/OFF
- **DP17**: `deodorization` - Deodorización ON/OFF
- **DP111**: `replace_litter` - Cambiar arena (mantener REPLACE 2s)
- **DP117**: `replace_bag` - Cambiar bolsa (mantener CLEAN 2s)

#### Configuración
- **DP5**: `delay_clean_time` - Tiempo para comenzar limpieza (0-60 min)
- **DP103**: `child_lock` - Bloqueo infantil (AUTO + REMOVE ODOR 3s)
- **DP104**: `infrared` - Sensor infrarrojo ON/OFF
- **DP105**: `cleaning_interval` - Intervalo entre limpiezas (0-120 min)
- **DP106**: `panel_light` - Luz del panel (invertido)
- **DP113**: `mode` - Modo operacional (0=normal)
- **DP114**: `full_bag_threshold` - Umbral bolsa llena (0-15)
- **DP115**: `initialize_litter_box` - Inicializar/calibrar arenero (boot)
- **DP118**: `calibrate_weight` - Calibrar peso/nivelar (mantener REMOVE ODOR 2s)

#### Sensores de Uso
- **DP6**: `cat_weight` - Peso del gato (g)
- **DP7**: `excretion_times_day` - Excreciones del día (contador)
- **DP8**: `excretion_time` - Tiempo última excreción (s)

#### Sensores Ambientales
- **DP101**: `temperature` - Temperatura (°C)
- **DP102**: `humidity` - Humedad (%)

#### Otros Sensores
- **DP116**: `real_time_weight` - Peso en tiempo real (g)

#### ✅ DP21: Bitmask de Estados (COMPLETAMENTE MAPEADO)

| Bit | Hex | Estado | Trigger |
|-----|-----|--------|---------|
| 6 | 0x000040 | Limpieza automática (gato) | Auto-clean después de gato |
| 8 | 0x000100 | Limpieza manual | Botón CLEAN |
| 10 | 0x000400 | Cambiando arena | Mantener REPLACE 2s |
| 12 | 0x001000 | Desodorización activa | DP17 ON |
| 13 | 0x002000 | Post-desodorización | DP17 OFF (finalizado) |
| 18 | 0x040000 | Cambiando bolsa | Mantener CLEAN 2s (DP117 ON) |
| 20 | 0x100000 | Calibrando/Nivelando | DP118 ON |
| 21 | 0x200000 | Post-calibración | DP118 OFF (finalizado) |

### DPs Pendientes de Análisis

#### DPs Descubiertos Pero No Activados
- **DP1, DP2**: RAW - No aparecen en logs (probablemente horarios/schedules)
- **DP9**: enum - No aparece (posiblemente estado general)
- **DP10**: enum - No aparece (posiblemente faults/errores)
- **DP22**: bitmask - No identificado (¿flags de configuración?)
- **DP24**: enum (valor 255 al boot) - No cambia
- **DP109**: int (valor: 10) - No identificado
- **DP110**: int (valor: 3) - No identificado
- **DP112**: bool - No identificado
- **DP119**: bool - No identificado

### Binary Sensors Implementados

✅ **Estado Operacional** (basados en DP21):
- `Limpiando`: bits 6+8 de DP21
- `Desodorizando`: bit 12 de DP21
- `Cambiando arena`: bit 10 de DP21
- `Cambiando bolsa`: bit 18 de DP21
- `Calibrando`: bit 20 de DP21
- `Gato dentro`: peso tiempo real > 500g

✅ **Diagnóstico**:
- `Bolsa llena`: por implementar lógica DP114 threshold

### Funcionalidades del Manual No Implementadas

#### 1. Horarios Programados (Clean Timing)
**Funcionalidad**: Configurar hasta 5 horarios diarios para limpieza automática
- Probablemente DP1 o DP2 (formato RAW)
- Similar a DP1 del comedero
- **Estado**: Sin app, no podemos configurar para capturar tráfico

#### 2. Horarios de Deodorización (Deodo Timing)
**Funcionalidad**: Programar cuándo activar deodorización
- Posiblemente DP1 o DP2
- **Estado**: Sin app, no podemos configurar

#### 3. Modo No Molestar (Do Not Disturb Timing)
**Funcionalidad**: Horario en el que no se ejecutan operaciones
- Configuración de rango horario (inicio-fin)
- Posiblemente parte de DP1/DP2
- **Estado**: Sin app, no podemos configurar
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
