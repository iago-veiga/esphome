# ESPHome MeuLar

Configuraciones ESPHome y herramientas para validarlas, compilarlas y
actualizar dispositivos desde un entorno Docker reproducible.

## Requisitos

- Docker con `docker compose`
- Acceso a la misma red que los dispositivos para mDNS y OTA
- `secrets.yaml` en la raíz del repositorio

Preparar secretos en un entorno nuevo:

```bash
cp secrets.yaml.example secrets.yaml
chmod 600 secrets.yaml
```

No hace falta instalar Python, PlatformIO ni ESPHome en el host. La versión
queda fijada en `.docker/compose.yaml`; puede sobrescribirse temporalmente:

```bash
ESPHOME_VERSION=2026.4.0 make version
```

## Uso habitual

```bash
make version
make check
make inventory
make status
make affected BASE=origin/master
make validate
make validate-affected BASE=origin/master
make compile CONFIGS="luz-principal-salon.yaml"
make compile-affected BASE=origin/master
make update CONFIGS="luz-principal-salon.yaml"
make update-affected BASE=origin/master
make update-all
make force-update-all
make update CONFIGS="luz-principal-salon.yaml" DEVICE=192.168.10.50
./scripts/device_builder_refresh.sh --base origin/master
make dashboard
```

Sin `CONFIGS`, `validate` y `compile` procesan todos los YAML de dispositivo.
`update` exige seleccionar configuraciones; `update-all` procesa todas.

El archivo Compose vive en `.docker/compose.yaml`, fuera de la raíz, para que
ESPHome Dashboard y el add-on de Home Assistant no lo detecten como dispositivo.

También puede ejecutarse cualquier comando ESPHome:

```bash
./scripts/esphome.sh config luz-principal-salon.yaml
./scripts/esphome.sh logs luz-principal-salon.yaml
```

`make dashboard` sirve la interfaz en <http://localhost:6052>.

## Actualizaciones

`make update CONFIGS="..."` compila y actualiza siempre los dispositivos
seleccionados. Esto garantiza que los cambios de configuración se desplieguen
aunque no cambie la versión ESPHome.

`make update-all` consulta primero la versión y el `config-hash` nativo anunciados
por cada dispositivo mediante mDNS, con la API cifrada como respaldo:

- Si coinciden la versión ESPHome y la huella esperada, omite el dispositivo.
- Si cualquiera es distinta, compila y actualiza por OTA.
- Si no puede consultar la versión, intenta actualizar igualmente y guarda el
  error de consulta en el directorio de logs.
- `make force-update CONFIGS="..."` se mantiene como alias de `make update`.
- `make force-update-all` actualiza todos los dispositivos sin comparar versión.
- `DEVICE=<IP|hostname|puerto serie>` fija destino explícito y exige un único
  YAML para evitar cargar firmware en el dispositivo equivocado.
- Los destinos serie (`/dev/...`) omiten la consulta API.

La consulta usa `esphome_api_encryption_key` de `secrets.yaml`. El destino se
obtiene de `inventory/devices.yaml`; por defecto es `<device_name>.local`.

El hash usado es el oficial de ESPHome: FNV-1a de la configuración ya resuelta,
incluidos `!include`, sustituciones y secretos. Por eso requiere la misma versión
de ESPHome y el mismo `secrets.yaml` en todos los entornos, pero no depende de la
ruta del checkout. `make status` compara ese valor con el TXT mDNS desplegado sin
compilar ni actualizar ningún dispositivo.

En el nuevo Device Builder, `Local` procede del `build_info.json` generado por el
último `compile` o `compile --only-generate` ejecutado en ese entorno. Una
sincronización Git externa no actualiza necesariamente ese artefacto, por lo que
el panel puede mostrar temporalmente un hash local antiguo. Tras generar o
instalar desde ese dashboard, compara exactamente el mismo hash nativo.

`scripts/device_builder_refresh.sh` automatiza ese refresco dentro del add-on de
Home Assistant ejecutando `esphome compile --only-generate` para los YAML
seleccionados. Puede recibir configs explícitos, `--all` o `--base/--head` para
regenerar solo los dispositivos afectados por un rango Git.

`config_fingerprint.py` conserva una huella SHA-256 del contenido versionado para
analizar dependencias e inventario, pero ya no se inyecta en el firmware ni se
usa para decidir actualizaciones.

## Cambios selectivos

El repositorio calcula qué dispositivos dependen de los archivos modificados:

```bash
make affected BASE=origin/master HEAD=HEAD
make validate-affected BASE=origin/master
make compile-affected BASE=origin/master
make update-affected BASE=origin/master
```

Un cambio en un YAML raíz afecta solo a ese dispositivo; un cambio en una base
o fichero común afecta a todos los dispositivos que lo incluyen.

Los logs se guardan en:

- `.validate-<version>-logs/`
- `.update-<version>-logs/<fecha-hora>/`

## Scripts

- `scripts/esphome.sh`: ejecuta CLI de ESPHome dentro de Docker.
- `scripts/esphome_validate_all.sh [yaml ...]`: valida uno o todos los YAML.
- `scripts/esphome_update_all.sh [opciones] [yaml ...]`: compila o actualiza.
- `scripts/esphome_update_affected.sh`: procesa dispositivos afectados por Git.
- `scripts/device_info.py`: consulta metadatos por mDNS, con respaldo por API.
- `scripts/device_builder_refresh.sh`: regenera el `build_info.json` del add-on.
- `scripts/config_fingerprint.py`: calcula la huella del contenido YAML versionado.
- `scripts/affected_configs.py`: resuelve dispositivos afectados por cambios Git.
- `scripts/inventory.py`: muestra el inventario operativo.

Opciones de actualización:

```text
--compile-only       Compila sin contactar dispositivos
--status             Compara configuración y firmware sin actualizar
--all                Procesa todos los dispositivos
--device ADDRESS     Destino explícito; requiere un único YAML
--skip-current       Omite dispositivos con la versión ESPHome objetivo
--force              Alias compatible para actualizar siempre
```

Los scripts se autoejecutan dentro de Docker. Para compatibilidad y ajustes
avanzados, aceptan `MODE=compile-only`, `SKIP_CURRENT=1`, `DEVICE=...`,
`LOGROOT=...` y `VERSION_CHECK_TIMEOUT=8` (segundos).

## Mantenimiento

```bash
make disk-usage
make clean-builds
make clean-cache
make clean-logs
```

Más información:

- [Estructura y decisiones](docs/architecture.md)
- [Operación y mantenimiento](docs/maintenance.md)
- [Mejoras pendientes](docs/backlog.md)

GitHub Actions ejecuta `make check` y `make validate` en cada push y pull
request usando `secrets.yaml.example`.

## Cambiar versión de ESPHome

1. Validar con versión nueva sin editar archivos:

   ```bash
   ESPHOME_VERSION=2026.4.0 make validate
   ```

2. Cambiar versión por defecto en `.docker/compose.yaml`.
3. Ejecutar `make validate`, después `make update-all`.

`network_mode: host` es intencionado: permite resolución mDNS y actualizaciones
OTA desde contenedor. Para carga inicial por USB, usar un destino serie y
exponer dispositivo al contenedor mediante un override local de Compose.
