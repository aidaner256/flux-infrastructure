# Order App Helm Chart

Helm chart для развертывания Order App микросервиса с полным стеком инфраструктуры:
- Order App (Go application)
- MongoDB (база данных)
- Redis (кеширование)
- Kafka + Zookeeper (message broker)
- RabbitMQ (message queue)
- HashiCorp Vault CSI Driver (управление секретами)
- Nginx Ingress (внешний доступ)

## Предварительные требования

- Kubernetes 1.20+
- Helm 3.0+
- Nginx Ingress Controller
- HashiCorp Vault с CSI Driver
- Kubectl настроен для работы с кластером

## Установка

### 1. Подготовка хост-системы

Создайте директорию для PersistentVolumes:

```bash
sudo mkdir -p /opt/order-app-data/{mongodb,redis,kafka,zookeeper,rabbitmq}
sudo chmod -R 755 /opt/order-app-data
```

### 2. Настройка Vault

Используйте скрипт из директории `../basic/vault-setup.sh` для настройки Vault:

```bash
cd ../basic
export VAULT_ADDR='http://vault-vault.vault.svc.cluster.local:8200'
export VAULT_TOKEN='your-vault-token'
./vault-setup.sh
```

### 3. Настройка values.yaml

Отредактируйте `values.yaml` согласно вашему окружению:

```yaml
# Обновите Docker registry
app:
  image:
    repository: your-registry/order-app
    tag: "1.0.2"

# Настройте Ingress host
ingress:
  hosts:
    - host: your-domain.local
      paths:
        - path: /
          pathType: Prefix
```

### 4. Установка chart

```bash
# Из директории с chart
helm install order-app . -n dev --create-namespace

# Или укажите свой values файл
helm install order-app . -n dev --create-namespace -f my-values.yaml
```

### 5. Проверка установки

```bash
# Проверьте статус release
helm status order-app -n dev

# Проверьте поды
kubectl get pods -n dev

# Проверьте все ресурсы
kubectl get all -n dev
```

## Настройка

### Основные параметры

| Параметр | Описание | Значение по умолчанию |
|----------|----------|----------------------|
| `global.namespace` | Kubernetes namespace | `dev` |
| `global.storageClass` | StorageClass для PV | `local-storage` |
| `global.hostPath` | Путь к данным на хосте | `/opt/order-app-data` |

### Приложение

| Параметр | Описание | Значение по умолчанию |
|----------|----------|----------------------|
| `app.replicaCount` | Количество реплик | `1` |
| `app.image.repository` | Docker registry | `your-registry/order-app` |
| `app.image.tag` | Версия образа | `1.0.2` |
| `app.service.port` | Порт сервиса | `8080` |
| `app.resources.requests.memory` | Memory request | `256Mi` |
| `app.resources.limits.memory` | Memory limit | `512Mi` |

### MongoDB

| Параметр | Описание | Значение по умолчанию |
|----------|----------|----------------------|
| `mongodb.enabled` | Включить MongoDB | `true` |
| `mongodb.replicaCount` | Количество реплик | `1` |
| `mongodb.persistence.size` | Размер PV | `10Gi` |
| `mongodb.env.initDbDatabase` | Имя БД | `shipments_db` |

### Redis

| Параметр | Описание | Значение по умолчанию |
|----------|----------|----------------------|
| `redis.enabled` | Включить Redis | `true` |
| `redis.replicaCount` | Количество реплик | `1` |
| `redis.persistence.size` | Размер PV | `5Gi` |

### Kafka

| Параметр | Описание | Значение по умолчанию |
|----------|----------|----------------------|
| `kafka.enabled` | Включить Kafka | `true` |
| `kafka.replicaCount` | Количество реплик | `1` |
| `kafka.persistence.size` | Размер PV | `10Gi` |
| `kafka.env.topic` | Kafka topic | `order.created` |

### RabbitMQ

| Параметр | Описание | Значение по умолчанию |
|----------|----------|----------------------|
| `rabbitmq.enabled` | Включить RabbitMQ | `true` |
| `rabbitmq.replicaCount` | Количество реплик | `1` |
| `rabbitmq.persistence.size` | Размер PV | `5Gi` |
| `rabbitmq.env.queue` | Имя очереди | `shipment.ready` |

### Ingress

| Параметр | Описание | Значение по умолчанию |
|----------|----------|----------------------|
| `ingress.enabled` | Включить Ingress | `true` |
| `ingress.ingressClassName` | Ingress class | `nginx` |
| `ingress.hosts[0].host` | Hostname | `app.local` |

### Vault

| Параметр | Описание | Значение по умолчанию |
|----------|----------|----------------------|
| `vault.enabled` | Включить Vault CSI | `true` |
| `vault.address` | Адрес Vault | `http://vault-vault.vault.svc.cluster.local:8200` |
| `vault.role` | Vault роль | `application-order-role` |

## Примеры использования

### Установка с кастомными значениями

```bash
# Создайте файл my-values.yaml
cat <<EOF > my-values.yaml
app:
  image:
    repository: myregistry/order-app
    tag: "2.0.0"
  replicaCount: 3

ingress:
  hosts:
    - host: order-app.example.com
      paths:
        - path: /
          pathType: Prefix

mongodb:
  persistence:
    size: 20Gi

kafka:
  persistence:
    size: 20Gi
EOF

# Установите с кастомными значениями
helm install order-app . -n dev -f my-values.yaml
```

### Обновление release

```bash
# Обновите values.yaml и выполните
helm upgrade order-app . -n dev

# Или с новым values файлом
helm upgrade order-app . -n dev -f my-values.yaml
```

### Откат к предыдущей версии

