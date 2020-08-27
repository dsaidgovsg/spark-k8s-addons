# While it might make sense to start from `dsaidgovsg/spark-k8s-py` instead,
# it is easier to just COPY over from the above image just the python directory
# to avoid having to remove pip stuff, since we are using conda here

ARG BASE_VERSION="v2"
ARG SPARK_VERSION
ARG HADOOP_VERSION
ARG SCALA_VERSION

# For copying of pyspark + py4j only
FROM dsaidgovsg/spark-k8s-py:${BASE_VERSION}_${SPARK_VERSION}_hadoop-${HADOOP_VERSION}_scala-${SCALA_VERSION} as pybase

# Base image
FROM dsaidgovsg/spark-k8s:${BASE_VERSION}_${SPARK_VERSION}_hadoop-${HADOOP_VERSION}_scala-${SCALA_VERSION}

ARG PY4J_SRC

COPY --from=pybase "${SPARK_HOME}/python" "${SPARK_HOME}/python"
ENV PYTHONPATH="${SPARK_HOME}/python/lib/pyspark.zip:${PY4J_SRC}"

ARG HADOOP_VERSION
ARG PYTHON_VERSION

USER root
SHELL ["/bin/bash", "-c"]

# Install curl for to get external deps
RUN set -euo pipefail && \
    apt-get update; \
    apt-get install -y --no-install-recommends curl ca-certificates git; \
    # The installation of pyenv uses curl, so cannot use wget
    curl https://pyenv.run | bash; \
    apt-get remove -y git; \
    rm -rf /var/lib/apt/lists/*; \
    printf '\n\
eval "$(pyenv init -)"\n\
eval "$(pyenv virtualenv-init -)"\n' >> /etc/bash.bashrc; \
    :

# We took some of the PATH created by the above two evals since they are
# necessary PATHs to locate python and pip for Docker build
ENV PATH="/root/.pyenv/plugins/pyenv-virtualenv/shims:/root/.pyenv/shims:/root/.pyenv/bin:${SPARK_HOME}/bin:${PATH}"

# Python runtime + build requirements
RUN set -euo pipefail && \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        gcc make openssl \
        libc6-dev \
        xz-utils \
        openssl libssl-dev \
        zlib1g zlib1g-dev \
        libbz2-1.0 libbz2-dev \
        libreadline7 libreadline-dev \
        libsqlite3-0 libsqlite3-dev \
        libffi6 libffi-dev \
        tk tk-dev \
        liblzma5 liblzma-dev \
        libncurses6 libncurses5-dev \
        libncursesw6 libncursesw5-dev \
        ; \
    # Find the latest patch version from given Python version with up to minor
    # This cheats a bit because given PYTHON_VERSION=3.6 in regex, the dot can
    # represent other stuff other than ., but in practice this doesn't matter
    PYTHON_XYZ_VERSION="$(pyenv install --list | awk '{$1=$1};1' | grep -wE "^${PYTHON_VERSION}\.[[:digit:]]+$" | sort -rV | head -n 1)"; \
    pyenv install "${PYTHON_XYZ_VERSION}"; \
    pyenv global "${PYTHON_XYZ_VERSION}"; \
    apt-get remove -y \
        libssl-dev \
        zlib1g-dev \
        libbz2-dev \
        libreadline-dev \
        libsqlite3-dev \
        libffi-dev \
        tk-dev \
        liblzma-dev \
        libncurses5-dev \
        libncursesw5-dev \
        ; \
    apt-get autoremove -y; \
    rm -rf /var/lib/apt/lists/*; \
    :

RUN set -euo pipefail && \
    # AWS S3 JAR
    cd ${SPARK_HOME}/jars; \
    ## Get the aws-java-sdk version dynamic based on Hadoop version
    ## Do not use head -n1 because it will trigger 141 exit code due to early return on pipe
    AWS_JAVA_SDK_VERSION="$(curl -L https://raw.githubusercontent.com/apache/hadoop/branch-${HADOOP_VERSION}/hadoop-project/pom.xml | grep -A1 aws-java-sdk | grep -oE "[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+" | tr "\r\n" " " | cut -d " " -f 1)"; \
    ## Download the JAR
    curl -LO https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_VERSION}/hadoop-aws-${HADOOP_VERSION}.jar; \
    curl -LO https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/${AWS_JAVA_SDK_VERSION}/aws-java-sdk-bundle-${AWS_JAVA_SDK_VERSION}.jar; \
    # AWS IAM Authenticator
    curl -LO https://amazon-eks.s3-us-west-2.amazonaws.com/1.13.7/2019-06-11/bin/linux/amd64/aws-iam-authenticator; \
    chmod +x aws-iam-authenticator; \
    mv aws-iam-authenticator /usr/local/bin/; \
    # AWS CLI
    pip install --no-cache-dir awscli; \
    # Google Storage JAR
    curl -LO https://storage.googleapis.com/hadoop-lib/gcs/gcs-connector-hadoop2-latest.jar; \
    # MariaDB connector JAR
    curl -LO https://downloads.mariadb.com/Connectors/java/connector-java-2.4.0/mariadb-java-client-2.4.0.jar; \
    # Postgres JDBC JAR
    curl -LO https://jdbc.postgresql.org/download/postgresql-42.2.9.jar; \
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
