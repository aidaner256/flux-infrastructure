#!/bin/bash
# Полный скрипт настройки секретов и политик в HashiCorp Vault
# Включает секреты для Go-сервиса (order-app) и Python-сервиса (order-service-py)

set -e

echo "========================================="
echo "Настройка Vault для всех сервисов"
echo "========================================="

# Проверка доступности Vault
if ! command -v vault &> /dev/null; then
    echo "ОШИБКА: Vault CLI не установлен!"
    echo "Установите Vault: https://www.vaultproject.io/downloads"
    exit 1
fi

# ==========================================
# СЕКРЕТЫ ДЛЯ ОБЩИХ КОМПОНЕНТОВ
# ==========================================

echo ""
echo "=== Создание секретов для MongoDB ==="
vault kv put secret/app/mongo \
  host="mongodb.dev.svc.cluster.local" \
  port="27017" \
  database="shipments_db" \
  user="" \
  password=""

echo ""
echo "=== Создание секретов для Redis ==="
vault kv put secret/app/redis \
  host="redis.dev.svc.cluster.local" \
  port="6379" \
  password=""

echo ""
echo "=== Создание секретов для RabbitMQ ==="
vault kv put secret/app/rabbitmq \
  host="rabbitmq.dev.svc.cluster.local" \
  port="5672" \
  username="guest" \
  password="guest"

echo ""
echo "=== Создание секретов для PostgreSQL ==="
vault kv put secret/app/postgres \
  host="postgresql.postgre.svc.cluster.local" \
  port="5432" \
  database="orders" \
  user="postgres" \
  password="postgres"

# ==========================================
# СЕКРЕТЫ ДЛЯ GO-СЕРВИСА (order-app)
# ==========================================

echo ""
echo "=== Создание секретов для Go-сервиса (order-app) ==="
vault kv put secret/app/order-app \
  port="8080" \
  app-version="1.0.2" \
  gin-mode="release" \
  kafka-brokers="kafka.dev.svc.cluster.local:29092" \
  kafka-topic="order.created" \
  kafka-group-id="shipment-service" \
  rabbitmq-queue="shipment.ready"

echo ""
echo "=== Создание политики для order-app ==="
vault policy write order-app - <<EOF
# Политика для чтения секретов приложения order-app

# Разрешить чтение секретов MongoDB
path "secret/data/app/mongo" {
  capabilities = ["read"]
}

# Разрешить чтение секретов Redis
path "secret/data/app/redis" {
  capabilities = ["read"]
}

# Разрешить чтение секретов RabbitMQ
path "secret/data/app/rabbitmq" {
  capabilities = ["read"]
}

# Разрешить чтение секретов приложения
path "secret/data/app/order-app" {
  capabilities = ["read"]
}

# Разрешить листинг секретов (опционально)
path "secret/metadata/app/*" {
  capabilities = ["list"]
}
EOF

echo ""
echo "=== Создание роли Kubernetes для order-app ==="
vault write auth/kubernetes/role/application-order-role \
  bound_service_account_names=order-app-sa \
  bound_service_account_namespaces=dev \
  policies=order-app \
  ttl=24h

# ==========================================
# СЕКРЕТЫ ДЛЯ PYTHON-СЕРВИСА (order-service-py)
# ==========================================

echo ""
echo "=== Создание секретов для Python-сервиса (order-service-py) ==="
vault kv put secret/app/order-service-py \
  port="8000" \
  app-version="1.0.0" \
  debug="false" \
  kafka-bootstrap-servers="kafka.dev.svc.cluster.local:29092" \
  kafka-topic="order.created"

echo ""
echo "=== Создание политики для order-service-py ==="
vault policy write order-service-py - <<EOF
# Политика для чтения секретов Python Order Service

# Разрешить чтение секретов PostgreSQL
path "secret/data/app/postgres" {
  capabilities = ["read"]
}

# Разрешить чтение секретов Redis
path "secret/data/app/redis" {
  capabilities = ["read"]
}

# Разрешить чтение секретов приложения
path "secret/data/app/order-service-py" {
  capabilities = ["read"]
}

# Разрешить листинг секретов (опционально)
path "secret/metadata/app/*" {
  capabilities = ["list"]
}
EOF

echo ""
echo "=== Создание роли Kubernetes для order-service-py ==="
vault write auth/kubernetes/role/order-service-py-role \
  bound_service_account_names=order-service-py-sa \
  bound_service_account_namespaces=dev \
  policies=order-service-py \
  ttl=24h

# ==========================================
# СЕКРЕТЫ ДЛЯ ВСПОМОГАТЕЛЬНЫХ СЕРВИСОВ
# ==========================================

