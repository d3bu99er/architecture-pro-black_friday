# Развёртывание API Gateway и механизма Service Discovery

Схема архитектуры: [drawio](arch.drawio) | [png](arch.png)

В данном разделе описан эксперимент по организации шлюза API и динамического обнаружения сервисов. Несмотря на то, что подробная инструкция не требовалась, была выполнена самостоятельная настройка и тестирование решения. Описание носит более обзорный характер.

<details>
<summary>Порядок действий</summary>

---

* **Запуск всей системы**

  ```bash
  ./run.sh
  ```

---

* **Тестирование распределения нагрузки между инстансами**

  Откройте три терминала.

  ```bash
  watch -d "docker-compose logs pymongo_api1 | tail"
  ```

  ```bash
  watch -d "docker-compose logs pymongo_api2 | tail"
  ```

  ```bash
  curl http://localhost:9080
  curl http://localhost:9080
  curl http://localhost:9080
  ```

  Результат: обращения к шлюзу должны поочерёдно обрабатываться разными экземплярами сервиса. Возможны небольшие перекосы на малом числе запросов, однако при увеличении нагрузки распределение становится равномерным.

---

* **Проверка поведения системы при отказе одного из сервисов**

  Используются три терминала.

  ```bash
  watch -d "docker-compose logs pymongo_api1 | tail"
  ```

  ```bash
  watch -d "docker-compose logs pymongo_api2 | tail"
  ```

  ```bash
  docker-compose stop pymongo_api1
  curl http://localhost:9080
  curl http://localhost:9080
  curl http://localhost:9080

  docker-compose start pymongo_api1
  docker-compose stop pymongo_api2
  curl http://localhost:9080
  curl http://localhost:9080
  curl http://localhost:9080

  docker-compose start pymongo_api2
  curl http://localhost:9080
  curl http://localhost:9080
  curl http://localhost:9080
  ```

  Ожидаемое поведение:

  * при остановке одного экземпляра весь трафик перенаправляется на оставшийся;
  * после возврата отключённого сервиса нагрузка снова делится между ними;
  * пользователю не возвращаются ошибки при переключении.

---

* **Проверка механизма Service Discovery**

  В трёх терминалах отслеживаются логи и выполняются управляющие запросы.

  ```bash
  watch -d "docker-compose logs pymongo_api1 | tail"
  ```

  ```bash
  watch -d "docker-compose logs pymongo_api2 | tail"
  ```

  ```bash
  curl -X PUT "http://localhost:8500/v1/agent/service/deregister/pymongo-api1"
  curl http://localhost:9080
  curl http://localhost:9080
  curl http://localhost:9080

  curl "http://127.0.0.1:8500/v1/agent/service/register" -X PUT \
  -H "Content-Type: application/json" \
  -d '{
    "ID": "pymongo-api1",
    "Name": "pymongo-api",
    "Tags": ["pymongo-api", "v1"],
    "Address": "'173.17.5.1'",
    "Port": 8080,
    "Weights": {
      "Passing": 10,
      "Warning": 1
    }
  }'
  curl http://localhost:9080
  curl http://localhost:9080
  curl http://localhost:9080
  ```

  Ожидаемый результат:

  * после исключения сервиса из реестра запросы направляются только на доступный экземпляр;
  * после повторной регистрации балансировка восстанавливается;
  * система корректно реагирует на динамические изменения состава сервисов.

</details>