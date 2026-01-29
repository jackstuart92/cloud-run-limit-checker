package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"time"
)

var (
	targetURL   string
	serviceName string
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	targetURL = os.Getenv("TARGET_URL")
	if targetURL == "" {
		log.Fatal("TARGET_URL environment variable is required")
	}

	serviceName = os.Getenv("SERVICE_NAME")
	if serviceName == "" {
		log.Fatal("SERVICE_NAME environment variable is required")
	}

	http.HandleFunc("/ping", pingHandler)
	http.HandleFunc("/health", healthHandler)

	addr := ":" + port
	log.Printf(`{"message":"starting server","port":"%s","service":"%s"}`, port, serviceName)
	if err := http.ListenAndServe(addr, nil); err != nil {
		log.Fatalf(`{"message":"server failed","error":"%s"}`, err)
	}
}

func pingHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	url := targetURL + "?service=" + serviceName

	client := &http.Client{Timeout: 20 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadGateway)
		body := map[string]string{
			"error":   err.Error(),
			"service": serviceName,
		}
		json.NewEncoder(w).Encode(body)
		logJSON("ping_failed", err.Error())
		return
	}
	defer resp.Body.Close()

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadGateway)
		body := map[string]string{
			"error":   fmt.Sprintf("failed to read response body: %s", err),
			"service": serviceName,
		}
		json.NewEncoder(w).Encode(body)
		logJSON("ping_read_failed", err.Error())
		return
	}

	logJSON("ping_success", fmt.Sprintf("status=%d bytes=%d", resp.StatusCode, len(data)))

	w.WriteHeader(http.StatusOK)
	w.Write(data)
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, "OK")
}

func logJSON(event, detail string) {
	entry := map[string]string{
		"severity": "INFO",
		"service":  serviceName,
		"event":    event,
		"detail":   detail,
		"time":     time.Now().UTC().Format(time.RFC3339),
	}
	data, _ := json.Marshal(entry)
	fmt.Println(string(data))
}
