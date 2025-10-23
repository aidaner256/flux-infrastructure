# Order App Helm Charts

## Компоненты

Helm chart развертывает следующие компоненты:

| Компонент | Версия | Тип | Описание |
|-----------|--------|-----|----------|
| Order App | v1.0.1 | Deployment | Go микросервис для управления заказами |
| Order Service Py | v1.0.5 | Deployment | Python микросервис для заказов (FastAPI) |
| MongoDB | 7-jammy | StatefulSet | База данных для хранения shipments |
| Redis | 7-alpine | StatefulSet | Кеширование данных (30 секунд TTL) |
| Kafka | 7.5.0 | StatefulSet | Потребление событий `order.created` |
| Zookeeper | 7.5.0 | StatefulSet | Координация для Kafka |
| RabbitMQ | 3.12 | StatefulSet | Публикация событий `shipment.ready` |
| Vault CSI | - | CSI Driver | Управление секретами через CSI Driver |
| Nginx Ingress | - | Ingress | Внешний доступ к приложениям (app.local, app-py.local) |

## Основные возможности

- Полностью параметризованная конфигурация через `values.yaml`
- Поддержка single-node и multi-node кластеров
- Интеграция с HashiCorp Vault для управления секретами
- PersistentVolumes для всех stateful компонентов
- Настраиваемые resource limits и requests
- Health checks и readiness probes
- Возможность включения/отключения любого компонента
- Ingress для внешнего доступа

## Требования

- Kubernetes 1.20+
- Helm 3.0+
- Nginx Ingress Controller
- HashiCorp Vault с CSI Driver
- StorageClass (local-storage для single-node)

## Примеры использования

### Базовая установка

```bash
helm install order-app ./order-app -n dev --create-namespace
```

### Установка с кастомными values

```bash
helm install order-app ./order-app -n dev --create-namespace -f my-values.yaml
```

### Обновление

```bash
helm upgrade order-app ./order-app -n dev -f my-values.yaml
```

### Удаление

```bash
helm uninstall order-app -n dev
```

## Конфигурация

### Основные параметры

```yaml
# Namespace
global:
  namespace: dev

# Образ приложения
app:
  image:
    repository: your-registry/order-app
    tag: "1.0.2"
  replicaCount: 1

# Ingress
ingress:
  enabled: true
  hosts:
    - host: app.local

# Включение/отключение компонентов
mongodb:
  enabled: true
redis:
  enabled: true
kafka:
  enabled: true
rabbitmq:
  enabled: true
vault:
  enabled: true
```

## Архитектура

