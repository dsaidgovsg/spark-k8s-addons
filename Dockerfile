# Current k8s built image is always Debian buster based
ARG BASE_VERSION="v3"
ARG SPARK_VERSION
ARG HADOOP_VERSION
ARG SCALA_VERSION
ARG JAVA_VERSION
ARG PYTHON_VERSION
ARG IMAGE_VERSION

# For copying over of Python set-up
FROM python:${PYTHON_VERSION}${IMAGE_VERSION} as python_base

# While it might make sense to start from `dsaidgovsg/spark-k8s-py` instead,
# it is easier to just COPY over from the above image just the python directory
# to avoid having to remove pip stuff, since we are using conda here

# For copying of pyspark + py4j only
FROM dsaidgovsg/spark-k8s-py:${BASE_VERSION}_${SPARK_VERSION}_hadoop-${HADOOP_VERSION}_scala-${SCALA_VERSION}_java-${JAVA_VERSION} as pybase

# Base image
FROM dsaidgovsg/spark-k8s:${BASE_VERSION}_${SPARK_VERSION}_hadoop-${HADOOP_VERSION}_scala-${SCALA_VERSION}_java-${JAVA_VERSION}

COPY --from=pybase "${SPARK_HOME}/python" "${SPARK_HOME}/python"
ENV PATH="${PATH}:${SPARK_HOME}/bin"
ENV PYTHONPATH="${SPARK_HOME}/python/lib/pyspark.zip:${SPARK_HOME}/python/lib/py4j.zip"

ARG HADOOP_VERSION
ARG PYTHON_VERSION
ARG IMAGE_VERSION

USER root
SHELL ["/bin/bash", "-c"]

