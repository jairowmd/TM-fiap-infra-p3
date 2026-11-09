package main

import (
	"context"
	"database/sql"
	"errors"
	"log"
	"net/http"
	"net/url"
	"os"
	"os/signal"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/XSAM/otelsql"
	_ "github.com/jackc/pgx/v4/stdlib"
	"github.com/joho/godotenv"
	"go.opentelemetry.io/otel/attribute"
)

const serviceName = "auth-service"

// App struct (para injeção de dependência)
type App struct {
	DB        *sql.DB
	MasterKey string
	Failing   atomic.Bool // falha injetada para o teste de Self-Healing (chaos.go)
}

func main() {
	// Carrega o .env para desenvolvimento local. Em produção, isso não fará nada.
	_ = godotenv.Load()

	// --- Observabilidade (OpenTelemetry) ---
	shutdownTelemetry, err := setupTelemetry(context.Background(), serviceName)
	if err != nil {
		log.Fatalf("Não foi possível inicializar o OpenTelemetry: %v", err)
	}

	// --- Configuração ---
	port := os.Getenv("PORT")
	if port == "" {
		port = "8001" // Porta padrão
	}

	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		log.Fatal("DATABASE_URL deve ser definida")
	}

	masterKey := os.Getenv("MASTER_KEY")
	if masterKey == "" {
		log.Fatal("MASTER_KEY deve ser definida")
	}

	// --- Conexão com o Banco ---
	db, err := connectDB(databaseURL)
	if err != nil {
		log.Fatalf("Não foi possível conectar ao banco de dados: %v", err)
	}
	defer func() {
		if err := db.Close(); err != nil {
			log.Printf("Failed to close database: %v", err)
		}
	}()

	app := &App{
		DB:        db,
		MasterKey: masterKey,
	}

	// --- Rotas da API ---
	mux := http.NewServeMux()
	mux.HandleFunc("/health", app.healthHandler)

	// Endpoint público para validar uma chave
	mux.Handle("/validate", app.chaosMiddleware(http.HandlerFunc(app.validateKeyHandler)))

	// Endpoints de "admin" para criar/gerenciar chaves
	// Eles são protegidos pelo middleware de autenticação
	mux.Handle("/admin/keys", app.masterKeyAuthMiddleware(http.HandlerFunc(app.createKeyHandler)))

	// Liga/desliga a falha usada na demonstração de Self-Healing
	mux.Handle("/admin/chaos", app.masterKeyAuthMiddleware(http.HandlerFunc(app.chaosHandler)))

	log.Printf("Serviço de Autenticação (Go) rodando na porta %s", port)
	server := &http.Server{
		Addr:              ":" + port,
		Handler:           instrumentHandler(mux, serviceName),
		ReadHeaderTimeout: 5 * time.Second,
	}
	runServer(server, shutdownTelemetry)
}

// runServer sobe o servidor HTTP e, ao receber SIGTERM/SIGINT (ex.: rollout do
// Kubernetes), encerra as conexões e envia os spans pendentes antes de sair.
func runServer(server *http.Server, shutdownTelemetry func(context.Context) error) {
	stopCtx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	serverErr := make(chan error, 1)
	go func() {
		serverErr <- server.ListenAndServe()
	}()

	select {
	case err := <-serverErr:
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Printf("Erro no servidor HTTP: %v", err)
		}
	case <-stopCtx.Done():
		log.Println("Sinal de encerramento recebido, finalizando...")
	}

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := server.Shutdown(shutdownCtx); err != nil {
		log.Printf("Erro ao encerrar o servidor HTTP: %v", err)
	}
	if err := shutdownTelemetry(shutdownCtx); err != nil {
		log.Printf("Erro ao encerrar o OpenTelemetry: %v", err)
	}
}

// dbAttributes identifica o PostgreSQL nos spans, para o New Relic exibir o
// banco como dependência do auth-service no Service Map.
func dbAttributes(databaseURL string) []attribute.KeyValue {
	attrs := []attribute.KeyValue{attribute.String("db.system", "postgresql")}
	if u, err := url.Parse(databaseURL); err == nil {
		if host := u.Hostname(); host != "" {
			attrs = append(attrs,
				attribute.String("server.address", host),
				attribute.String("net.peer.name", host),
			)
		}
		if len(u.Path) > 1 {
			attrs = append(attrs, attribute.String("db.name", u.Path[1:]))
		}
	}
	return attrs
}

// connectDB inicializa e testa a conexão com o PostgreSQL.
// O otelsql cria um span CLIENT para cada query executada.
func connectDB(databaseURL string) (*sql.DB, error) {
	db, err := otelsql.Open("pgx", databaseURL,
		otelsql.WithAttributes(dbAttributes(databaseURL)...),
		otelsql.WithSpanOptions(otelsql.SpanOptions{
			OmitConnResetSession: true,
			OmitRows:             true,
			OmitConnectorConnect: true,
		}),
	)
	if err != nil {
		return nil, err
	}

	if err = db.Ping(); err != nil {
		return nil, err
	}

	log.Println("Conectado ao PostgreSQL com sucesso!")
	return db, nil
}
