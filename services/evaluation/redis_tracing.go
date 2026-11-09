package main

import (
	"context"
	"errors"
	"net"
	"strconv"

	"github.com/go-redis/redis/v8"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/trace"
)

// redisTracingHook cria um span CLIENT para cada comando Redis. Os atributos
// db.system e server.address fazem o New Relic mostrar o Redis como
// dependência do evaluation-service no Service Map.
type redisTracingHook struct {
	tracer trace.Tracer
	attrs  []attribute.KeyValue
}

func newRedisTracingHook(addr string) redisTracingHook {
	attrs := []attribute.KeyValue{attribute.String("db.system", "redis")}
	if host, portStr, err := net.SplitHostPort(addr); err == nil {
		attrs = append(attrs,
			attribute.String("server.address", host),
			attribute.String("net.peer.name", host),
		)
		if port, err := strconv.Atoi(portStr); err == nil {
			attrs = append(attrs, attribute.Int("server.port", port))
		}
	}
	return redisTracingHook{tracer: otel.Tracer("evaluation-service/redis"), attrs: attrs}
}

func (h redisTracingHook) start(ctx context.Context, operation string) context.Context {
	ctx, _ = h.tracer.Start(ctx, "redis "+operation,
		trace.WithSpanKind(trace.SpanKindClient),
		trace.WithAttributes(h.attrs...),
		trace.WithAttributes(attribute.String("db.operation", operation)),
	)
	return ctx
}

func finishRedisSpan(ctx context.Context, err error) {
	span := trace.SpanFromContext(ctx)
	// redis.Nil significa apenas "chave não existe" (cache miss), não é erro.
	if err != nil && !errors.Is(err, redis.Nil) {
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
	}
	span.End()
}

func (h redisTracingHook) BeforeProcess(ctx context.Context, cmd redis.Cmder) (context.Context, error) {
	return h.start(ctx, cmd.Name()), nil
}

func (h redisTracingHook) AfterProcess(ctx context.Context, cmd redis.Cmder) error {
	finishRedisSpan(ctx, cmd.Err())
	return nil
}

func (h redisTracingHook) BeforeProcessPipeline(ctx context.Context, _ []redis.Cmder) (context.Context, error) {
	return h.start(ctx, "pipeline"), nil
}

func (h redisTracingHook) AfterProcessPipeline(ctx context.Context, cmds []redis.Cmder) error {
	var err error
	for _, cmd := range cmds {
		if cmdErr := cmd.Err(); cmdErr != nil && !errors.Is(cmdErr, redis.Nil) {
			err = cmdErr
			break
		}
	}
	finishRedisSpan(ctx, err)
	return nil
}
