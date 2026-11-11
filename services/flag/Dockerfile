FROM python:3.9-slim

# Install current Debian security fixes, including OpenSSL and Perl updates.
RUN apt-get update \
    && apt-get upgrade -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8002

# "opentelemetry-instrument" ativa a auto-instrumentação (Flask, requests,
# psycopg2). Destino e nome do serviço vêm das variáveis OTEL_* do deployment.
CMD ["opentelemetry-instrument", "gunicorn", "--bind", "0.0.0.0:8002", "app:app"]
