# `spark-k8s-addons`

![CI Status](https://img.shields.io/github/workflow/status/dsaidgovsg/spark-k8s-addons/CI/master?label=CI&logo=github&style=for-the-badge)

CI Dockerfile setup to install cloud related utilities onto the standard Spark
K8s Docker images.

The Spark K8s Docker images are built using
[this repository](https://github.com/dsaidgovsg/spark-k8s).

Note that the images here are Debian based because of how the official script
generates the Spark-Kubernetes images.

## Add-ons

### User `spark`

A more human-friendly `spark` username has been added at UID 185, which is the
default UID dictated by the official Spark-Kubernetes Docker image build.

### CLIs

The following command-line tools have been added onto the original K8s Docker
images:

- [`pyenv`](https://github.com/pyenv/pyenv) to easily get the specific Python
  major.minor version installed and be set as the global version. Every CI build
  from this repository will cause the Python version to take the latest patch
  version.
- [AWS CLI](https://aws.amazon.com/cli/) installed via `pip` using the same
  Python version set globally by `pyenv`.
- [AWS IAM Authenticator](https://github.com/kubernetes-sigs/aws-iam-authenticator)
  This is a Go statically linked binary, so this does not interact with any of
  the above said items.

### JARs

The following JARs have been added onto the original K8s Docker images:

- AWS Hadoop SDK JAR
  - Appends `spark.hadoop.fs.s3a.impl org.apache.hadoop.fs.s3a.S3AFileSystem`
    into `spark-defaults.conf`
- Google Cloud Storage SDK JAR
- MariaDB JDBC Connector JAR

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

## How to Apply Template for CI build

For Linux user, you can download Tera CLI v0.4 at
<https://github.com/guangie88/tera-cli/releases> and place it in `PATH`.

Otherwise, you will need `cargo`, which can be installed via
[rustup](https://rustup.rs/).

Once `cargo` is installed, simply run `cargo install tera-cli --version=^0.4.0`.