# Install Python by copying over from matching Debian distribution for building
COPY --from=python_base /usr/local /usr/local
RUN set -euo pipefail && \
    # Ensure constant path for py4j for env purposes
    ln -rs /opt/spark/python/lib/py4j-*.zip /opt/spark/python/lib/py4j.zip; \
    # Test added PATH works
    spark-shell --version; \
    pyspark --version; \
    # Required extra deps
    if [ "${IMAGE_VERSION}" = "-buster" ]; then \
        export LIBREADLINE_VERSION=7 ; \
    else \
        export LIBREADLINE_VERSION=8 ; \
    fi ; \
    apt-get update && apt-get install --no-install-recommends -y libexpat1 libreadline"${LIBREADLINE_VERSION}" tk; \
    rm -rf /var/lib/apt/lists/*; \
    ldconfig; \
    # Test every command to return non-error status code for help
    find /usr/local/bin -type f -perm /u=x,g=x,o=x -print0 | xargs -0 -I {} bash -c "{} --help || {} -h" >/dev/null 2>&1; \
    # Test python works and can be found in PATH
    python --version; \
    # Test PYTHONPATH libraries works
    python -c "import pyspark, py4j"; \
    :

# Install curl for to get external deps
RUN set -euo pipefail && \
    apt-get update; \
    apt-get install -y --no-install-recommends curl ca-certificates; \
    rm -rf /var/lib/apt/lists/*; \
    :

# Set up poetry to do proper global pip dependency management
ENV POETRY_HOME=/opt/poetry
ENV POETRY_VIRTUALENVS_CREATE=false
ENV POETRY_SYSTEM_PROJECT_DIR="${POETRY_HOME}/.system"
ENV PATH="${POETRY_HOME}/bin:${PATH}"
RUN set -euo pipefail && \
    curl -sSL https://install.python-poetry.org | python3 -; \
    $POETRY_HOME/bin/poetry --version; \
    mkdir -p "${POETRY_SYSTEM_PROJECT_DIR}"; \
    cd "${POETRY_SYSTEM_PROJECT_DIR}"; \
    $POETRY_HOME/bin/poetry init -n --name system; \
    $POETRY_HOME/bin/poetry config virtualenvs.create false; \
    :

RUN set -euo pipefail && \
    # AWS S3 JAR
    pushd ${SPARK_HOME}/jars; \
    ## Get the aws-java-sdk version dynamic based on Hadoop version
    ## Do not use head -n1 because it will trigger 141 exit code due to early return on pipe
    AWS_JAVA_SDK_VERSION="$(curl -L https://raw.githubusercontent.com/apache/hadoop/branch-${HADOOP_VERSION}/hadoop-project/pom.xml | grep -A1 aws-java-sdk | grep -oE "[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+" | tr "\r\n" " " | cut -d " " -f 1)"; \
    ## Download the JAR
    curl -LO https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_VERSION}/hadoop-aws-${HADOOP_VERSION}.jar; \
    HADOOP_MAJOR_VERSION="$(echo "${HADOOP_VERSION}" | cut -d '.' -f1)"; \
    if [[ ${HADOOP_MAJOR_VERSION} -lt 3 ]]; then \
        # Version of AWS_JAVA_SDK_VERSION is expected out of range for the bundled build
        # So fetch the original non-bundled build
        # Only ion-java is missing from the bundle:
        # https://github.com/aws/aws-sdk-java/blob/1.11.375/aws-java-sdk-bundle/pom.xml
        # So just download the latest version for it
        ION_JAVA_VERSION=1.5.1; \
        curl -LO https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk/${AWS_JAVA_SDK_VERSION}/aws-java-sdk-${AWS_JAVA_SDK_VERSION}.jar; \
        curl -LO https://repo1.maven.org/maven2/software/amazon/ion/ion-java/${ION_JAVA_VERSION}/ion-java-${ION_JAVA_VERSION}.jar; \
    else \
        curl -LO https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/${AWS_JAVA_SDK_VERSION}/aws-java-sdk-bundle-${AWS_JAVA_SDK_VERSION}.jar; \
    fi; \
    # AWS IAM Authenticator
    curl -LO https://amazon-eks.s3-us-west-2.amazonaws.com/1.13.7/2019-06-11/bin/linux/amd64/aws-iam-authenticator; \
    chmod +x aws-iam-authenticator; \
    mv aws-iam-authenticator /usr/local/bin/; \
    # AWS CLI
    pushd "${POETRY_SYSTEM_PROJECT_DIR}"; \
    $POETRY_HOME/bin/poetry add awscli; \
    popd; \
    # Google Storage JAR
    curl -LO https://storage.googleapis.com/hadoop-lib/gcs/gcs-connector-hadoop2-latest.jar; \
    # MariaDB connector JAR
    curl -LO https://downloads.mariadb.com/Connectors/java/connector-java-2.4.0/mariadb-java-client-2.4.0.jar; \
    # Postgres JDBC JAR
    curl -LO https://jdbc.postgresql.org/download/postgresql-42.2.9.jar; \
    popd; \
    :

# See https://github.com/apache/spark/blob/master/docs/running-on-kubernetes.md#user-identity
## Restore back the original UID
ARG SPARK_USER=spark
ARG SPARK_USER_UID=185

# Create proper username and home for it so that there is a default place to house the conda config
# This will not affect the original spark-k8s set-up
RUN set -euo pipefail && \
    adduser --disabled-password --gecos "" -u "${SPARK_USER_UID}" "${SPARK_USER}"; \
    # Amend the work-dir, which is a scratch space for running Spark to be usable by group `spark`
    chown root:spark "${SPARK_HOME}/work-dir"; \
    # And force group write for older 2.4.z versions that is contained within >= 3.y.z
    # https://github.com/apache/spark/blob/v3.0.1/resource-managers/kubernetes/docker/src/main/dockerfiles/spark/Dockerfile#L56
    chmod g+w "${SPARK_HOME}/work-dir"; \
    # Also create the default SPARK_LOG_DIR and usable as 'spark' user in case the image is used in
    # non-k8s settings and tries to create and write into this dir
    mkdir -p "${SPARK_HOME}/logs"; \
    chown root:spark "${SPARK_HOME}/logs"; \
    chmod g+w "${SPARK_HOME}/logs"; \
    :

USER ${SPARK_USER}
