.PHONY: all clean prepare bench-docker bench-gojinn help

# Configuration
REQUESTS=5000
CONCURRENCY=50
OUT_DIR=./bin
RESULTS_DIR=./results
CADDY_BIN=./caddy

help:
	@echo "🧞 Gojinn Benchmarks Suite"
	@echo "--------------------------------"
	@echo "make all          - Run full suite (Docker vs Gojinn)"
	@echo "make bench-docker - Run only Docker benchmark"
	@echo "make bench-gojinn - Run only Gojinn benchmark"
	@echo "make clean        - Remove artifacts"

all: clean prepare bench-docker bench-gojinn

prepare:
	@mkdir -p $(OUT_DIR) $(RESULTS_DIR)
	@echo "🛠️  Compiling Bench Runner..."
	@go build -o $(OUT_DIR)/bench-runner cmd/bench-runner/main.go
	
	@echo "🐳 Building Docker Image (Scenarios)..."
	@cd scenarios/docker && docker build -q -t benchmark-go .
	
	@echo "🤏 Compiling WASM with TinyGo (Dockerized)..."
	@docker run --rm -v $(PWD)/scenarios/wasm:/src -w /src tinygo/tinygo:0.33.0 \
		tinygo build -o tax.wasm -target=wasi -no-debug -panic=trap main.go
	@mv scenarios/wasm/tax.wasm $(OUT_DIR)/tax.wasm

bench-docker:
	@echo "\n🥊 ROUND 1: DOCKER CONTAINER (Native Go)"
	@echo "----------------------------------------"
	@docker run --rm -d -p 8081:8081 --name bench-docker-inst benchmark-go > /dev/null
	@sleep 2
	@$(OUT_DIR)/bench-runner -url http://localhost:8081/api/bench \
		-n $(REQUESTS) -c $(CONCURRENCY) -name Docker
	@mv docker_results.csv $(RESULTS_DIR)/
	@docker stop bench-docker-inst > /dev/null

bench-gojinn:
	@if [ ! -f $(CADDY_BIN) ]; then echo "❌ Caddy binary not found in root!"; exit 1; fi
	@echo "\n🥊 ROUND 2: GOJINN (In-Process Wasm)"
	@echo "----------------------------------------"
	@$(CADDY_BIN) run --config configs/Caddyfile > /dev/null 2>&1 & echo $$! > caddy.pid
	@# Wait for parallel pool provisioning
	@sleep 5 
	@$(OUT_DIR)/bench-runner -url http://localhost:8080/api/bench \
		-n $(REQUESTS) -c $(CONCURRENCY) -name Gojinn
	@mv gojinn_results.csv $(RESULTS_DIR)/
	@kill $$(cat caddy.pid) && rm caddy.pid

clean:
	@rm -rf $(OUT_DIR)/* $(RESULTS_DIR)/* caddy.pid
	@echo "🧹 Cleaned up."

cold-start:
	@chmod +x cold-start.sh
	@./cold-start.sh