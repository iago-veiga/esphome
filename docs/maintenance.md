# Mantenimiento

## Flujo recomendado

Después de editar uno o varios dispositivos:

```bash
make check
make validate CONFIGS="dispositivo.yaml"
make update CONFIGS="dispositivo.yaml"
```

Después de cambiar la versión ESPHome fijada:

```bash
make validate
make update-all
```

Para recompilar y actualizar todos los dispositivos aunque ya ejecuten la
versión objetivo:

```bash
make force-update-all
```

## Espacio en disco

Los builds ESPHome pueden ocupar varios gigabytes:

```bash
make disk-usage
make clean-builds
make clean-cache
make clean-logs
```

`clean-builds` elimina los firmwares generados y obliga a recompilar desde cero
la próxima vez, pero conserva toolchains y dependencias. `clean-logs` elimina
únicamente logs locales de validación y actualización.

La caché de PlatformIO se conserva en el volumen Docker `platformio` para no
descargar toolchains en cada compilación. `make clean-cache` elimina también
ese volumen; la siguiente compilación volverá a descargar las herramientas.
Las rutas de PlatformIO están fijadas en Compose para que también usen el
volumen los scripts ejecutados mediante una shell dentro del contenedor.
El volumen `platformio_core` conserva además el entorno Python interno que
pioarduino genera durante las compilaciones ESP32.

## Incorporar un dispositivo

1. Copiar `secrets.yaml.example` a `secrets.yaml` si el entorno aún no lo tiene.
2. Crear un YAML en raíz cuyo nombre coincida con `device_name`.
3. Reutilizar un hardware de `base_devices/` o crear uno nuevo.
4. Ejecutar `make validate CONFIGS="nuevo-dispositivo.yaml"`.
5. Realizar primera carga y después usar OTA mediante `make update`.

## Sincronización con Home Assistant

El checkout utilizado por ESPHome Device Builder puede mantenerse actualizado
ejecutando periódicamente:

```bash
./scripts/sync_home_assistant.sh
```

El script está pensado para `/root/config/esphome`, usa `master` por defecto y
solo acepta actualizaciones fast-forward. Se detiene sin modificar archivos si
la rama activa no es la esperada, existen cambios locales versionados o el
historial ha divergido.

El servidor debe usar una deploy key de GitHub de solo lectura. En Advanced SSH
& Web Terminal puede programarse cada cinco minutos con un `init_command` que
añada esta entrada al crontab:

```cron
*/5 * * * * cd /root/config/esphome && ./scripts/sync_home_assistant.sh >> /root/config/esphome/.sync-home-assistant.log 2>&1
```

La sincronización actualiza los YAML visibles por ESPHome Device Builder, pero
no compila ni instala firmware automáticamente.
