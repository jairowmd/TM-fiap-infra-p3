# ---------- build ----------
FROM golang:1.25-alpine AS builder
WORKDIR /app
COPY . .
RUN go build -o flag

# ---------- runtime ----------
FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/flag .
CMD ["./flag"]
