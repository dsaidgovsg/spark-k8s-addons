#!/usr/bin/env bash
set -euo pipefail

DOCKER_IMAGE=${DOCKER_IMAGE:-guangie88/spark-k8s-addons}
docker login -u="${DOCKER_USERNAME}" -p="${DOCKER_PASSWORD}"
docker push "${DOCKER_IMAGE}:${SPARK_VERSION}_hadoop-${HADOOP}"