echo ""
echo "=== Создание политики для RabbitMQ ==="
vault policy write rabbitmq - <<EOF
# Политика для чтения секретов RabbitMQ

# Разрешить чтение секретов RabbitMQ
path "secret/data/app/rabbitmq" {
  capabilities = ["read"]
}

# Разрешить листинг секретов (опционально)
path "secret/metadata/app/rabbitmq" {
  capabilities = ["list"]
}
EOF

echo ""
echo "=== Создание роли Kubernetes для RabbitMQ ==="
vault write auth/kubernetes/role/rabbitmq-role \
  bound_service_account_names=rabbitmq-sa \
  bound_service_account_namespaces=dev \
  policies=rabbitmq \
  ttl=24h

echo ""
echo "=== Создание политики для MongoDB ==="
vault policy write mongodb - <<EOF
# Политика для чтения секретов MongoDB

# Разрешить чтение секретов MongoDB
path "secret/data/app/mongo" {
  capabilities = ["read"]
}

# Разрешить листинг секретов (опционально)
path "secret/metadata/app/mongo" {
  capabilities = ["list"]
}
EOF

echo ""
echo "=== Создание роли Kubernetes для MongoDB ==="
vault write auth/kubernetes/role/mongodb-role \
  bound_service_account_names=mongodb-sa \
  bound_service_account_namespaces=dev \
  policies=mongodb \
  ttl=24h

echo ""
echo "=== Создание политики для PostgreSQL ==="
vault policy write postgres - <<EOF
# Политика для чтения секретов PostgreSQL

# Разрешить чтение секретов PostgreSQL
path "secret/data/app/postgres" {
  capabilities = ["read"]
}

# Разрешить листинг секретов (опционально)
path "secret/metadata/app/postgres" {
  capabilities = ["list"]
}
EOF

echo ""
echo "=== Создание роли Kubernetes для PostgreSQL ==="
vault write auth/kubernetes/role/postgres-role \
  bound_service_account_names=postgres-sa \
  bound_service_account_namespaces=dev \
  policies=postgres \
  ttl=24h

# ==========================================
# ИТОГИ
# ==========================================

echo ""
echo "========================================="
echo "Настройка Vault завершена успешно!"
echo "========================================="
echo ""
echo "Созданные секреты:"
echo "  - secret/app/mongo         - Секреты MongoDB"
echo "  - secret/app/redis         - Секреты Redis"
echo "  - secret/app/rabbitmq      - Секреты RabbitMQ"
echo "  - secret/app/postgres      - Секреты PostgreSQL (новый)"
echo "  - secret/app/order-app     - Секреты Go-сервиса"
echo "  - secret/app/order-service-py - Секреты Python-сервиса (новый)"
echo ""
echo "Созданные политики:"
echo "  - order-app           - Политика для Go-сервиса"
echo "  - order-service-py    - Политика для Python-сервиса (новая)"
echo "  - rabbitmq            - Политика для RabbitMQ"
echo "  - mongodb             - Политика для MongoDB"
echo "  - postgres            - Политика для PostgreSQL (новая)"
echo ""
echo "Созданные роли Kubernetes:"
echo "  - application-order-role    - Роль для order-app-sa"
echo "  - order-service-py-role     - Роль для order-service-py-sa (новая)"
echo "  - rabbitmq-role             - Роль для rabbitmq-sa"
echo "  - mongodb-role              - Роль для mongodb-sa"
echo "  - postgres-role             - Роль для postgres-sa (новая)"
echo ""
echo "ServiceAccounts (должны быть созданы в Kubernetes):"
echo "  - order-app-sa              - namespace: dev"
echo "  - order-service-py-sa       - namespace: dev (новый)"
echo "  - rabbitmq-sa               - namespace: dev"
echo "  - mongodb-sa                - namespace: dev"
echo "  - postgres-sa               - namespace: dev (новый)"
echo ""
echo "Для проверки секретов используйте:"
echo "  vault kv get secret/app/mongo"
echo "  vault kv get secret/app/redis"
echo "  vault kv get secret/app/rabbitmq"
echo "  vault kv get secret/app/postgres"
echo "  vault kv get secret/app/order-app"
echo "  vault kv get secret/app/order-service-py"
echo ""
echo "Следующие шаги:"
echo "  1. Примените Kubernetes манифесты для Python-сервиса:"
echo "     kubectl apply -f service-py/deploy/k8s-secrets.yaml"
echo "     kubectl apply -f service-py/deploy/k8s-deployment.yaml"
echo ""
echo "  2. Проверьте статус подов:"
echo "     kubectl get pods -n dev"
echo ""
