#! /bin/bash
set -xe
sudo cp -rf sausage-store-backend.service /etc/systemd/system/sausage-store-backend.service
sudo rm -f /home/jarservice/sausage-store.jar || true
sudo rm -f /opt/sausage-store/bin/sausage-store-0.0.1-SNAPSHOT.jar || true
curl -L -u ${NEXUS_REPO_USER}:${NEXUS_REPO_PASS} -o sausage-store.jar ${NEXUS_REPO_URL}/com/yandex/practicum/devops/sausage-store/${VERSION}/sausage-store-${VERSION}.jar
sudo cp ./sausage-store.jar /opt/sausage-store/bin/sausage-store-0.0.1-SNAPSHOT.jar
sudo systemctl daemon-reload
sudo systemctl restart sausage-store-backend.service