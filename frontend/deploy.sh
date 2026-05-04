#!/bin/bash
set -xe

echo "${CI_REGISTRY_PASSWORD}" | sudo docker login -u "${CI_REGISTRY_USER}" --password-stdin "${CI_REGISTRY}"

sudo docker network create -d bridge sausage_network || true

sudo docker rm -f sausage-frontend || true

sudo docker run -d --name sausage-frontend \
     --restart=always \
     -p 80:80 \
     -v /tmp/frontend_config/default.conf:/etc/nginx/conf.d/default.conf:ro \
     --network=sausage_network \
     "${CI_REGISTRY_IMAGE}"/sausage-frontend:latest