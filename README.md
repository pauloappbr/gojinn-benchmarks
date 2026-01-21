# ⚡ Gojinn Benchmarks

> **Reproducible Performance Suite for In-Process Serverless**

This repository contains the official benchmarking suite comparing **Gojinn (WebAssembly on Caddy)** against traditional **Docker** containerization.

The goal is to provide a transparent, reproducible environment to verify the performance characteristics of the **v0.3.0 JIT Engine**.

## 🏗 Architecture

The suite uses a custom Go runner (`cmd/bench-runner`) that performs high-concurrency HTTP load testing and calculates P99 latency distribution.

| Scenario | Technology | Description |
| :--- | :--- | :--- |
| **Challenger** | **Docker** (Alpine/Go) | A standard Go HTTP server running inside a container, exposed via port forwarding (Native execution). |
| **Defender** | **Gojinn** (TinyGo/Wasm) | The same Go logic compiled to Wasm (via TinyGo) running inside Caddy's process memory (Virtual Machine). |

## 🚀 Key Results (v0.3.0)

Tests performed on standard hardware (12 vCPU).

### 1. Throughput & Latency (Warm State)
*Both services running and ready to accept traffic.*

| Metric | Docker (Native) | Gojinn (Wasm) | Analysis |
| :--- | :--- | :--- | :--- |
| **Throughput** | ~14,500 req/s | ~5,300 req/s | Docker wins on raw CPU throughput. |
| **Latency (P99)** | ~12 ms | ~39 ms | Wasm overhead is present but stable. |
| **Artifact Size** | 20.6 MB | **288 KB** | **🏆 Gojinn is 70x smaller.** |

### 2. The "Cold Start" Showdown
*Starting the service from zero for each request loop.*

| Metric | Docker | Gojinn | Improvement |
| :--- | :--- | :--- | :--- |
| **Worst Case (First Run)** | 2,811 ms | **176 ms** | **15x Faster** |
| **Average Cold Start** | 730 ms | **163 ms** | **4.5x Faster** |

> **Note:** The Gojinn Cold Start time includes the entire boot process of the Caddy Web Server + JIT Compilation. The internal Wasm instantiation time is **< 2ms**.

---

## ⚖️ Analysis & Trade-offs

The benchmarks show that Native Go (Docker) is faster than WebAssembly in raw execution. This is expected, as Wasm adds a layer of abstraction (Virtual Machine and Sandbox).

However, raw speed is not the only metric for Serverless architectures.

### 1. The "Scale to Zero" Reality
In the "Cold Start" benchmark, we simulated a scaling event (starting the process from scratch).
* **Docker:** Fluctuates heavily. The first request took **2.8 seconds** to allocate kernel namespaces and network.
* **Gojinn:** Consistent. It took **0.16 seconds** to boot the server and serve traffic.
* **Verdict:** Gojinn provides a significantly better user experience for ephemeral, rarely-used functions.

### 2. Density & Cost
* **Docker:** Requires a dedicated OS process and memory (~20MB) even when idle. A typical node can run ~50 containers before exhaustion.
* **Gojinn:** Idle functions are just bytes on disk. You can configure **thousands of functions** on a single $5 VPS, consuming zero RAM until they are actually called.

### 3. Security (The Sandbox)
* **Docker:** Relies on Linux Namespaces. A compromised process can potentially attack the kernel or network.
* **Gojinn:** Uses [Wazero](https://wazero.io) to guarantee strict memory isolation. The code cannot access files, env vars, or sockets unless explicitly allowed.

---

## 🛠️ How to Run

### Prerequisites

* **Go 1.23+** installed.
* **Docker** running.
* **Make** (build automation).
* **Caddy (Gojinn Edition)**: Compiled `caddy` binary with the plugin in the root.

### 1. Build & Run Load Test (Warm)

```bash
make all
```

### 2. Run Cold Start Test

```bash
make cold-start
```

## 🤏 Why TinyGo?
Gojinn v0.3.0 is optimized for TinyGo.

Standard Go compiles to large binaries (~2MB) because it includes a heavy runtime (GC, Scheduler). This causes overhead when instantiating thousands of sandboxes per second.

TinyGo strips away the fat, generating Wasm binaries of ~200KB. This allows Gojinn's Worker Pool to instantiate sandboxes in microseconds, unlocking the true potential of In-Process Serverless.

## 📂 Project Structure

Follows standard Go layout:

```
.
├── cmd/
│   └── bench-runner/        # Benchmark Runner CLI source
├── configs/
│   └── Caddyfile            # Caddy configuration
├── scenarios/
│   ├── docker/              # Docker target source code
│   └── wasm/                # Wasm target source code
├── bin/                     # Compiled artifacts (Ignored)
├── results/                 # Output CSV data (Ignored)
├── cold-start.sh            # Cold Start Benchmark
├── go.mod                   # Go module definition
├── Makefile                 # Build automation scripts
└── README.md                # This file
```

---