```bash
# Посмотрите историю
helm history order-app -n dev

# Откатитесь к предыдущей версии
helm rollback order-app -n dev

# Или к конкретной ревизии
helm rollback order-app 2 -n dev
```

### Удаление

```bash
# Удалить release
helm uninstall order-app -n dev

# Удалить PVC (опционально)
kubectl delete pvc -n dev -l app.kubernetes.io/instance=order-app

# Удалить PV (опционально)
kubectl delete pv mongodb-pv redis-pv kafka-pv zookeeper-pv rabbitmq-pv

# Удалить данные на хосте (опционально)
sudo rm -rf /opt/order-app-data
```

## Отключение компонентов

Вы можете отключить любой компонент, установив `enabled: false`:

```yaml
# Отключить Kafka
kafka:
  enabled: false

# Отключить RabbitMQ
rabbitmq:
  enabled: false

# Отключить Vault CSI
vault:
  enabled: false

# Отключить Ingress
ingress:
  enabled: false
```

## Доступ к приложению

### Через Ingress

После установки добавьте запись в `/etc/hosts`:

```bash
# Получите IP Ingress Controller
kubectl get svc -n ingress-nginx ingress-nginx-controller

# Добавьте в /etc/hosts
echo "<EXTERNAL-IP> app.local" | sudo tee -a /etc/hosts

# Проверьте доступ
curl http://app.local/api/v1/health
```

### Через Port Forward

```bash
# Forward порт сервиса
kubectl port-forward -n dev svc/order-app 8080:8080

# Тестируйте в другом терминале
curl http://localhost:8080/api/v1/health
```

## Мониторинг и логи

### Просмотр логов

```bash
# Логи приложения
kubectl logs -n dev -l app=order-app -f

# Логи конкретного пода
kubectl logs -n dev order-app-<pod-hash> -f

# Логи всех компонентов
kubectl logs -n dev -l app.kubernetes.io/instance=order-app -f --all-containers
```

### Проверка health endpoints

```bash
# Health check
curl http://app.local/api/v1/health

# Prometheus метрики
curl http://app.local/metrics
```

### Проверка статуса компонентов

```bash
# Все ресурсы
kubectl get all -n dev

# Pods с деталями
kubectl get pods -n dev -o wide

# Services
kubectl get svc -n dev

# Ingress
kubectl get ingress -n dev

# PVC
kubectl get pvc -n dev

# PV
kubectl get pv | grep order-app
```

## Troubleshooting

### Проблема: Поды в Pending

```bash
# Проверьте события
kubectl get events -n dev --sort-by='.lastTimestamp'

# Проверьте PVC
kubectl get pvc -n dev

# Проверьте describe пода
kubectl describe pod <pod-name> -n dev
```

**Решение**: Убедитесь что PV созданы и директория `/opt/order-app-data` существует на хосте.

### Проблема: Приложение не может подключиться к Vault

```bash
# Проверьте SecretProviderClass
kubectl describe secretproviderclass -n dev

# Проверьте ServiceAccount
kubectl get sa -n dev

# Проверьте логи CSI driver
kubectl logs -n kube-system -l app=secrets-store-csi-driver
```

**Решение**: Убедитесь что Vault настроен правильно и роль `application-order-role` создана.

### Проблема: Kafka не запускается

```bash
# Проверьте что Zookeeper работает
kubectl exec -n dev zookeeper-0 -- nc -z localhost 2181

# Проверьте логи Kafka
kubectl logs -n dev kafka-0 --tail=50
```

**Решение**: Kafka зависит от Zookeeper. Убедитесь что Zookeeper запущен и healthy.

### Проблема: Ingress не работает

```bash
# Проверьте Ingress
kubectl get ingress -n dev
kubectl describe ingress -n dev

# Проверьте endpoints
kubectl get endpoints order-app -n dev

# Проверьте Ingress Controller
kubectl get pods -n ingress-nginx
```

**Решение**: Убедитесь что Nginx Ingress Controller установлен и Service имеет активные endpoints.

## Структура Chart

```
order-app/
├── Chart.yaml                      # Метаданные chart
├── values.yaml                     # Значения по умолчанию
├── templates/
│   ├── _helpers.tpl               # Helper функции
│   ├── namespace.yaml             # Namespace
│   ├── persistent-volumes.yaml    # PersistentVolumes
│   ├── persistent-volume-claims.yaml  # PVC
│   ├── zookeeper.yaml            # Zookeeper StatefulSet + Service
│   ├── kafka.yaml                # Kafka StatefulSet + Service
│   ├── mongodb.yaml              # MongoDB StatefulSet + Service
│   ├── redis.yaml                # Redis StatefulSet + Service
│   ├── rabbitmq.yaml             # RabbitMQ StatefulSet + Service
│   ├── vault.yaml                # ServiceAccount + SecretProviderClass
│   ├── deployment.yaml           # App Deployment + Service
│   └── ingress.yaml              # Ingress
└── README.md                      # Эта документация
```

## Безопасность

### Best Practices

1. **Используйте приватный Docker registry** для production
2. **Настройте Network Policies** для ограничения трафика между подами
3. **Используйте сильные пароли** для RabbitMQ и MongoDB
4. **Включите TLS** для Ingress в production
5. **Настройте RBAC** с минимальными правами
6. **Регулярно обновляйте** образы компонентов

### Пример Network Policy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: order-app-netpol
  namespace: dev
spec:
  podSelector:
    matchLabels:
      app: order-app
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector: {}
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: mongodb
    - to:
        - podSelector:
            matchLabels:
              app: redis
    - to:
        - podSelector:
            matchLabels:
              app: kafka
    - to:
        - podSelector:
            matchLabels:
              app: rabbitmq
```

## Поддержка

Для вопросов и проблем создавайте issue в репозитории проекта.

## Лицензия

MIT
