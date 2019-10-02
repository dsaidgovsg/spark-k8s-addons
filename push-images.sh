#!/usr/bin/env bash
set -euo pipefail

docker login -u="${DOCKER_USERNAME}" -p="${DOCKER_PASSWORD}"

TAG_NAME="${SPARK_VERSION}_hadoop-${HADOOP_VERSION}"

docker tag "${IMAGE_NAME}:${TAG_NAME}" "${DOCKER_USERNAME}/${IMAGE_NAME}:${TAG_NAME}"
docker push "${DOCKER_USERNAME}/${IMAGE_NAME}:${TAG_NAME}"
