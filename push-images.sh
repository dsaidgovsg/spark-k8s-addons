#!/usr/bin/env bash
set -euo pipefail

docker login -u="${DOCKER_USERNAME}" -p="${DOCKER_PASSWORD}"

IMAGE_NAME=${IMAGE_NAME:-spark-k8s-addons}

TAG_NAME="${SELF_VERSION}_${SPARK_VERSION}_hadoop-${HADOOP_VERSION}_scala-${SCALA_VERSION}"
docker tag "${IMAGE_NAME}:${TAG_NAME}" "${DOCKER_USERNAME}/${IMAGE_NAME}:${TAG_NAME}"
docker push "${DOCKER_USERNAME}/${IMAGE_NAME}:${TAG_NAME}"

ALT_TAG_NAME="${SPARK_VERSION}_hadoop-${HADOOP_VERSION}"
docker tag "${IMAGE_NAME}:${TAG_NAME}" "${DOCKER_USERNAME}/${IMAGE_NAME}:${ALT_TAG_NAME}"
docker push "${DOCKER_USERNAME}/${IMAGE_NAME}:${ALT_TAG_NAME}"
