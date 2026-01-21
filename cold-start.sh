#!/bin/bash

echo "❄️  COLD START SHOWDOWN: Docker vs Gojinn"
echo "----------------------------------------"

echo -e "\n🥊 ROUND 1: DOCKER (Start Container -> Process -> Stop)"
echo "Measuring time to serve ONE request from zero..."

total_docker=0
for i in {1..5}; do
    echo -n "Run #$i: "
    
    start_time=$(date +%s%N)
    
    cid=$(docker run --rm -d -p 8081:8081 benchmark-go 2>/dev/null)
    
    while ! curl -s http://localhost:8081/api/bench > /dev/null; do
        sleep 0.05
    done
    
    end_time=$(date +%s%N)
    
    docker stop $cid > /dev/null
    
    duration=$(( ($end_time - $start_time) / 1000000 ))
    echo "${duration} ms"
    total_docker=$((total_docker + duration))
done

avg_docker=$((total_docker / 5))
echo "👉 Docker Average Cold Start: ${avg_docker} ms"


# --- GOJINN COLD START ---
echo -e "\n🥊 ROUND 2: GOJINN (Caddy Start -> Provision -> Process)"

total_gojinn=0
for i in {1..5}; do
    echo -n "Run #$i: "
    
    start_time=$(date +%s%N)
    
    ./caddy run --config configs/Caddyfile.cold > /dev/null 2>&1 &
    pid=$!
    
    while ! curl -s http://localhost:8080/api/bench > /dev/null; do
        sleep 0.01
    done
    
    end_time=$(date +%s%N)
    
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