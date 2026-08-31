# ---------- build ----------
FROM golang:1.24-alpine AS builder
WORKDIR /app
COPY . .
RUN go build -o targeting

# ---------- runtime ----------
FROM alpine:3.21
WORKDIR /app
COPY --from=builder /app/targeting .
CMD ["./targeting"]
