# ---------- build ----------
FROM golang:1.24-alpine AS builder
WORKDIR /app
COPY . .
RUN go build -o evaluation

# ---------- runtime ----------
FROM alpine:3.21
WORKDIR /app
COPY --from=builder /app/evaluation .
CMD ["./evaluation"]
