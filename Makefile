.PHONY: build

# find all gleam files in src
GLEAM_FILES := $(shell find src -name '*.gleam')

build: build-marker

build-marker: $(GLEAM_FILES)
	gleam export erlang-shipment
	touch build-marker

deploy: build
	rsync -av build/erlang-shipment/ aws:apps/gleam_game

run: deploy
	ssh aws -t "source ~/.zshrc && cd apps/gleam_game && ./entrypoint.sh run"
