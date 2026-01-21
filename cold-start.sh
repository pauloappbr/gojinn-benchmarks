#!/bin/bash

echo "❄️  COLD START SHOWDOWN: Docker vs Gojinn"
echo "----------------------------------------"

# --- DOCKER COLD START ---
echo -e "\n🥊 ROUND 1: DOCKER (Start Container -> Process -> Stop)"
echo "Measuring time to serve ONE request from zero..."

total_docker=0
for i in {1..5}; do
    echo -n "Run #$i: "
    
    # Captura o timestamp antes
    start_time=$(date +%s%N)
    
    # 1. Inicia Container em background
    cid=$(docker run --rm -d -p 8081:8081 benchmark-go 2>/dev/null)
    
    # 2. Polling: Tenta conectar até o container estar vivo
    while ! curl -s http://localhost:8081/api/bench > /dev/null; do
        sleep 0.05
    done
    
    # Captura o timestamp depois
    end_time=$(date +%s%N)
    
    # Mata o container
    docker stop $cid > /dev/null
    
    # Calcula duração em ms
    duration=$(( ($end_time - $start_time) / 1000000 ))
    echo "${duration} ms"
    total_docker=$((total_docker + duration))
done

avg_docker=$((total_docker / 5))
echo "👉 Docker Average Cold Start: ${avg_docker} ms"


# --- GOJINN COLD START ---
echo -e "\n🥊 ROUND 2: GOJINN (Caddy Start -> Provision -> Process)"
# Para ser justo, vamos medir o tempo de BOOT do Caddy + Request
# Embora na prática o Gojinn seja "Always On", vamos simular um restart do servidor.

total_gojinn=0
for i in {1..5}; do
    echo -n "Run #$i: "
    
    start_time=$(date +%s%N)
    
    # 1. Inicia Caddy em background
    ./caddy run --config configs/Caddyfile.cold > /dev/null 2>&1 &
    pid=$!
    
    # 2. Polling: Tenta conectar (Isso inclui o tempo de JIT Compilation do Gojinn)
    while ! curl -s http://localhost:8080/api/bench > /dev/null; do
        sleep 0.01
    done
    
    end_time=$(date +%s%N)
    
    # Mata o Caddy
    kill $pid > /dev/null 2>&1
    wait $pid 2>/dev/null
    
    duration=$(( ($end_time - $start_time) / 1000000 ))
    echo "${duration} ms"
    total_gojinn=$((total_gojinn + duration))
done

avg_gojinn=$((total_gojinn / 5))
echo "👉 Gojinn Average Cold Start: ${avg_gojinn} ms"

echo -e "\n========================================"
echo "🏆 WINNER: $(if [ $avg_gojinn -lt $avg_docker ]; then echo "GOJINN"; else echo "DOCKER"; fi)"
echo "Speedup Factor: $((avg_docker / avg_gojinn))x faster"
echo "========================================"