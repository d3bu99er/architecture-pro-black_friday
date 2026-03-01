# Настройка шардирования и запуск системы

Нижеприведенная последовательность команд составлена для быстрого запуска нужных сервисов. Для быстроты запуска и проверок можете воспользоваться [скриптом](run.sh).

- Создание и запуск сервиса
  ```bash
  docker compose up -d
  ```

- Настройка сервиса конфигураций
  ```bash
  docker exec -it config_srv mongosh --port 27017
  rs.status();  # MongoServerError[NotYetInitialized]: no replset config has been received

  rs.initiate(
    {
      _id : "config_server",
      configsvr: true,
      members: [
        { _id : 0, host : "config_srv:27017" }
      ]
    }
  );
  rs.status();  # replica set description with the member "config_server".
  exit();
  ```

- Настройка шардов
  ```bash
  docker exec -it shard1 mongosh --port 27018
  rs.status();  # MongoServerError[NotYetInitialized]: no replset config has been received

  rs.initiate(
      {
        _id : "shard1",
        members: [
          { _id : 0, host : "shard1:27018" },
        ]
      }
  );
  rs.status();  # replica set description with the member "shard1".
  exit();

  docker exec -it shard2 mongosh --port 27019
  rs.status();  # MongoServerError[NotYetInitialized]: no replset config has been received

  rs.initiate(
      {
        _id : "shard2",
        members: [
          { _id : 0, host : "shard2:27019" },
        ]
      }
  );
  rs.status();  # replica set description with the member "shard2".
  exit();
  ```

- Запуск и настройка роутера

  ```bash
  docker exec -it mongos_router mongosh --port 27020

  sh.status();  # Много всего, важно: "shards[]"
  sh.addShard("shard1/shard1:27018");
  sh.addShard("shard2/shard2:27019");
  sh.status();  # Много всего, важно: "shards[{shard1}, {shard2}]"

  sh.status();  # Много всего, важно: shardedDataDistribution[] и databases: ['config']
  sh.enableSharding("somedb");
  sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } );
  sh.status();  # Много всего, важно: shardedDataDistribution['somedb.helloDoc'] и databases['config', 'somedb']
  exit();
  ```

- Наполнение БД
  ```bash
  docker exec -it mongos_router mongosh --port 27020

  use somedb
  print("Documents count: " + db.helloDoc.countDocuments());  # N
  for(var i = 0; i < 1000; i++) {
      db.helloDoc.insert({age:i, name:"ly"+i});
  }
  print("Documents count: " + db.helloDoc.countDocuments());  # N + 1000
  exit();
  ```

- Проверка распределения данных по шардам (нет в [run.sh](run.sh))
  ```bash
  docker exec -it shard1 mongosh -port 27018
  use somedb;
  db.helloDoc.countDocuments();  # X1 - часть от общего количества документов в mongos_router
  exit();

  docker exec -it shard2 mongosh -port 27019
  use somedb;
  db.helloDoc.countDocuments();  # X2 - часть от общего количества документов в mongos_router
  exit();

  # X1 + X2 = N + 1000
  ```

- Для остановки и очистки volumes используйте команду
  ```bash
  docker-compose down -v
  ```