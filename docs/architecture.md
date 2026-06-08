# Estructura del repositorio

## Directorios

- `*.yaml`: configuraciones desplegables. Permanecen en raíz para que ESPHome
  Dashboard y el add-on de Home Assistant las descubran.
- `base_devices/`: definición reutilizable del hardware y sus pines.
- `common/core.yaml`: servicios presentes en todos los dispositivos.
- `common/behaviors/`: comportamientos reutilizables independientes del hardware.
- `common/`: componentes compartidos como WiFi, API, OTA y logging.
- `scripts/`: automatización de validación, compilación y actualización.
- `.docker/`: entorno reproducible local; oculto al Dashboard.
- `docs/`: documentación versionada del repositorio.
- `archive/`: pruebas y configuraciones retiradas; contenido local no versionado.

Cada configuración desplegable debe:

1. Tener el mismo nombre de archivo y `substitutions.device_name`.
2. Incluir exactamente un `base_devices/*.yaml`.
3. Mantener únicamente comportamiento específico del dispositivo.

La separación intencionada es:

- `base_devices/`: qué hardware existe y a qué GPIO está conectado.
- `common/behaviors/`: qué hace ese hardware dentro de un dispositivo.
- YAML de raíz: identidad, área, parámetros y excepciones.

## Decisiones

- Docker fija la versión ESPHome usada para validar y compilar.
- Los dispositivos operativos permanecen en raíz por compatibilidad con
  Home Assistant.
- `secrets.yaml` nunca se versiona. `secrets.yaml.example` documenta sus claves.
- `make update` siempre despliega configuraciones seleccionadas.
- `make update-all` compara versiones antes de actualizar toda la instalación.
