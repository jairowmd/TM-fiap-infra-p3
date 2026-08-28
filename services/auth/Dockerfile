# ---------- build ----------
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY . .
RUN go build -o auth

# ---------- runtime ----------
FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/auth .
CMD ["./auth"]
