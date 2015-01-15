SHELL := /bin/bash
PATH := $(PATH):node_modules/.bin
PROJECT_NAME := forest_roads

define EXPAND_EXPORTS
export $(word 1, $(subst =, , $(1))) := $(word 2, $(subst =, , $(1)))
endef

# wrap Makefile body with a check for pgexplode
ifeq ($(shell test -f node_modules/.bin/pgexplode; echo $$?), 0)

# load .env
$(foreach a,$(shell cat .env 2> /dev/null),$(eval $(call EXPAND_EXPORTS,$(a))))
# expand PG* environment vars
$(foreach a,$(shell set -a && source .env 2> /dev/null; node_modules/.bin/pgexplode),$(eval $(call EXPAND_EXPORTS,$(a))))

default: project

.env:
	@echo DATABASE_URL=postgres:///usfs > $@

link:
	test -e "${HOME}/Documents/MapBox/project" && \
	test -e "${HOME}/Documents/MapBox/project/$(PROJECT_NAME)" || \
	ln -sf "`pwd`" "${HOME}/Documents/MapBox/project/$(PROJECT_NAME)"

clean:
	@rm -f *.mml *.xml

## Data

data/S_USA.RoadCore_FS.zip:
	mkdir -p $$(dirname $@)
	curl -sLf http://data.fs.usda.gov/geodata/edw/edw_resources/shp/S_USA.RoadCore_FS.zip -o $@

## Database Relations

.PHONY: db/forest_roads

db/forest_roads: data/S_USA.RoadCore_FS.zip db/postgis ogr2ogr
	psql -c "\d $(subst db/,,$@)" > /dev/null 2>&1 || \
	ogr2ogr \
		--config PG_USE_COPY YES \
		-nln $(subst db/,,$@) \
		-t_srs EPSG:3857 \
		-lco ENCODING=LATIN1 \
		-nlt PROMOTE_TO_MULTI \
		-lco POSTGIS_VERSION=2.0 \
		-lco GEOMETRY_NAME=geom \
		-lco SRID=3857 \
		-f PGDump /vsistdout/ \
		/vsizip/$< | psql -q

# Dependencies

.PHONY: carto

carto: node_modules/carto/package.json

.PHONY: interp

interp: node_modules/interp/package.json

.PHONY: js-yaml

js-yaml: node_modules/js-yaml/package.json

.PHONY: ogr2ogr

ogr2ogr:
	@type $@ > /dev/null 2>&1 || (echo "Please install $@" && false)

node_modules/carto/package.json: PKG = $(word 2,$(subst /, ,$@))
node_modules/carto/package.json: node_modules/millstone/package.json
	@type node > /dev/null 2>&1 || (echo "Please install Node.js" && false)
	@echo "Installing $(PKG)"
	@npm install $(PKG)

node_modules/interp/package.json: PKG = $(word 2,$(subst /, ,$@))
node_modules/interp/package.json:
	@type node > /dev/null 2>&1 || (echo "Please install Node.js" && false)
	@echo "Installing $(PKG)"
	@npm install $(PKG)

node_modules/js-yaml/package.json: PKG = $(word 2,$(subst /, ,$@))
node_modules/js-yaml/package.json:
	@type node > /dev/null 2>&1 || (echo "Please install Node.js" && false)
	@echo "Installing $(PKG)"
	@npm install $(PKG)

node_modules/millstone/package.json: PKG = $(word 2,$(subst /, ,$@))
node_modules/millstone/package.json:
	@type node > /dev/null 2>&1 || (echo "Please install Node.js" && false)
	@echo "Installing $(PKG)"
	@npm install $(PKG)

## Generic Targets

%: %.mml
	@cp $< project.mml

.PRECIOUS: %.mml

%.mml: %.yml forest_roads.mss interp js-yaml
	@echo Building $@
	@cat $< | interp | js-yaml > tmp.mml && mv tmp.mml $@

.PRECIOUS: %.xml

%.xml: %.mml carto
	@echo
	@echo Building $@
	@echo
	@carto -l $< > $@ || (rm -f $@; false)


.PHONY: DATABASE_URL

DATABASE_URL:
	@test "${$@}" || (echo "$@ is undefined" && false)

.PHONY: db

db: DATABASE_URL
	@psql -c "SELECT 1" > /dev/null 2>&1 || \
	createdb

.PHONY: db/postgis

db/postgis: db
	$(call create_extension)

define create_extension
@psql -c "\dx $(subst db/,,$@)" | grep $(subst db/,,$@) > /dev/null 2>&1 || \
	psql -v ON_ERROR_STOP=1 -qX1c "CREATE EXTENSION $(subst db/,,$@)"
endef


# complete wrapping
else
.DEFAULT:
	$(error Please install pgexplode: "npm install pgexplode")
endif
