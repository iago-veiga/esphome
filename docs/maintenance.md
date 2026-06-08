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
