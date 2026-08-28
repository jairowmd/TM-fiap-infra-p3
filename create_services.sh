#!/usr/bin/env bash
set -euo pipefail

# Lista dos serviços que o workflow espera
services=(
  analytics
  auth
  evaluation
  flag
  targeting
)

# Função que cria um serviço de exemplo
create_service() {
  local svc=$1
  local dir="services/$svc"

  echo "🛠️  Criando $dir ..."
  mkdir -p "$dir"

  # go.mod (módulo padrão; troque o caminho se quiser usar outro repo)
  cat > "$dir/go.mod" <<'EOF'
module github.com/torresj0/{{SERVICE}}-service

go 1.22
EOF
  sed -i "s/{{SERVICE}}/$svc/g" "$dir/go.mod"

  # main.go – programa "hello world" para o serviço
  cat > "$dir/main.go" <<'EOF'
package main

import "fmt"

func main() {
    fmt.Println("{{SERVICE}} service started")
}
EOF
  sed -i "s/{{SERVICE}}/$svc/g" "$dir/main.go"

  # Dockerfile – imagem mínima baseada em Alpine
  cat > "$dir/Dockerfile" <<'EOF'
# ---------- build ----------
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY . .
RUN go build -o {{SERVICE}}

# ---------- runtime ----------
FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/{{SERVICE}} .
CMD ["./{{SERVICE}}"]
EOF
  sed -i "s/{{SERVICE}}/$svc/g" "$dir/Dockerfile"

  echo "✅  $svc criado"
}

# Loop em todos os serviços
for svc in "${services[@]}"; do
  create_service "$svc"
 done

echo "🎉  Todos os diretórios de serviço foram criados."
