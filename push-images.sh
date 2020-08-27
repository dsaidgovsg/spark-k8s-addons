#!/usr/bin/env bash
set -euo pipefail

echo "${DOCKER_PASSWORD}" | docker login -u="${DOCKER_USERNAME}" --password-stdin

IMAGE_NAME=${IMAGE_NAME:-spark-k8s-addons}

TAG_NAME="${SELF_VERSION}_${SPARK_VERSION}_hadoop-${HADOOP_VERSION}_scala-${SCALA_VERSION}_python-${PYTHON_VERSION}"
docker tag "${IMAGE_NAME}:${TAG_NAME}" "${IMAGE_ORG}/${IMAGE_NAME}:${TAG_NAME}"
docker push "${IMAGE_ORG}/${IMAGE_NAME}:${TAG_NAME}"

ALT_TAG_NAME="${SPARK_VERSION}_hadoop-${HADOOP_VERSION}"
docker tag "${IMAGE_NAME}:${TAG_NAME}" "${IMAGE_ORG}/${IMAGE_NAME}:${ALT_TAG_NAME}"
docker push "${IMAGE_ORG}/${IMAGE_NAME}:${ALT_TAG_NAME}"
