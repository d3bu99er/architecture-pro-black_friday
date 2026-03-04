#!/bin/bash

docker compose exec -T shard1_1 mongosh --port 27014 --quiet <<EOF
rs.initiate(
  {
    _id: "shard1", members: [
      {_id: 0, host: "shard1_1:27014"},
      {_id: 1, host: "shard1_2:27015"},
      {_id: 2, host: "shard1_3:27016"}
    ]
});
exit();
EOF

docker compose exec -T shard2_1 mongosh --port 27017 --quiet <<EOF
rs.initiate(
  {
    _id: "shard2", members: [
      {_id: 0, host: "shard2_1:27017"},
      {_id: 1, host: "shard2_2:27018"},
      {_id: 2, host: "shard2_3:27019"}
    ]
});
exit();
EOF

docker compose exec -T configSrv mongosh --port 27013 --quiet <<EOF
rs.initiate(
  {
    _id : "config_server",
       configsvr: true,
    members: [
      { _id : 0, host : "configSrv:27013" }
    ]
  }
);
exit();
EOF

sleep 2

docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.addShard( "shard1/shard1_1:27014");
sh.addShard( "shard1/shard1_2:27015");
sh.addShard( "shard1/shard1_3:27016");
sh.addShard( "shard2/shard2_1:27017");
sh.addShard( "shard2/shard2_2:27018");
sh.addShard( "shard2/shard2_3:27019");

sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } )

use somedb

for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i})

db.helloDoc.countDocuments()
exit();
EOF