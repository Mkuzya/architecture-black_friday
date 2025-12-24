#!/bin/bash

echo "Инициализация MongoDB Sharding..."

# Ждем запуска всех контейнеров
echo "Ожидание запуска контейнеров..."
sleep 30

# Инициализируем конфигурационный сервер
echo "Инициализация конфигурационного сервера..."
docker compose exec -T configSrv mongosh --port 27017 --quiet <<EOF
rs.initiate({
  _id: "configReplSet",
  configsvr: true,
  members: [
    { _id: 0, host: "configSrv:27017" }
  ]
})
EOF

sleep 10

# Инициализируем репликационные наборы для шардов
echo "Инициализация шарда 1..."
docker compose exec -T shard1 mongosh --port 27017 --quiet <<EOF
rs.initiate({
  _id: "shard1ReplSet",
  members: [
    { _id: 0, host: "shard1:27017" }
  ]
})
EOF

echo "Инициализация шарда 2..."
docker compose exec -T shard2 mongosh --port 27017 --quiet <<EOF
rs.initiate({
  _id: "shard2ReplSet",
  members: [
    { _id: 0, host: "shard2:27017" }
  ]
})
EOF

sleep 10

# Добавляем шарды в кластер
echo "Добавление шардов в кластер..."
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
sh.addShard("shard1ReplSet/shard1:27017")
sh.addShard("shard2ReplSet/shard2:27017")
EOF

# Включаем шардирование для базы данных
echo "Включение шардирования для базы данных..."
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
sh.enableSharding("somedb")
EOF

# Настраиваем шардирование для коллекции
echo "Настройка шардирования для коллекции..."
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
sh.shardCollection("somedb.helloDoc", { "age": 1 })
EOF

# Заполняем данными
echo "Заполнение базы данных..."
docker compose exec -T mongos mongosh --port 27017 --quiet <<EOF
use somedb
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i})
EOF

echo "Инициализация завершена!"
echo "Проверьте статус: docker compose exec -T mongos mongosh --port 27017 --quiet -c 'sh.status()'"
