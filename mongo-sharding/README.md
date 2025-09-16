# MongoDB Sharding Setup

## Как запустить

1. Запускаем все сервисы:
```shell
docker compose up -d
```

2. Ждем запуска всех контейнеров (около 30 секунд):
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
# Шард 1
docker compose exec -T shard1 mongosh --port 27017 --quiet <<EOF
rs.initiate({
  _id: "shard1ReplSet",
  members: [
    { _id: 0, host: "shard1:27017" }
  ]
})
EOF

# Шард 2
docker compose exec -T shard2 mongosh --port 27017 --quiet <<EOF
rs.initiate({
  _id: "shard2ReplSet",
  members: [
    { _id: 0, host: "shard2:27017" }
  ]
})
EOF
```

5. Добавляем шарды в кластер:
```shell
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
sh.addShard("shard1ReplSet/shard1:27017")
sh.addShard("shard2ReplSet/shard2:27017")
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

8. Заполняем исходную БД данными:
```shell
docker compose exec -T mongodb1 mongosh --port 27017 --quiet <<EOF
use somedb
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i})
EOF
```

9. Мигрируем данные из исходной БД в шардированную:
```shell
# Получаем данные из исходной БД
docker compose exec -T mongodb1 mongosh --port 27017 --quiet <<EOF
use somedb
db.helloDoc.find().forEach(function(doc) {
  print(JSON.stringify(doc));
});
EOF
```

10. Вставляем данные в шардированную БД:
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

3. Проверьте количество документов в каждом шарде:
```shell
# Общее количество
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

# В шарде 1
docker compose exec -T shard1 mongosh --port 27017 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

# В шарде 2
docker compose exec -T shard2 mongosh --port 27017 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

## Доступные эндпоинты

- http://localhost:8080 - основное приложение
- http://localhost:8080/docs - документация API