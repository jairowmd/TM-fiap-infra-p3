# ---------- build ----------
FROM golang:1.24-alpine AS builder
WORKDIR /app
COPY . .
RUN go build -o analytics

# ---------- runtime ----------
FROM alpine:3.21
WORKDIR /app
COPY --from=builder /app/analytics .
CMD ["./analytics"]
