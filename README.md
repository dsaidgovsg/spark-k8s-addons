# `spark-k8s-addons`

Dockerfile setup to install cloud related utilities onto the standard Spark K8s
Docker images.

The Spark K8s Docker images are built using
[this repository](https://github.com/guangie88/spark-k8s).

## Additional Utilities

### JARs

The following JARs are added onto the original K8s Docker images:

- AWS Hadoop SDK JAR
  - Appends `spark.hadoop.fs.s3a.impl org.apache.hadoop.fs.s3a.S3AFileSystem`
    into `spark-defaults.conf`
- Google Cloud Storage SDK JAR
- MariaDB JDBC Connector JAR

### Others

Both Python3 and `aws-iam-authenticator` are installed, so that AWS user can
easily perform the Kubernetes authentication set-up.

Additionally, all Alpine builds have `gcompat` and `libc6-compat` installed to
prevent `glibc` shared library related issues.

## Spark Configuration

### AWS S3A Client

In your Spark application configuration, to use AWS S3A client JAR, do the
following:

```bash
echo "spark.hadoop.fs.s3a.impl  org.apache.hadoop.fs.s3a.S3AFileSystem" >> ${SPARK_HOME}/conf/spark-defaults.conf; \
```

If you are using `spark-shell` or `spark-submit`, then you can add the above as
a flag instead:

```bash
spark-shell --conf "spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem"
```
