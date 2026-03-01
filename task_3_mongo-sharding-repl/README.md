# Развёртывание кластера MongoDB с шардингом и репликацией

Ниже представлена последовательность действий для поэтапной настройки кластера. Такой формат позволяет контролировать состояние системы на каждом этапе.
При необходимости можно воспользоваться [скриптом](run.sh), который выполняет базовую автоматическую настройку.

---

* **Запуск контейнеров инфраструктуры**

  ```bash
  docker compose up -d
  ```

---

* **Инициализация конфигурационного replica set**

  ```bash
  docker exec -it config_srv mongosh --port 27021
  rs.status();

  rs.initiate(
    {
      _id : "config_server",
      configsvr: true,
      members: [
        { _id : 0, host : "config_srv:27021" }
      ]
    }
  );
  rs.status();
  exit();
  ```

---

* **Создание replica set для первого шарда**

  ```bash
  docker exec -it shard1_repl1 mongosh --port 27022
  rs.status();
  rs.initiate(
      {
        _id : "shard1",
        members: [
          { _id : 0, host : "shard1_repl1:27022" },
          { _id : 1, host : "shard1_repl2:27023" },
          { _id : 2, host : "shard1_repl3:27024" }
        ]
      }
  );
  rs.status();
  exit();
  ```

---

* **Создание replica set для второго шарда**

  ```bash
  docker exec -it shard2_repl1 mongosh --port 27025
  rs.status();
  rs.initiate(
      {
        _id : "shard2",
        members: [
          { _id : 0, host : "shard2_repl1:27025" },
          { _id : 1, host : "shard2_repl2:27026" },
          { _id : 2, host : "shard2_repl3:27027" }
        ]
      }
  );
  rs.status();
  exit();
  ```

---

* **Подключение шардов к маршрутизатору и активация шардинга**

  ```bash
  docker exec -it mongos_router mongosh --port 27020

  sh.status();
  sh.addShard("shard1/shard1_repl1:27022");
  sh.addShard("shard2/shard2_repl1:27025");
  sh.status();

  sh.status();
  sh.enableSharding("somedb");
  sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } );
  sh.status();
  exit();
  ```

---

* **Добавление тестовых записей в коллекцию**

  ```bash
  docker exec -it mongos_router mongosh --port 27020

  use somedb
  print("Documents count: " + db.helloDoc.countDocuments());
  for(var i = 0; i < 1000; i++) {
      db.helloDoc.insert({age:i, name:"ly"+i});
  }
  print("Documents count: " + db.helloDoc.countDocuments());
  exit();
  ```

---

* **Проверка распределения данных между шардами и их репликами**

  ```bash
  docker exec -it shard1_repl1 mongosh -port 27022
  use somedb;
  db.helloDoc.countDocuments();
  db.helloDoc.distinct("name");
  exit();

  docker exec -it shard1_repl2 mongosh -port 27023
  use somedb;
  db.helloDoc.countDocuments();
  db.helloDoc.distinct("name");
  exit();

  docker exec -it shard1_repl3 mongosh -port 27024
  use somedb;
  db.helloDoc.countDocuments();
  db.helloDoc.distinct("name");
  exit();

  docker exec -it shard2_repl1 mongosh -port 27025
  use somedb;
  db.helloDoc.countDocuments();
  db.helloDoc.distinct("name");
  exit();

  docker exec -it shard2_repl2 mongosh -port 27026
  use somedb;
  db.helloDoc.countDocuments();
  db.helloDoc.distinct("name");
  exit();

  docker exec -it shard2_repl3 mongosh -port 27027
  use somedb;
  db.helloDoc.countDocuments();
  db.helloDoc.distinct("name");
  exit();
  ```

---

* **Остановка окружения и удаление всех данных**

  ```bash
  docker-compose down -v
  ```