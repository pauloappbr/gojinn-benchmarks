.PHONY: all clean prepare bench-docker bench-gojinn bench-rust graphs help

# Configuration
REQUESTS=5000
CONCURRENCY=50
OUT_DIR=./bin
RESULTS_DIR=./results
CADDY_BIN=./caddy

help:
	@echo "🧞 Gojinn Benchmarks Suite"
	@echo "--------------------------------"
	@echo "make all          - Run full suite (Docker vs Gojinn TinyGo vs Rust)"
	@echo "make bench-rust   - Run only Rust benchmark"
	@echo "make cold-start   - Run Cold Start showdown"
	@echo "make graphs       - Generate charts using Docker (Python)"

all: clean prepare bench-docker bench-gojinn bench-rust graphs

prepare:
	@mkdir -p $(OUT_DIR) $(RESULTS_DIR) assets
	@echo "🛠️  Compiling Bench Runner..."
	@go build -o $(OUT_DIR)/bench-runner cmd/bench-runner/main.go
	
	@echo "🐳 Building Docker Image..."
	@cd scenarios/docker && docker build -q -t benchmark-go .
	
	@echo "🤏 Compiling Go WASM (TinyGo)..."
	@docker run --rm -v $(PWD)/scenarios/wasm:/src -w /src tinygo/tinygo:0.33.0 \
		tinygo build -o tax.wasm -target=wasi -no-debug -panic=trap main.go
	@mv scenarios/wasm/tax.wasm $(OUT_DIR)/tax.wasm

	@echo "🦀 Compiling Rust WASM..."
	@docker run --rm -v $(PWD)/scenarios/rust:/src -w /src rust:1.84-slim-bookworm \
		sh -c "rustup target add wasm32-wasip1 && cargo build --release --target wasm32-wasip1"
	@mv scenarios/rust/target/wasm32-wasip1/release/tax-rust.wasm $(OUT_DIR)/rust.wasm

bench-docker:
	@echo "\n🥊 ROUND 1: DOCKER (Native Go)"
	@echo "----------------------------------------"
	@docker run --rm -d -p 8081:8081 --name bench-docker-inst benchmark-go > /dev/null
	@sleep 2
	@$(OUT_DIR)/bench-runner -url http://localhost:8081/api/bench \
		-n $(REQUESTS) -c $(CONCURRENCY) -name Docker
	@mv docker_results.csv $(RESULTS_DIR)/
	@docker stop bench-docker-inst > /dev/null

bench-gojinn:
	@if [ ! -f $(CADDY_BIN) ]; then echo "❌ Caddy binary not found!"; exit 1; fi
	@echo "\n🥊 ROUND 2: GOJINN (TinyGo)"
	@echo "----------------------------------------"
	# Ensures config points to the Go WASM binary
	@sed -i 's|gojinn .* {|gojinn ./bin/tax.wasm {|' configs/Caddyfile
	@$(CADDY_BIN) run --config configs/Caddyfile > /dev/null 2>&1 & echo $$! > caddy.pid
	@sleep 5 # Waits for Worker Pool provisioning
	@$(OUT_DIR)/bench-runner -url http://localhost:8080/api/bench \
		-n $(REQUESTS) -c $(CONCURRENCY) -name Gojinn-TinyGo
	@mv gojinn-tinygo_results.csv $(RESULTS_DIR)/
	@kill $$(cat caddy.pid) && rm caddy.pid

bench-rust:
	@if [ ! -f $(CADDY_BIN) ]; then echo "❌ Caddy binary not found!"; exit 1; fi
	@echo "\n🥊 ROUND 3: GOJINN (Rust)"
	@echo "----------------------------------------"
	# Dynamically updates Caddyfile to use the Rust binary
	@sed -i 's|gojinn .* {|gojinn ./bin/rust.wasm {|' configs/Caddyfile
	@$(CADDY_BIN) run --config configs/Caddyfile > /dev/null 2>&1 & echo $$! > caddy.pid
	@sleep 5 # Waits for Worker Pool provisioning
	@$(OUT_DIR)/bench-runner -url http://localhost:8080/api/bench \
		-n $(REQUESTS) -c $(CONCURRENCY) -name Gojinn-Rust
	@mv gojinn-rust_results.csv $(RESULTS_DIR)/
	@kill $$(cat caddy.pid) && rm caddy.pid

cold-start:
	@chmod +x cold-start.sh
	@./cold-start.sh

graphs:
	@echo "📊 Generating Benchmark Charts..."
	@docker run --rm -v $(PWD):/app -w /app python:3.9-slim \
		sh -c "pip install matplotlib && python scripts/generate_graphs.py"

clean:
	@rm -rf $(OUT_DIR)/* $(RESULTS_DIR)/* caddy.pid scenarios/rust/target
	@echo "🧹 Workspace cleaned."