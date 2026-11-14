import os
import sys
import threading
import json
import uuid
import time
import logging
import boto3
from botocore.exceptions import NoCredentialsError, ClientError
from flask import Flask, jsonify
from dotenv import load_dotenv
from opentelemetry import propagate, trace
from opentelemetry.trace import SpanKind, Status, StatusCode

try:
    from opentelemetry.instrumentation.utils import suppress_instrumentation
except ImportError:  # pragma: no cover - fallback se a lib mudar de lugar
    from contextlib import nullcontext as suppress_instrumentation

# Tracer usado no consumo do SQS (o Flask e o boto3 são auto-instrumentados)
tracer = trace.get_tracer("analytics-service")

# Configura o logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
log = logging.getLogger(__name__)

# Carrega .env para desenvolvimento local
load_dotenv()

# --- Configuração ---
AWS_REGION = os.getenv("AWS_REGION")
SQS_QUEUE_URL = os.getenv("AWS_SQS_URL")
DYNAMODB_TABLE_NAME = os.getenv("AWS_DYNAMODB_TABLE")

if not all([AWS_REGION, SQS_QUEUE_URL, DYNAMODB_TABLE_NAME]):
    log.critical("Erro: AWS_REGION, AWS_SQS_URL, e AWS_DYNAMODB_TABLE devem ser definidos.")
    sys.exit(1)

# --- Clientes Boto3 ---
# Criamos a sessão uma vez
try:
    session = boto3.Session(region_name=AWS_REGION)
    endpoint_url = os.getenv('AWS_ENDPOINT_URL')
    if endpoint_url:
        client_kwargs = {"endpoint_url": endpoint_url}
        sqs_client = session.client("sqs", **client_kwargs)
        dynamodb_client = session.client("dynamodb", **client_kwargs)
    else:
        sqs_client = session.client("sqs")
        dynamodb_client = session.client("dynamodb")
    log.info(f"Clientes Boto3 inicializados na região {AWS_REGION} (endpoint={endpoint_url})")
except NoCredentialsError:
    log.critical("Credenciais da AWS não encontradas. Verifique seu ambiente.")
    sys.exit(1)
except Exception as e:
    log.critical(f"Erro ao inicializar o Boto3: {e}")
    sys.exit(1)

QUEUE_NAME = SQS_QUEUE_URL.rstrip("/").split("/")[-1]


# --- Tracing do consumo SQS ---

def trace_context_from(message):
    """ Extrai o contexto W3C (traceparent) que o evaluation-service enviou
    nos atributos da mensagem, ligando este processamento ao trace original. """
    carrier = {
        key: attr["StringValue"]
        for key, attr in message.get("MessageAttributes", {}).items()
        if attr.get("DataType") == "String" and "StringValue" in attr
    }
    return propagate.extract(carrier)


def mark_span_error(description, exc=None):
    """ Marca o span atual como erro (aparece como erro no APM). """
    span = trace.get_current_span()
    if exc is not None:
        span.record_exception(exc)
    span.set_status(Status(StatusCode.ERROR, description))


# --- SQS Worker ---

def process_message(message):
    """ Processa uma única mensagem SQS e a insere no DynamoDB """
    try:
        log.info(f"Processando mensagem ID: {message['MessageId']}")
        body = json.loads(message['Body'])
        trace.get_current_span().set_attribute("feature_flag.key", body.get('flag_name', ''))

        # Gera um ID único para o item no DynamoDB
        event_id = str(uuid.uuid4())
        
        # Constrói o item no formato do DynamoDB
        item = {
            'event_id': {'S': event_id},
            'user_id': {'S': body['user_id']},
            'flag_name': {'S': body['flag_name']},
            'result': {'BOOL': body['result']},
            'timestamp': {'S': body['timestamp']}
        }
        
        # Insere no DynamoDB
        dynamodb_client.put_item(
            TableName=DYNAMODB_TABLE_NAME,
            Item=item
        )
        
        log.info(f"Evento {event_id} (Flag: {body['flag_name']}) salvo no DynamoDB.")
        
        # Se tudo deu certo, deleta a mensagem da fila
        sqs_client.delete_message(
            QueueUrl=SQS_QUEUE_URL,
            ReceiptHandle=message['ReceiptHandle']
        )
        
    except json.JSONDecodeError as e:
        log.error(f"Erro ao decodificar JSON da mensagem ID: {message['MessageId']}")
        mark_span_error("JSON inválido na mensagem SQS", e)
        # Não deleta a mensagem, pode ser uma "poison pill"
    except ClientError as e:
        log.error(f"Erro do Boto3 (DynamoDB ou SQS) ao processar {message['MessageId']}: {e}")
        mark_span_error("Erro do Boto3 ao processar mensagem", e)
        # Não deleta a mensagem, tenta novamente
    except Exception as e:
        log.error(f"Erro inesperado ao processar {message['MessageId']}: {e}")
        mark_span_error("Erro inesperado ao processar mensagem", e)
        # Não deleta a mensagem, tenta novamente

def sqs_worker_loop():
    """ Loop principal do worker que ouve a fila SQS """
    log.info("Iniciando o worker SQS...")
    while True:
        try:
            # Long-polling: espera até 20s por mensagens.
            # O polling não gera spans (seriam traces vazios a cada 20s);
            # o que vira trace é o processamento de cada mensagem abaixo.
            with suppress_instrumentation():
                response = sqs_client.receive_message(
                    QueueUrl=SQS_QUEUE_URL,
                    MaxNumberOfMessages=10,  # Processa em lotes de até 10
                    WaitTimeSeconds=20,
                    MessageAttributeNames=['All']  # Inclui o "traceparent"
                )
            
            messages = response.get('Messages', [])
            if not messages:
                # Nenhuma mensagem, continua o loop
                continue
                
            log.info(f"Recebidas {len(messages)} mensagens.")
            
            for message in messages:
                # Span CONSUMER filho do span "sqs send" do evaluation-service.
                # As chamadas ao DynamoDB/SQS feitas aqui dentro viram spans filhos.
                with tracer.start_as_current_span(
                    f"sqs process {QUEUE_NAME}",
                    context=trace_context_from(message),
                    kind=SpanKind.CONSUMER,
                    attributes={
                        "messaging.system": "aws_sqs",
                        "messaging.operation.type": "process",
                        "messaging.destination.name": QUEUE_NAME,
                        "messaging.message.id": message.get('MessageId', ''),
                    },
                ):
                    process_message(message)
                
        except ClientError as e:
            log.error(f"Erro do Boto3 no loop principal do SQS: {e}")
            time.sleep(10) # Pausa antes de tentar novamente
        except Exception as e:
            log.error(f"Erro inesperado no loop principal do SQS: {e}")
            time.sleep(10)

# --- Servidor Flask (Apenas para Health Check) ---

app = Flask(__name__)

@app.route('/health')
def health():
    # Uma verificação de saúde real poderia checar a conexão com o DynamoDB/SQS
    return jsonify({"status": "ok"})

# --- Inicialização ---

def start_worker():
    """ Inicia o worker SQS em uma thread separada """
    worker_thread = threading.Thread(target=sqs_worker_loop, daemon=True)
    worker_thread.start()

# Inicia o worker SQS em uma thread de background
# Isso garante que ele inicie tanto com 'flask run' quanto com 'gunicorn'
start_worker()

if __name__ == '__main__':
    port = int(os.getenv("PORT", 8005))
    app.run(host='127.0.0.1', port=port, debug=False)