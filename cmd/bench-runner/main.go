package main

import (
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"sort"
	"strings"
	"sync"
	"text/tabwriter"
	"time"
)

func main() {
	url := flag.String("url", "http://localhost:8080/api/bench", "Target URL")
	requests := flag.Int("n", 1000, "Number of requests")
	concurrency := flag.Int("c", 10, "Concurrency level")
	name := flag.String("name", "Unknown", "Test Name (e.g., Docker, Gojinn)")
	flag.Parse()

	fmt.Printf("🔥 Starting Benchmark: %s\n", *name)
	fmt.Printf("   URL: %s | Reqs: %d | Concurrency: %d\n\n", *url, *requests, *concurrency)

	start := time.Now()
	results := make(chan time.Duration, *requests)
	var wg sync.WaitGroup

	// Worker Pool
	jobs := make(chan int, *requests)
	for i := 0; i < *concurrency; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			client := &http.Client{Timeout: 10 * time.Second}
			payload := strings.NewReader(`{"id":"1", "value":100}`)

			for range jobs {
				reqStart := time.Now()
				resp, err := client.Post(*url, "application/json", payload)
				if err != nil {
					fmt.Printf("Error: %v\n", err)
					continue
				}
				io.Copy(io.Discard, resp.Body)
				resp.Body.Close()
				results <- time.Since(reqStart)
			}
		}()
	}

	for i := 0; i < *requests; i++ {
		jobs <- i
	}
	close(jobs)
	wg.Wait()
	close(results)
	totalTime := time.Since(start)

	// Calculate Stats
	var latencies []float64
	for d := range results {
		latencies = append(latencies, float64(d.Microseconds()))
	}
	sort.Float64s(latencies)

	if len(latencies) == 0 {
		fmt.Println("No successful requests.")
		return
	}

	min := latencies[0]
	max := latencies[len(latencies)-1]
	avg := sum(latencies) / float64(len(latencies))
	p50 := latencies[int(float64(len(latencies))*0.50)]
	p95 := latencies[int(float64(len(latencies))*0.95)]
	p99 := latencies[int(float64(len(latencies))*0.99)]

	// Print Table
	w := tabwriter.NewWriter(os.Stdout, 0, 0, 3, ' ', tabwriter.AlignRight|tabwriter.Debug)
	fmt.Fprintln(w, "Metric\tValue (µs)\tValue (ms)")
	fmt.Fprintf(w, "Total Time\t-\t%.2fs\n", totalTime.Seconds())
	fmt.Fprintf(w, "Requests/sec\t-\t%.2f\n", float64(*requests)/totalTime.Seconds())
	fmt.Fprintf(w, "Min\t%.2f µs\t%.3f ms\n", min, min/1000)
	fmt.Fprintf(w, "Average\t%.2f µs\t%.3f ms\n", avg, avg/1000)
	fmt.Fprintf(w, "P50 (Median)\t%.2f µs\t%.3f ms\n", p50, p50/1000)
	fmt.Fprintf(w, "P95\t%.2f µs\t%.3f ms\n", p95, p95/1000)
	fmt.Fprintf(w, "P99\t%.2f µs\t%.3f ms\n", p99, p99/1000)
	fmt.Fprintf(w, "Max\t%.2f µs\t%.3f ms\n", max, max/1000)
	w.Flush()

	// Save CSV for graphing
	saveCSV(*name, latencies)
}

func sum(nums []float64) float64 {
	total := 0.0
	for _, x := range nums {
		total += x
	}
	return total
}

func saveCSV(name string, latencies []float64) {
	f, _ := os.Create(fmt.Sprintf("%s_results.csv", strings.ToLower(name)))
	defer f.Close()
	f.WriteString("request_id,latency_us\n")
	for i, l := range latencies {
		f.WriteString(fmt.Sprintf("%d,%.2f\n", i+1, l))
	}
	fmt.Printf("\n💾 Data saved to %s_results.csv\n", strings.ToLower(name))
}
