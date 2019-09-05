# `spark-k8s-addons`

[![Build Status](https://travis-ci.org/guangie88/spark-k8s-addons.svg?branch=master)](https://travis-ci.org/guangie88/spark-k8s-addons)

Dockerfile setup to install cloud related utilities onto the standard Spark K8s
Docker images.

The Spark K8s Docker images are built using
[this repository](https://github.com/guangie88/spark-k8s).

Note that the images here are naturally Alpine based because of how the official
script generates the Spark-Kubernetes images.

## Additional Utilities

### JARs

The following JARs are added onto the original K8s Docker images:

- Miniconda3 (i.e. `conda` command)
  - No guarantee of which exact Python 3 version, since the intent is to allow
    `conda` to create new environments with any Python version of the user's
    liking in the downstream Docker images
- [AWS CLI](https://aws.amazon.com/cli/) installed via `conda`
- [AWS IAM Authenticator](https://github.com/kubernetes-sigs/aws-iam-authenticator)
- AWS Hadoop SDK JAR
  - Appends `spark.hadoop.fs.s3a.impl org.apache.hadoop.fs.s3a.S3AFileSystem`
    into `spark-defaults.conf`
- Google Cloud Storage SDK JAR
- MariaDB JDBC Connector JAR

Additionally, the image is patched with `glibc` from
<https://github.com/sgerrand/alpine-pkg-glibc/>, required by `conda` and also to
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

## How to Apply Travis Template

For Linux user, you can download Tera CLI v0.2 at
<https://github.com/guangie88/tera-cli/releases> and place it in `PATH`.

Otherwise, you will need `cargo`, which can be installed via
[rustup](https://rustup.rs/).

Once `cargo` is installed, simply run `cargo install tera-cli --version=^0.2.0`.
