##
# Test and build minersweeper Project
#
# This Makefile is primarily instructional; you can simply enter the Nix environment for
# holochain development (supplied by holonix;) via `nix-shell` and run
# `make test` directly, or build a target directly, eg. `nix-build -A minersweeper`.
#
SHELL		= bash
DNANAME		= minersweeper
DNA		= $(DNANAME).dna
WASM		= target/wasm32-unknown-unknown/release/mines.wasm

# External targets; Uses a nix-shell environment to obtain Holochain runtimes, run tests, etc.
.PHONY: all FORCE
all: nix-test

# nix-test, nix-install, ...
nix-%:
	nix-shell --pure --run "make $*"

# Internal targets; require a Nix environment in order to be deterministic.
# - Uses the version of `dna-util`, `holochain` on the system PATH.
# - Normally called from within a Nix environment, eg. run `nix-shell`
.PHONY:		rebuild install build build-cargo build-dna
rebuild:	clean build

install:	build

build:	build-cargo build-dna

build:		$(DNA)

# Package the DNA from the built target release WASM
$(DNA):		$(WASM) FORCE
	@echo "Packaging DNA:"
	@hc dna pack . -o ./$(DNANAME).dna
	@hc app pack . -o ./$(DNANAME).happ
	@ls -l $@

# Recompile the target release WASM
$(WASM): FORCE
	@echo "Building  DNA WASM:"
	@RUST_BACKTRACE=1 CARGO_TARGET_DIR=target cargo build \
	    --release --target wasm32-unknown-unknown
	@echo "Optimizing wasms:"
	@wasm-opt -Oz $(WASM) --output $(WASM)

.PHONY: test test-all test-unit test-e2e test-dna test-dna-debug test-stress test-sim2h test-node
test-all:	test

test:		test-unit test-e2e # test-stress # re-enable when Stress tests end reliably

test-unit:
	RUST_BACKTRACE=1 cargo test \
	    -- --nocapture

test-dna:	$(DNA) FORCE
	@echo "Starting Scenario tests in $$(pwd)..."; \
	    cd tests && ( [ -d  node_modules ] || npm install ) && npm test

test-dna-debug:
	@echo "Starting Scenario tests in $$(pwd)..."; \
	    cd tests && ( [ -d  node_modules ] || npm install ) && npm run test-debug

test-e2e:	test-dna

# Spin up agents

gen-agent:
	hc sandbox clean
	hc sandbox generate ./minersweeper.happ -a='minersweeper-1'
	hc sandbox generate ./minersweeper.happ -a='minersweeper-2'

run-agent1:
	hc sandbox r 0 -p=8800

run-agent2:
	hc sandbox r 1 -p=9300

webhapp:
	rm -rf ./build
	npm run build
	rm -f minersweeper.zip
	cd build && rm -rf service-worker.js && zip -r ../minersweeper.zip $$(ls .)
	hc web-app pack .


#############################
# █▀█ █▀▀ █░░ █▀▀ ▄▀█ █▀ █▀▀
# █▀▄ ██▄ █▄▄ ██▄ █▀█ ▄█ ██▄
#############################
# requirements
# - cargo-edit crate: `cargo install cargo-edit`
# - jq linux terminal tool : `sudo apt-get install jq`
# How to make a release?
# make HC_REV="HC_REV" release-0.0.0-alpha0

update:
	echo '⚙️  Updating hdk crate...'
	cargo upgrade hdk@=$(shell jq .hdk ./version-manager.json) --workspace
	echo '⚙️  Updating hc_utils crate...'
	cargo upgrade hc_utils@=$(shell jq .hc_utils ./version-manager.json) --workspace	
	echo '⚙️  Updating holochainVersionId in nix...'
	sed -i -e 's/^  holonixRevision = .*/  holonixRevision = $(shell jq .holonix_rev ./version-manager.json);/' config.nix;\
	sed -i -e 's/^  holochainVersionId = .*/  holochainVersionId = $(shell jq .holochain_rev ./version-manager.json);/' config.nix;\
	echo '⚙️  Building dnas and happ...'
	rm -rf Cargo.lock
	make nix-build
	echo '⚙️  Running tests...'
	make nix-test-dna

# Generic targets; does not require a Nix environment
.PHONY: clean
clean:
	rm -rf \
	    dist \
	    tests/node_modules \
	    .cargo \
	    target \
			Cargo.lock
