# While it might make sense to start from `guangie88/spark-k8s-py` instead,
# it is easier to just COPY over from the above image just the python directory
# to avoid having to remove pip stuff, since we are using conda here

ARG BASE_VERSION="v2"
ARG SPARK_VERSION
ARG HADOOP_VERSION
ARG SCALA_VERSION

# For copying of pyspark + py4j only
FROM guangie88/spark-k8s-py:${BASE_VERSION}_${SPARK_VERSION}_hadoop-${HADOOP_VERSION}_scala-${SCALA_VERSION} as pybase

# Base image
FROM guangie88/spark-k8s:${BASE_VERSION}_${SPARK_VERSION}_hadoop-${HADOOP_VERSION}_scala-${SCALA_VERSION}

ARG PY4J_SRC

COPY --from=pybase "${SPARK_HOME}/python" "${SPARK_HOME}/python"
ENV PYTHONPATH="${SPARK_HOME}/python/lib/pyspark.zip:${PY4J_SRC}"

ARG HADOOP_VERSION

# This directory will hold all the default bins and libs installed via conda
ARG CONDA_HOME=/opt/conda
ENV CONDA_HOME="${CONDA_HOME}"
ARG CONDA_PREFIX=/opt/conda/default
ENV CONDA_PREFIX="${CONDA_PREFIX}"

# The conda3 version shouldn't matter much, can just take the latest
ARG MINICONDA3_VERSION="py38_4.8.2"

USER root

# Install wget for to get external deps
RUN set -euo pipefail && \
    apt-get update; \
    apt-get install -y wget; \
    rm -rf /var/lib/apt/lists/*; \
    :

RUN set -euo pipefail && \
    ## Install conda via installer
    wget "https://repo.continuum.io/miniconda/Miniconda3-${MINICONDA3_VERSION}-Linux-x86_64.sh"; \
    bash "Miniconda3-${MINICONDA3_VERSION}-Linux-x86_64.sh" -b -p "${CONDA_HOME}"; \
    rm "Miniconda3-${MINICONDA3_VERSION}-Linux-x86_64.sh"; \
    ## Create the basic configuration for installation later
    ## Do not put any packages in create because this seems to pin the packages to the given versions
    ## Use conda install for that instead
    "${CONDA_HOME}/bin/conda" config --add channels conda-forge; \
    "${CONDA_HOME}/bin/conda" create -y -p "${CONDA_PREFIX}"; \
    "${CONDA_HOME}/bin/conda" clean -a -y; \
    :

# We set conda with higher precedence on purpose here to handle all Python
# related packages over the system package manager
ENV PATH="${CONDA_PREFIX}/bin:${CONDA_HOME}/bin:${SPARK_HOME}/bin:${PATH}"

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
    ## We use the earliest possible version of Python 3 so that the deriving image
    ## can easily upgrade the Python version later on
    ## We simply drop support for Python 2 because it is often not possible for conda to resolve the
    ## version dependencies later on
    conda install -y -p "${CONDA_PREFIX}" python=3.4 awscli; \
    conda clean -a -y; \
    # Google Storage JAR
    wget https://storage.googleapis.com/hadoop-lib/gcs/gcs-connector-hadoop2-latest.jar; \
    # MariaDB connector JAR
    wget https://downloads.mariadb.com/Connectors/java/connector-java-2.4.0/mariadb-java-client-2.4.0.jar; \
    # Postgres JDBC JAR
    wget https://jdbc.postgresql.org/download/postgresql-42.2.9.jar; \
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
SHELL ["/bin/bash", "-c"]
