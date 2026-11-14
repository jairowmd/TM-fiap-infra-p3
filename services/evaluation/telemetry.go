package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetrichttp"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/propagation"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
)

// setupTelemetry configura traces e métricas OpenTelemetry exportados via OTLP/HTTP.
// O destino vem de OTEL_EXPORTER_OTLP_ENDPOINT (no cluster: o OTel Collector),
// e o nome do serviço de OTEL_SERVICE_NAME (com fallback para defaultServiceName).
func setupTelemetry(ctx context.Context, defaultServiceName string) (func(context.Context) error, error) {
	if strings.EqualFold(os.Getenv("OTEL_SDK_DISABLED"), "true") {
		log.Println("OpenTelemetry desabilitado (OTEL_SDK_DISABLED=true).")
		return func(context.Context) error { return nil }, nil
	}

	res, err := resource.New(ctx,
		resource.WithAttributes(attribute.String("service.name", defaultServiceName)),
		resource.WithFromEnv(), // OTEL_SERVICE_NAME e OTEL_RESOURCE_ATTRIBUTES sobrescrevem o padrão
		resource.WithTelemetrySDK(),
		resource.WithHost(),
	)
	if err != nil && !errors.Is(err, resource.ErrPartialResource) {
		return nil, err
	}

	traceExporter, err := otlptracehttp.New(ctx)
	if err != nil {
		return nil, err
	}
	tracerProvider := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(traceExporter),
		sdktrace.WithResource(res),
	)

	metricExporter, err := otlpmetrichttp.New(ctx)
	if err != nil {
		return nil, errors.Join(err, tracerProvider.Shutdown(ctx))
	}
	meterProvider := sdkmetric.NewMeterProvider(
		sdkmetric.WithReader(sdkmetric.NewPeriodicReader(metricExporter, sdkmetric.WithInterval(30*time.Second))),
		sdkmetric.WithResource(res),
	)

	otel.SetTracerProvider(tracerProvider)
	otel.SetMeterProvider(meterProvider)
	// W3C Trace Context: mesmo formato usado pelos serviços Python.
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{},
		propagation.Baggage{},
	))

	log.Println("OpenTelemetry inicializado (traces e métricas via OTLP/HTTP).")
	return func(ctx context.Context) error {
		return errors.Join(tracerProvider.Shutdown(ctx), meterProvider.Shutdown(ctx))
	}, nil
}

// instrumentHandler cria um span SERVER por requisição, ignorando o health check
// para não poluir o APM com as probes do Kubernetes.
func instrumentHandler(h http.Handler, serviceName string) http.Handler {
	return otelhttp.NewHandler(h, serviceName,
		otelhttp.WithFilter(func(r *http.Request) bool { return r.URL.Path != "/health" }),
		otelhttp.WithSpanNameFormatter(func(_ string, r *http.Request) string {
			return r.Method + " " + r.URL.Path
		}),
	)
}
