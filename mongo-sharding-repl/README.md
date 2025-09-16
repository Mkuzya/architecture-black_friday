# MongoDB Sharding + Replication Setup

## Как запустить

1. Запускаем все сервисы:
```shell
docker compose up -d
```

2. Ждем запуска всех контейнеров (около 60 секунд):
```shell
docker compose ps
```

3. Инициализируем конфигурационный сервер:
```shell
docker compose exec -T configSrv mongosh --port 27017 --quiet <<EOF
rs.initiate({
  _id: "configReplSet",
  configsvr: true,
  members: [
    { _id: 0, host: "configSrv:27017" }
  ]
})
EOF
```

4. Инициализируем репликационные наборы для шардов:
```shell
# Шард 1 (3 реплики)
docker compose exec -T shard1-1 mongosh --port 27017 --quiet <<EOF
rs.initiate({
  _id: "shard1ReplSet",
  members: [
    { _id: 0, host: "shard1-1:27017" },
    { _id: 1, host: "shard1-2:27017" },
    { _id: 2, host: "shard1-3:27017" }
  ]
})
EOF

# Шард 2 (3 реплики)
docker compose exec -T shard2-1 mongosh --port 27017 --quiet <<EOF
rs.initiate({
  _id: "shard2ReplSet",
  members: [
    { _id: 0, host: "shard2-1:27017" },
    { _id: 1, host: "shard2-2:27017" },
    { _id: 2, host: "shard2-3:27017" }
  ]
})
EOF
```

5. Добавляем шарды в кластер:
```shell
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
sh.addShard("shard1ReplSet/shard1-1:27017,shard1-2:27017,shard1-3:27017")
sh.addShard("shard2ReplSet/shard2-1:27017,shard2-2:27017,shard2-3:27017")
EOF
```

6. Включаем шардирование для базы данных:
```shell
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
sh.enableSharding("somedb")
EOF
```

7. Настраиваем шардирование для коллекции (по полю age):
```shell
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
sh.shardCollection("somedb.helloDoc", { "age": 1 })
EOF
```

8. Заполняем данными:
```shell
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
use somedb
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i})
EOF
```

## Как проверить

1. Откройте в браузере http://localhost:8080

2. Проверьте статус шардирования:
```shell
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
sh.status()
EOF
```

3. Проверьте статус репликации для шарда 1:
```shell
docker compose exec -T shard1-1 mongosh --port 27017 --quiet <<EOF
rs.status()
EOF
```

4. Проверьте статус репликации для шарда 2:
```shell
docker compose exec -T shard2-1 mongosh --port 27017 --quiet <<EOF
rs.status()
EOF
```

5. Проверьте количество документов:
```shell
# Общее количество
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

# В шарде 1
docker compose exec -T shard1-1 mongosh --port 27017 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

# В шарде 2
docker compose exec -T shard2-1 mongosh --port 27017 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

6. Проверьте количество реплик:
```shell
# Количество реплик в шарде 1
docker compose exec -T shard1-1 mongosh --port 27017 --quiet <<EOF
rs.status().members.length
EOF

# Количество реплик в шарде 2
docker compose exec -T shard2-1 mongosh --port 27017 --quiet <<EOF
rs.status().members.length
EOF
```

## Доступные эндпоинты

- http://localhost:8080 - основное приложение
- http://localhost:8080/docs - документация API

## Автоматическая инициализация

Для автоматической инициализации используйте скрипт:
```shell
./scripts/init-sharding-repl.sh
```