# ⚡ Gojinn Benchmarks

> **Reproducible Performance Suite for In-Process Serverless**

This repository contains the official benchmarking suite comparing **Gojinn (WebAssembly on Caddy)** against traditional **Docker** containerization.

The goal is to provide a transparent, reproducible environment to verify the claims of **microsecond latency**, **high density**, and **polyglot support**.

## 🏗 Architecture

The suite uses a custom Go runner (`cmd/bench-runner`) that performs high-concurrency HTTP load testing.

| Scenario | Technology | Description |
| :--- | :--- | :--- |
| **Challenger** | **Docker** (Alpine/Go) | A standard Go HTTP server running inside a container (Native execution). |
| **Defender A** | **Gojinn** (TinyGo) | Go logic compiled to Wasm via TinyGo (Managed Memory / GC). |
| **Defender B** | **Gojinn** (Rust) | Rust logic compiled to Wasm (Manual Memory / Zero Runtime). |

## 🚀 Key Results (v0.3.0)

Tests performed on standard hardware (12 vCPU).

### 1. Throughput & Latency (Warm State)
*Both services running and ready to accept traffic.*

| Metric | Docker (Native) | Gojinn (TinyGo) | Gojinn (Rust) | Analysis |
| :--- | :--- | :--- | :--- | :--- |
| **Throughput** | ~14,500 req/s | ~5,300 req/s | **~6,200 req/s** | Rust extracts +20% performance over TinyGo. |
| **Latency (Min)** | 0.13 ms | 1.17 ms | **0.44 ms** | **Rust breaks the sub-ms barrier.** |
| **Latency (P99)** | ~12 ms | ~39 ms | **~30 ms** | Rust is more stable (No GC pauses). |
| **Artifact Size** | 20.6 MB | 288 KB | **180 KB** | **🏆 Gojinn is ~100x smaller.** |

### 2. The "Cold Start" Showdown
*Starting the service from zero for each request loop.*

| Metric | Docker | Gojinn (Any Lang) | Improvement |
| :--- | :--- | :--- | :--- |
| **Worst Case (First Run)** | 2,811 ms | **176 ms** | **15x Faster** |
| **Average Cold Start** | 730 ms | **163 ms** | **4.5x Faster** |

> **Note:** Gojinn's Cold Start is consistent regardless of the guest language (Go or Rust), as the overhead comes from the Host initialization, not the Wasm module instantiation (< 2ms).

---

## ⚖️ Analysis & Trade-offs

The benchmarks provide a clear picture of the trade-offs between Native Containers and In-Process Wasm.

### 1. The Language Factor (Go vs Rust)
This suite proves that the **Gojinn Engine** overhead is negligible (< 0.2ms). The final performance depends heavily on the Guest Language:
* **TinyGo:** Excellent for productivity, but pays a tax (~0.7ms) for Garbage Collection and Runtime.
* **Rust:** The choice for raw performance. By managing memory manually, Rust achieves **0.44ms latency**, approaching native speeds while maintaining full sandbox isolation.

### 2. The "Scale to Zero" Reality
* **Docker:** Heavyweight (~1.5s boot). Not viable for synchronous serverless functions that scale to zero per-request.
* **Gojinn:** Instant (~2ms internal instantiation). Perfect for high-density edge computing, plugins, and webhooks.

### 3. Density & Cost
* **Docker:** Requires a dedicated OS process and memory (~20MB) even when idle. A typical node can run ~50 containers before exhaustion.
* **Gojinn:** Idle functions are just bytes on disk. You can configure **thousands of functions** on a single $5 VPS, consuming zero RAM until they are actually called.

---

## 🛠️ How to Run

### Prerequisites

* **Go 1.23+** installed.
* **Docker** running (used to compile Wasm targets deterministically).
* **Make** (build automation).
* **Caddy (Gojinn Edition)**: Compiled `caddy` binary with the plugin in the root.

### 1. Build & Run All Benchmarks

This command compiles the Runner, builds the Docker image, compiles Wasm targets (TinyGo & Rust), and runs the load tests.

```bash
make all
```

### 2. Run Individual Benchmarks

```bash
make bench-docker   # Run Native Go
make bench-gojinn   # Run TinyGo Wasm
make bench-rust     # Run Rust Wasm
```

### 3. Run Cold Start Test

```bash
make cold-start
```

## 📂 Project Structure

Follows standard Go layout:

```
.
├── cmd/             # Benchmark Runner CLI source
├── configs/         # Caddyfile configurations
├── scenarios/
│   ├── docker/      # Native Go target source
│   ├── wasm/        # TinyGo target source
│   └── rust/        # Rust target source (The Speed King)
├── bin/             # Compiled artifacts (Ignored)
├── results/         # Output CSV data (Ignored)
├── cold-start.sh    # Cold Start script
├── Makefile         # Automation scripts
└── README.md        # This file
```