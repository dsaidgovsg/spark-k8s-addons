ARG FROM_DOCKER_IMAGE="guangie88/spark-k8s"
ARG SPARK_VERSION=
ARG HADOOP_VERSION=

FROM ${FROM_DOCKER_IMAGE}:${SPARK_VERSION}_hadoop-${HADOOP_VERSION}

ARG HADOOP_VERSION=
ARG AWS_JAVA_SDK_VERSION=

RUN set -euo pipefail && \
    # apt requirements
    apk add --no-cache \
        curl \
        ; \
    # AWS S3 JAR
    cd ${SPARK_HOME}/jars; \
    curl -LO http://central.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_VERSION}/hadoop-aws-${HADOOP_VERSION}.jar; \
    curl -LO https://sdk-for-java.amazonwebservices.com/aws-java-sdk-${AWS_JAVA_SDK_VERSION}.zip; \
        unzip -qq aws-java-sdk-${AWS_JAVA_SDK_VERSION}.zip; \
        find aws-java-sdk-${AWS_JAVA_SDK_VERSION} -name "*.jar" -exec mv {} ${SPARK_HOME}/jars/ \; ; \
        rm -r ./aws-java-sdk-${AWS_JAVA_SDK_VERSION}; \
        rm ./aws-java-sdk-${AWS_JAVA_SDK_VERSION}.zip; \
    # AWS IAM Authenticator with AWS CLI
    # apk add --no-cache \
    #     python3 \
    #     ; \
    # curl -o aws-iam-authenticator https://amazon-eks.s3-us-west-2.amazonaws.com/1.13.7/2019-06-11/bin/linux/amd64/aws-iam-authenticator; \
    # chmod +x aws-iam-authenticator; \
    # mv aws-iam-authenticator /usr/local/bin/; \
    # python3 -m pip install setuptools; \
    # python3 -m pip install awscli; \
    # Google Storage JAR
    curl -LO https://storage.googleapis.com/hadoop-lib/gcs/gcs-connector-hadoop2-latest.jar; \
    # MariaDB connector JAR
    curl -LO https://downloads.mariadb.com/Connectors/java/connector-java-2.4.0/mariadb-java-client-2.4.0.jar; \
    cd -; \
    # Required for prevent snappy compression error because the shared lib is dependent on glibc
    apk add --no-cache gcompat libc6-compat; \
    # apt clean-up
    apk del \
        curl \
        ; \
    :
