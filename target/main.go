package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"
)

func main() {
	http.HandleFunc("/log", logHandler)
	http.HandleFunc("/health", healthHandler)

	startup := map[string]string{
		"severity": "INFO",
		"event":    "startup",
		"message":  "target server starting on :8080",
		"time":     time.Now().UTC().Format(time.RFC3339),
	}
	data, _ := json.Marshal(startup)
	fmt.Println(string(data))

	if err := http.ListenAndServe("0.0.0.0:8080", nil); err != nil {
		log.Fatalf(`{"severity":"ERROR","event":"server_failed","error":"%s"}`, err)
	}
}

func logHandler(w http.ResponseWriter, r *http.Request) {
	service := r.URL.Query().Get("service")
	if service == "" {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{
			"error": "missing service parameter",
		})
		return
	}

	entry := map[string]string{
		"severity": "INFO",
		"event":    "request",
		"service":  service,
		"time":     time.Now().UTC().Format(time.RFC3339),
	}
	data, _ := json.Marshal(entry)
	fmt.Println(string(data))

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{
		"status":  "ok",
		"service": service,
	})
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, "OK")
}
