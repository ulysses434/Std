#!/bin/bash
set -xe

echo "${CI_REGISTRY_PASSWORD}" | sudo docker login -u "${CI_REGISTRY_USER}" --password-stdin "${CI_REGISTRY}"

sudo docker network create -d bridge sausage_network || true

sudo docker rm -f sausage-backend || true

sudo docker run -d --name sausage-backend \
     --restart=always \
     --network=sausage_network \
     -e SPRING_DATASOURCE_URL="${SPRING_DATASOURCE_URL}" \
     -e SPRING_DATASOURCE_USERNAME="${SPRING_DATASOURCE_USERNAME}" \
     -e SPRING_DATASOURCE_PASSWORD="${SPRING_DATASOURCE_PASSWORD}" \
     -e SPRING_DATA_MONGODB_URI="${SPRING_DATA_MONGODB_URI}" \
     -v /home/student/.postgresql/root.crt:/app/postgres.crt:ro \
     -v /home/student/.mongodb/root.crt:/app/root.crt:ro \
     "${CI_REGISTRY_IMAGE}"/sausage-backend:${VERSION}
