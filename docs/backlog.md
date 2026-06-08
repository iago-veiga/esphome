# Mejoras pendientes

Cambios detectados durante la revisión que no se aplican automáticamente porque
pueden alterar comportamiento desplegado.

## Servidor web

`common/core.yaml` incluye `web_server` en todos los dispositivos. Conviene
evaluar hacerlo opcional para reducir consumo de memoria y superficie de ataque.
Antes de retirarlo hay que confirmar qué dispositivos dependen de carga OTA o
diagnóstico por web.

## Perfiles y componentes sin uso

Actualmente no están referenciados por configuraciones desplegables:

- `base_devices/esp32s3.yaml`
- `base_devices/led-eglo.yaml`
- `base_devices/sonoffminir4.yaml`
- `base_devices/tecking-sp22.yaml`
- `common/binary_sensor/status.yaml`
- `common/sensor/uptime.yaml`
- `common/switch/debug_mode.yaml`
- `common/text_sensor/version.yaml`
- `common/time/homeassitant.yaml`

Revisar antes de mover a `archive/`; pueden servir como inventario de hardware
temporalmente desconectado.

## GPIO

- `rack-cpd.yaml` genera warning porque GPIO5 es strapping pin. Confirmar que el
  uso del LED es correcto y documentar `ignore_strapping_warning` si procede.
- `base_devices/sonoffmini.yaml` declara GPIO0 como salida `button_1`, aunque
  ninguna configuración actual lo usa. Confirmar hardware antes de eliminarlo.