```
┌──────────────────────────────────────────────────────────────────────┐
│                          Namespace: dev                              │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌────────────────┐              ┌────────────────┐                 │
│  │  Order App     │◄─────────────│  Vault CSI     │                 │
│  │  (Go - v1.0.1) │              │  Secrets       │                 │
│  │  Deployment    │              └────────────────┘                 │
│  │  Port: 8080    │                      ▲                           │
│  └────────┬───────┘                      │                           │
│           ▲                              │                           │
│           │                              │                           │
│  ┌────────┴────────┐        ┌────────────┴────────┐                 │
│  │  Ingress        │        │ Order Service Py    │                 │
│  │  app.local      │        │ (Python - v1.0.5)   │                 │
│  │  (nginx)        │        │ Deployment          │                 │
│  └─────────────────┘        │ Port: 8000          │                 │
│                              └──────────┬──────────┘                 │
│                                         │                            │
│                              ┌──────────┴──────────┐                 │
│                              │  Ingress            │                 │
│                              │  app-py.local       │                 │
│                              │  (nginx)            │                 │
│                              └─────────────────────┘                 │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    Infrastructure Layer                       │   │
│  ├──────────────────────────────────────────────────────────────┤   │
│  │                                                                │   │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐              │   │
│  │  │  MongoDB   │  │   Redis    │  │  RabbitMQ  │              │   │
│  │  │ StatefulSet│  │ StatefulSet│  │ StatefulSet│              │   │
│  │  │  Port:     │  │  Port:     │  │  Ports:    │              │   │
│  │  │  27017     │  │  6379      │  │  5672      │              │   │
│  │  │            │  │            │  │  15672     │              │   │
│  │  │  PVC: 10Gi │  │  PVC: 5Gi  │  │  PVC: 5Gi  │              │   │
│  │  └────────────┘  └────────────┘  └────────────┘              │   │
│  │                                                                │   │
│  │  ┌────────────┐                  ┌────────────┐              │   │
│  │  │  Kafka     │◄─────────────────│ Zookeeper  │              │   │
│  │  │ StatefulSet│   coordination   │ StatefulSet│              │   │
│  │  │  Ports:    │                  │  Port:     │              │   │
│  │  │  9092      │                  │  2181      │              │   │
│  │  │  29092     │                  │            │              │   │
│  │  │  PVC: 10Gi │                  │  PVC: 5Gi  │              │   │
│  │  └────────────┘                  └────────────┘              │   │
│  │                                                                │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │            Persistent Volumes (hostPath)                      │   │
│  │            /opt/order-app-data/{mongodb,redis,kafka,...}      │   │
│  │            StorageClass: local-storage                        │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  ServiceAccounts & SecretProviderClasses                      │   │
│  │  - order-app-sa → vault-order-app                            │   │
│  │  - order-service-py-sa → vault-order-service-py              │   │
│  │  - mongodb-sa → vault-secret-mongodb                         │   │
│  │  - rabbitmq-sa → vault-secret-rabbitmq                       │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘

Data Flow:
-----------
1. Order App (Go)      → MongoDB + Redis + RabbitMQ + Kafka
2. Order Service (Py)  → PostgreSQL + Redis + Kafka
3. Kafka ↔ Zookeeper   (coordination)
4. All services ↔ Vault CSI (secrets management)
```

## Сравнение с basic манифестами

| Аспект | Basic (kubectl) | Helm |
|--------|----------------|------|
| Установка | Поэтапно, множество файлов | Одна команда |
| Конфигурация | Редактирование YAML файлов | values.yaml |
| Обновление | Ручное применение манифестов | helm upgrade |
| Откат | Нет встроенной поддержки | helm rollback |
| Версионирование | Нет | Автоматически |
| Переиспользование | Низкое | Высокое |
| Параметризация | Низкая | Высокая |
| CI/CD интеграция | Сложнее | Проще |

## Troubleshooting

### Проверка chart

```bash
# Валидация синтаксиса
helm lint ./order-app

# Dry-run
helm install order-app ./order-app --dry-run --debug -n dev

# Показать сгенерированные манифесты
helm template order-app ./order-app -n dev
```

### Отладка установки

```bash
# Статус release
helm status order-app -n dev

# История изменений
helm history order-app -n dev

# Текущие values
helm get values order-app -n dev

# Все манифесты release
helm get manifest order-app -n dev
```

### Проблемы с компонентами

```bash
# Проверка подов
kubectl get pods -n dev

# Логи
kubectl logs -n dev <pod-name> -f

# События
kubectl get events -n dev --sort-by='.lastTimestamp'

# Описание пода
kubectl describe pod <pod-name> -n dev
```

## Best Practices

1. **Используйте кастомный values файл** вместо редактирования values.yaml напрямую
2. **Версионируйте values файлы** в системе контроля версий
3. **Используйте разные values** для разных окружений (dev, staging, prod)
4. **Проверяйте chart** с помощью `helm lint` и `helm template` перед установкой
5. **Делайте backup values** перед обновлением
6. **Используйте dry-run** при тестировании изменений
7. **Мониторьте ресурсы** после установки
8. **Регулярно обновляйте** образы компонентов

## Дополнительные ресурсы

- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [Vault CSI Provider](https://github.com/hashicorp/vault-csi-provider)

## Поддержка

Для вопросов и проблем:
1. Проверьте [INSTALL.md](INSTALL.md)
2. Проверьте [order-app/README.md](order-app/README.md)
3. Создайте issue в репозитории проекта

## Лицензия

MIT
