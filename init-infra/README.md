Установка и настройка Flux CD, Vault, PostgreSQL и приложения

## 1. Установка Flux

Первая команда, которую нужно выполнить:

```bash
flux install
````

Она создаст необходимые сущности, включая namespace `flux-system`.

---

## 2. Создание Git credentials для Flux

Flux будет скачивать обновления из Git-репозитория. Создадим секрет:

```bash
kubectl create secret generic flux-git-credentials \
  --namespace=flux-system \
  --from-literal=username=git \
  --from-literal=password=github_pat_token
```

---

## 3. Создание секретов PostgreSQL

Перед установкой базы создадим namespace и базовый логин/пароль:

```bash
kubectl create ns postgre
```

```bash
kubectl create secret generic postgresql-secret \
  --namespace=postgre \
  --from-literal=username=vault \
  --from-literal=password=PASSWORD \
  --from-literal=database=vault
```

---

## 4. Настройка Vault

Создаём namespace и применяем секреты:

```bash
kubectl create ns vault
kubectl apply -f secret-postgres.yaml
```

---

## 5. Применяем манифесты Flux CD

```bash
kubectl apply -f gitrepository.yaml
kubectl apply -f kustomization.yaml
```

Flux создаст все ресурсы, описанные в репозитории.
После создания Vault — необходимо инициализировать базу данных.

---

## 6. Инициализация базы данных для Vault

Подключаемся к PostgreSQL и создаём таблицы:

```sql
CREATE TABLE vault_kv_store (
  parent_path TEXT COLLATE "C" NOT NULL,
  path        TEXT COLLATE "C",
  key         TEXT COLLATE "C",
  value       BYTEA,
  CONSTRAINT pkey PRIMARY KEY (path, key)
);

CREATE INDEX parent_path_idx ON vault_kv_store (parent_path);

CREATE TABLE vault_ha_locks (
  ha_key          TEXT COLLATE "C" NOT NULL,
  ha_identity     TEXT COLLATE "C" NOT NULL,
  ha_value        TEXT COLLATE "C",
  valid_until     TIMESTAMP WITH TIME ZONE NOT NULL,
  CONSTRAINT ha_key PRIMARY KEY (ha_key)
);
```

---

## 7. Создание роли и базы данных для приложения

```sql
-- 1. Создать роль postgres с паролем
CREATE ROLE postgres WITH LOGIN PASSWORD 'postgres';

-- 2. Дать права суперпользователя
ALTER ROLE postgres WITH SUPERUSER CREATEDB CREATEROLE REPLICATION;

-- 3. Создать базу данных orders
DO $$
BEGIN
   IF NOT EXISTS (
      SELECT FROM pg_database WHERE datname = 'orders'
   ) THEN
      CREATE DATABASE orders;
   END IF;
END $$;

-- 4. Назначить владельцем базы пользователя postgres
ALTER DATABASE orders OWNER TO postgres;

-- 5. Выдать пользователю postgres все права на базу
GRANT ALL PRIVILEGES ON DATABASE orders TO postgres;

-- 6. Проверка
\du
\l
```

---

## 8. Инициализация и настройка Vault

```bash
kubectl -n vault exec vault-0 -- sh
vault status
vault operator init -key-shares=1 -key-threshold=1 -format=json > /tmp/cluster-keys.json
cat /tmp/cluster-keys.json
vault operator unseal
vault login
vault secrets enable -path=secret kv-v2
vault auth enable kubernetes
vault auth list
```

---

## 9. Настройка секретов Vault

Измените пароли в файле `vault-setup-complete.sh`, затем выполните его —
он создаст все необходимые секреты для работы сервисов.

---

## 10. Дополнительная настройка Prometheus

(Проверить при чистой установке kube-prom-stack)

```bash
sudo chown -R 65534:65534 /opt/prometheus-data/prometheus-db
ls -la /opt/prometheus-data/prometheus-db
```

Если `vault` не успел отдать секреты `external-secrets`, пересоздайте ресурс:

```bash
kubectl delete secret grafana-admin -n monitoring
flux reconcile kustomization external-secrets -n flux-system
```

---

## 11. Создание топика в Kafka

```bash
kafka-topics \
  --create \
  --bootstrap-server localhost:9092 \
  --topic order.created \
  --partitions 3 \
  --replication-factor 1 \
  --if-not-exists
```

---

## 12. Проверка работы приложения

### Добавляем хосты в `/etc/hosts`:

```bash
sudo nano /etc/hosts
```

Добавляем строки:

```
192.168.0.240 alertmanager.local
192.168.0.240 prometheus.local
192.168.0.240 grafana.local
192.168.0.240 vault.local
192.168.0.240 kibana.local
192.168.0.240 app.local
192.168.0.240 app-py.local
```

---

### Создание заказа

```bash
curl -X 'POST' \
  'http://app-py.local/api/v1/orders/' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "customer_name": "PID",
  "customer_email": "PID@gamil.com",
  "product_name": "K8S",
  "quantity": 10,
  "total_amount": 3
}' | jq
```

Пример ответа:

```json
{
  "customer_name": "PID",
  "customer_email": "PID@gamil.com",
  "product_name": "K8S",
  "quantity": 10,
  "total_amount": 3.0,
  "id": "ac253940-e29e-416e-b55f-30504b601810",
  "status": "created",
  "created_at": "2025-10-22T14:21:22.348132",
  "updated_at": null
}
```

---

### Проверка доставки по `order_id`

```bash
curl http://app.local/api/v1/shipments/4735b1bb-46e3-4856-a365-dfe2fd1c41d6 | jq
```

Пример ответа:

```json
{
  "id": "68f8c661181e58b33a4c59a8",
  "order_id": "4735b1bb-46e3-4856-a365-dfe2fd1c41d6",
  "status": "pending",
  "created_at": "2025-10-22T11:56:17.956Z"
}
```

---

**На этом установка и проверка завершены.**
