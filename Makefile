.PHONY: help check inventory affected validate validate-affected compile compile-affected update update-affected update-all force-update force-update-all dashboard shell disk-usage clean-builds clean-cache clean-logs

CONFIGS ?=
DEVICE ?=
BASE ?= origin/master
HEAD ?= HEAD
COMPOSE := docker compose -f .docker/compose.yaml --project-directory .

help:
	@printf '%s\n' \
		'make version                         Show pinned ESPHome version' \
		'make check                           Check repository conventions' \
		'make inventory                       Show device inventory and fingerprints' \
		'make affected [BASE=ref] [HEAD=ref]  List configs affected by Git changes' \
		'make validate [CONFIGS="a.yaml ..."] Validate configs' \
		'make validate-affected [BASE=ref]    Validate affected configs' \
		'make compile  [CONFIGS="a.yaml ..."] Compile configs' \
		'make compile-affected [BASE=ref]     Compile affected configs' \
		'make update CONFIGS="a.yaml ..."     Always update selected devices' \
		'make update-affected [BASE=ref]      Update affected devices' \
		'make update-all                      Update devices with stale firmware' \
		'make force-update CONFIGS="..."      Alias for make update' \
		'make force-update-all                Always update every device' \
		'make update CONFIGS=a.yaml DEVICE=IP Update one explicit target' \
		'make dashboard                       Start ESPHome dashboard' \
		'make shell                           Open shell in ESPHome container' \
		'make disk-usage                      Show local ESPHome disk usage' \
		'make clean-builds                    Delete ESPHome build cache' \
		'make clean-cache                     Delete builds and Docker tool cache' \
		'make clean-logs                      Delete validation/update logs'

version:
	@./scripts/esphome.sh version

check:
	@$(COMPOSE) run --rm --entrypoint python3 esphome scripts/check_repo.py

inventory:
	@$(COMPOSE) run --rm --entrypoint python3 esphome scripts/inventory.py

affected:
	@./scripts/esphome_update_affected.sh --base "$(BASE)" --head "$(HEAD)" --list-only

validate:
	@./scripts/esphome_validate_all.sh $(CONFIGS)

validate-affected:
	@./scripts/esphome_update_affected.sh --base "$(BASE)" --head "$(HEAD)" --validate-only

compile:
	@./scripts/esphome_update_all.sh --compile-only $(CONFIGS)

compile-affected:
	@./scripts/esphome_update_affected.sh --base "$(BASE)" --head "$(HEAD)" --compile-only

update:
	@./scripts/esphome_update_all.sh $(if $(DEVICE),--device $(DEVICE),) $(CONFIGS)

update-affected:
	@./scripts/esphome_update_affected.sh --base "$(BASE)" --head "$(HEAD)"

update-all:
	@./scripts/esphome_update_all.sh --all --skip-current

force-update:
	@./scripts/esphome_update_all.sh --force $(if $(DEVICE),--device $(DEVICE),) $(CONFIGS)

force-update-all:
	@./scripts/esphome_update_all.sh --all --force

dashboard:
	@$(COMPOSE) run --rm esphome dashboard /config --address 0.0.0.0

shell:
	@$(COMPOSE) run --rm --entrypoint /bin/bash esphome

disk-usage:
	@du -sh .esphome .validate-*-logs .update-*-logs .venv* 2>/dev/null | sort -h || true

clean-builds:
	@$(COMPOSE) run --rm --entrypoint rm esphome -rf /config/.esphome/build

clean-cache: clean-builds
	@$(COMPOSE) down --volumes

clean-logs:
	@find . -maxdepth 1 -type d \( -name '.validate-*-logs' -o -name '.update-*-logs' \) -exec rm -rf {} +
