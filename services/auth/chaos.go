package main

import (
	"encoding/json"
	"log"
	"net/http"
)

// Injeção de falha usada na demonstração de Self-Healing.
// O estado fica só em memória: um "kubectl rollout restart" cria um Pod novo
// e o serviço volta ao normal. O /health continua respondendo 200, então o
// kubelet não reinicia o Pod sozinho — a recuperação depende do alerta.

// chaosHandler liga (POST) ou desliga (DELETE) a falha e informa o estado (GET)
func (a *App) chaosHandler(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodPost:
		a.Failing.Store(true)
		log.Println("CHAOS: falha injetada, /validate passa a responder HTTP 500")
	case http.MethodDelete:
		a.Failing.Store(false)
		log.Println("CHAOS: falha removida manualmente")
	case http.MethodGet:
	default:
		http.Error(w, "Método não permitido", http.StatusMethodNotAllowed)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(map[string]bool{"failing": a.Failing.Load()}); err != nil {
		log.Printf("Failed to write JSON response: %v", err)
	}
}

// chaosMiddleware responde HTTP 500 enquanto a falha estiver ativa
func (a *App) chaosMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if a.Failing.Load() {
			log.Printf("CHAOS: respondendo 500 para %s %s", r.Method, r.URL.Path)
			http.Error(w, "Falha injetada (chaos)", http.StatusInternalServerError)
			return
		}
		next.ServeHTTP(w, r)
	})
}
