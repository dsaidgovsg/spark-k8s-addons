# While it might make sense to start from `guangie88/spark-k8s-py` instead,
# it is easier to just COPY over from the above image just the python directory
# to avoid having to remove pip stuff, since we are using conda here
ARG FROM_DOCKER_IMAGE="guangie88/spark-k8s"
ARG FROM_PY_DOCKER_IMAGE="guangie88/spark-k8s-py"

ARG BASE_VERSION="v1"
ARG SPARK_VERSION
ARG HADOOP_VERSION

# For copying of pyspark + py4j only
FROM ${FROM_PY_DOCKER_IMAGE}:${BASE_VERSION}_${SPARK_VERSION}_hadoop-${HADOOP_VERSION} as pybase

# Base image
FROM ${FROM_DOCKER_IMAGE}:${BASE_VERSION}_${SPARK_VERSION}_hadoop-${HADOOP_VERSION}

ARG PY4J_SRC

COPY --from=pybase "${SPARK_HOME}/python" "${SPARK_HOME}/python"
ENV PYTHONPATH="${SPARK_HOME}/python/lib/pyspark.zip:${PY4J_SRC}"

ARG HADOOP_VERSION

# This directory will hold all the bins and libs installed via conda
ARG CONDA_PREFIX=/opt/conda/default
ENV CONDA_PREFIX="${CONDA_PREFIX}"

# The conda3 version shouldn't matter much, can just take the latest
ARG MINICONDA3_VERSION=4.7.12

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
    ## We install a special compiled and linked version of conda
    ## The original .sh conda assumes preset Python version, and upgrading the
    ## base env Python version will immediately break conda
    ## Using the pre-linked conda makes the set-up completely independent from
    ## the Python version (in fact there is no default Python version to speak)
    wget "https://repo.anaconda.com/pkgs/misc/conda-execs/conda-${MINICONDA3_VERSION}-linux-64.exe"; \
    mv "conda-${MINICONDA3_VERSION}-linux-64.exe" /usr/local/bin/conda; \
    chmod +x /usr/local/bin/conda; \
    ## Create the basic configuration for installation later
    ## Note that this set-up will never activate the environment and rather
    ## globally adds to PATH so that every user can access the installed stuff
    ## without going through conda activate
    conda create -y -p "${CONDA_PREFIX}"; \
    conda config --add channels conda-forge; \
    ## Alpine's ctypes find_library is quite broken
    ## Need to directly feed the .so to the Conda directory
    :

# We set conda with higher precedence on purpose here to handle all Python
# related packages over the system package manager
ENV PATH="${CONDA_PREFIX}/bin:${PATH}:${SPARK_HOME}/bin"

RUN set -euo pipefail && \
    # AWS S3 JAR
    cd ${SPARK_HOME}/jars; \
    ## Get the aws-java-sdk version dynamic based on Hadoop version
    ## Do not use head -n1 because it will trigger 141 exit code due to early return on pipe
    AWS_JAVA_SDK_VERSION="$(wget -qO- https://raw.githubusercontent.com/apache/hadoop/branch-${HADOOP_VERSION}/hadoop-project/pom.xml | grep -A1 aws-java-sdk | grep -oE "[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+" | tr "\r\n" " " | cut -d " " -f 1)"; \
    ## Download the JAR
    wget https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_VERSION}/hadoop-aws-${HADOOP_VERSION}.jar; \
    wget https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/${AWS_JAVA_SDK_VERSION}/aws-java-sdk-bundle-${AWS_JAVA_SDK_VERSION}.jar; \
    # AWS IAM Authenticator
    wget https://amazon-eks.s3-us-west-2.amazonaws.com/1.13.7/2019-06-11/bin/linux/amd64/aws-iam-authenticator; \
    chmod +x aws-iam-authenticator; \
    mv aws-iam-authenticator /usr/local/bin/; \
    # AWS CLI
    ## We use the weakest possible version of Python so that the deriving image
    ## can easily upgrade the Python version later on
    conda install -y python=2.7 awscli; \
    conda clean -a -y; \
    ## For some reason alpine-pkg-glibc doesn't put up libc.so and libm.so as proper shared libraries
    ## So we symbolic link these against the actual shared libraries
    ## And we verify if we can find the basic libraries at the end
    find /usr/glibc-compat/lib -type f -name '*.so*' -exec ln -s {} "${CONDA_PREFIX}/lib/" \; ; \
    unlink "${CONDA_PREFIX}/lib/libc.so" && unlink "${CONDA_PREFIX}/lib/libm.so"; \
    ln -s /usr/glibc-compat/lib/libc.so.6 "${CONDA_PREFIX}/lib/libc.so"; \
    ln -s /usr/glibc-compat/lib/libm.so.6 "${CONDA_PREFIX}/lib/libm.so"; \
    python -c "from ctypes.util import find_library; exit(1) if not find_library('c') or not find_library('m') else exit(0)"; \
    # Google Storage JAR
    wget https://storage.googleapis.com/hadoop-lib/gcs/gcs-connector-hadoop2-latest.jar; \
    # MariaDB connector JAR
    wget https://downloads.mariadb.com/Connectors/java/connector-java-2.4.0/mariadb-java-client-2.4.0.jar; \
    cd -; \
    :

# See https://github.com/apache/spark/blob/master/docs/running-on-kubernetes.md#user-identity
## Restore back the original UID
ARG SPARK_USER=spark
ARG SPARK_USER_UID=185

# Create proper username and home for it so that there is a default place to house the conda config
# This will not affect the original spark-k8s set-up
RUN set -euo pipefail && \
    adduser --disabled-password --gecos "" -u "${SPARK_USER_UID}" "${SPARK_USER}"; \
    :

USER ${SPARK_USER}
# Version 3
# RUN conda init bash
SHELL ["/bin/bash", "-c"]
