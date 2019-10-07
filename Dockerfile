# While it might make sense to start from `guangie88/spark-k8s-py` instead,
# it is easier to just COPY over from the above image just the python directory
# to avoid having to remove pip stuff, since we are using conda here
ARG FROM_DOCKER_IMAGE="guangie88/spark-k8s"
ARG FROM_PY_DOCKER_IMAGE="guangie88/spark-k8s-py"
ARG SPARK_VERSION=
ARG HADOOP_VERSION=

# For copying of pyspark + py4j only
FROM ${FROM_PY_DOCKER_IMAGE}:${SPARK_VERSION}_hadoop-${HADOOP_VERSION} as pybase

# Base image
FROM ${FROM_DOCKER_IMAGE}:${SPARK_VERSION}_hadoop-${HADOOP_VERSION}

COPY --from=pybase "${SPARK_HOME}/python" "${SPARK_HOME}/python"
ENV PYTHONPATH="${SPARK_HOME}/python/lib/pyspark.zip:${SPARK_HOME}/python/lib/py4j-*.zip"

ARG HADOOP_VERSION=

# The miniconda version doesn't matter much because
# it is just a means to create an environment with your required Python packages
ARG CONDA_HOME=/opt/conda
ENV CONDA_HOME="${CONDA_HOME}"

# We pick 4.5 because it is just before the major change to conda init and also
# downgrading and upgrading Python is easy at this version on the base env
ARG MINICONDA3_VERSION=4.5.12

# The glibc version for Alpine doesn't matter much either
# as long as all the symbols we need are there
ARG ALPINE_GLIBC_VERSION=2.30
ENV ALPINE_GLIBC_VERSION=${ALPINE_GLIBC_VERSION}

USER root

RUN set -euo pipefail && \
    # Install conda to enable downstream to create Python environment
    ## conda needs working glibc and bash
    apk add --no-cache bash ca-certificates; \
    wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub; \
    ## Delete known conflicting packages first
    apk del libc6-compat; \
    wget "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${ALPINE_GLIBC_VERSION}-r0/glibc-${ALPINE_GLIBC_VERSION}-r0.apk"; \
    wget "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${ALPINE_GLIBC_VERSION}-r0/glibc-bin-${ALPINE_GLIBC_VERSION}-r0.apk"; \
    wget "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${ALPINE_GLIBC_VERSION}-r0/glibc-i18n-${ALPINE_GLIBC_VERSION}-r0.apk"; \
    apk add "glibc-${ALPINE_GLIBC_VERSION}-r0.apk" "glibc-bin-${ALPINE_GLIBC_VERSION}-r0.apk" "glibc-i18n-${ALPINE_GLIBC_VERSION}-r0.apk"; \
    rm "glibc-${ALPINE_GLIBC_VERSION}-r0.apk" "glibc-bin-${ALPINE_GLIBC_VERSION}-r0.apk" "glibc-i18n-${ALPINE_GLIBC_VERSION}-r0.apk"; \
    ## Finally install conda
    wget "https://repo.continuum.io/miniconda/Miniconda3-${MINICONDA3_VERSION}-Linux-x86_64.sh"; \
    bash "Miniconda3-${MINICONDA3_VERSION}-Linux-x86_64.sh" -b -p "${CONDA_HOME}"; \
    rm "Miniconda3-${MINICONDA3_VERSION}-Linux-x86_64.sh"; \
    # Version 4.5 and below does not require the below line
    # "${CONDA_HOME}/bin/conda" init bash; \
    :

ENV PATH="${PATH}:${SPARK_HOME}/bin:${CONDA_HOME}/bin"

RUN set -euo pipefail && \
    # apt requirements
    apk add --no-cache \
        curl \
        ; \
    # AWS S3 JAR
    cd ${SPARK_HOME}/jars; \
    ## Get the aws-java-sdk version dynamic based on Hadoop version
    ## Do not use head -n1 because it will trigger 141 exit code due to early return on pipe
    AWS_JAVA_SDK_VERSION="$(curl -s https://raw.githubusercontent.com/apache/hadoop/branch-${HADOOP_VERSION}/hadoop-project/pom.xml | grep -A1 aws-java-sdk | grep -oE "[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+" | tr "\r\n" " " | cut -d " " -f 1)"; \
    ## Download the JAR
    wget http://central.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_VERSION}/hadoop-aws-${HADOOP_VERSION}.jar; \
    wget https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/${AWS_JAVA_SDK_VERSION}/aws-java-sdk-bundle-${AWS_JAVA_SDK_VERSION}.jar; \
    # AWS IAM Authenticator
    wget https://amazon-eks.s3-us-west-2.amazonaws.com/1.13.7/2019-06-11/bin/linux/amd64/aws-iam-authenticator; \
    chmod +x aws-iam-authenticator; \
    mv aws-iam-authenticator /usr/local/bin/; \
    # AWS CLI
    conda config --add channels conda-forge; \
    conda install awscli; \
    conda clean -a -y; \
    # Google Storage JAR
    wget https://storage.googleapis.com/hadoop-lib/gcs/gcs-connector-hadoop2-latest.jar; \
    # MariaDB connector JAR
    wget https://downloads.mariadb.com/Connectors/java/connector-java-2.4.0/mariadb-java-client-2.4.0.jar; \
    cd -; \
    # apt clean-up
    apk del \
        curl \
        ; \
    :

# See https://github.com/apache/spark/blob/master/docs/running-on-kubernetes.md#user-identity
## Restore back the original UID
ARG SPARK_USER=spark
ARG SPARK_USER_UID=185

# Create proper username and home for it so that there is a default place to house the conda config
# This will not affect the original spark-k8s set-up
RUN set -euo pipefail && \
    adduser --disabled-password --gecos "" -u ${SPARK_USER_UID} ${SPARK_USER}; \
    :

USER ${SPARK_USER}
# Version 3
# RUN conda init bash
SHELL ["/bin/bash", "-c"]
