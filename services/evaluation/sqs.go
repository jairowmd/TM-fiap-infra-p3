package main

import (
	"context"
	"encoding/json"
	"log"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/sqs"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/trace"
)

// Evento que será enviado para a fila
type EvaluationEvent struct {
	UserID    string    `json:"user_id"`
	FlagName  string    `json:"flag_name"`
	Result    bool      `json:"result"`
	Timestamp time.Time `json:"timestamp"`
}

// sendEvaluationEvent envia um evento para a fila SQS
func (a *App) sendEvaluationEvent(ctx context.Context, userID, flagName string, result bool) {
	// Se a URL da fila não foi configurada, apenas loga localmente e sai.
	if a.SqsSvc == nil || a.SqsQueueURL == "" {
		log.Printf("[SQS_DISABLED] Evento: User '%s', Flag '%s', Result '%t'", userID, flagName, result)
		return
	}

	event := EvaluationEvent{
		UserID:    userID,
		FlagName:  flagName,
		Result:    result,
		Timestamp: time.Now().UTC(),
	}

	body, err := json.Marshal(event)
	if err != nil {
		log.Printf("Erro ao serializar evento SQS: %v", err)
		return
	}

	// Span PRODUCER: representa a publicação na fila e é o "pai" do
	// processamento feito pelo analytics-service.
	queueName := a.SqsQueueURL[strings.LastIndex(a.SqsQueueURL, "/")+1:]
	ctx, span := otel.Tracer(serviceName).Start(ctx, "sqs send "+queueName,
		trace.WithSpanKind(trace.SpanKindProducer),
		trace.WithAttributes(
			attribute.String("messaging.system", "aws_sqs"),
			attribute.String("messaging.operation.type", "send"),
			attribute.String("messaging.destination.name", queueName),
			attribute.String("feature_flag.key", flagName),
		),
	)
	defer span.End()

	// Propaga o trace (header W3C "traceparent") nos atributos da mensagem SQS.
	carrier := propagation.MapCarrier{}
	otel.GetTextMapPropagator().Inject(ctx, carrier)
	attributes := make(map[string]*sqs.MessageAttributeValue, len(carrier))
	for key, value := range carrier {
		attributes[key] = &sqs.MessageAttributeValue{
			DataType:    aws.String("String"),
			StringValue: aws.String(value),
		}
	}

	// Envia a mensagem
	out, err := a.SqsSvc.SendMessageWithContext(ctx, &sqs.SendMessageInput{
		MessageBody:       aws.String(string(body)),
		QueueUrl:          aws.String(a.SqsQueueURL),
		MessageAttributes: attributes,
	})

	if err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, "falha ao enviar mensagem para o SQS")
		log.Printf("Erro ao enviar mensagem para SQS: %v", err)
		return
	}

	// Log SendMessage response details for debugging
	if out.MessageId != nil {
		log.Printf("SQS SendMessage MessageId: %s", *out.MessageId)
	}
	if out.MD5OfMessageBody != nil {
		log.Printf("SQS MD5OfMessageBody: %s", *out.MD5OfMessageBody)
	}
	log.Printf("Evento de avaliação enviado para SQS (Flag: %s, QueueURL: %s, Body: %s)", flagName, a.SqsQueueURL, string(body))

}