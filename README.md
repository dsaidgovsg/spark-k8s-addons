# `spark-k8s-addons`

![CI Status](https://img.shields.io/github/workflow/status/dsaidgovsg/spark-k8s-addons/CI/master?label=CI&logo=github&style=for-the-badge)

CI Dockerfile setup to install cloud related utilities onto the standard Spark
K8s Docker images.

The Spark K8s Docker images are built using
[this repository](https://github.com/dsaidgovsg/spark-k8s).

Note that the images here are Debian based because of how the official script
generates the Spark-Kubernetes images.

## How to build

```bash
BASE_VERSION=v2
SPARK_VERSION=3.0.1
HADOOP_VERSION=3.2.0
SCALA_VERSION=2.12
PYTHON_VERSION=3.8

docker pull dsaidgovsg/spark-k8s-py:${BASE_VERSION}_${SPARK_VERSION}_hadoop-${HADOOP_VERSION}_scala-${SCALA_VERSION}
PY4J_SRC="$(docker run --rm -t --entrypoint sh "dsaidgovsg/spark-k8s-py:${BASE_VERSION}_${SPARK_VERSION}_hadoop-${HADOOP_VERSION}_scala-${SCALA_VERSION}" -c 'ls --color=never ${SPARK_HOME}/python/lib/py4j-*.zip' | tr -d "\r\n")"

IMAGE_NAME=spark-k8s-addons
docker build -t "${IMAGE_NAME}" \
    --build-arg BASE_VERSION="${BASE_VERSION}" \
    --build-arg SPARK_VERSION="${SPARK_VERSION}" \
    --build-arg HADOOP_VERSION="${HADOOP_VERSION}" \
    --build-arg SCALA_VERSION="${SCALA_VERSION}" \
    --build-arg PYTHON_VERSION="${PYTHON_VERSION}" \
    --build-arg PY4J_SRC="${PY4J_SRC}" \
    .
```

## How to properly manage `pip` packages

Since raw `pip` is terrible at managing installation of dependencies in a
version compatible across multiple `pip` install sessions, `poetry` has been
installed in a system wide manner (whose directory to contain `pyproject.toml`
is the value of the env var `POETRY_SYSTEM_PROJECT_DIR`).

All `pip` installation is recommended to go through via `poetry` completely, and
this can be done like this:

```bash
pushd "${POETRY_SYSTEM_PROJECT_DIR}"
poetry add <package1> [<other packages to add>]
popd
```

## Add-ons

### User `spark`

A more human-friendly `spark` username has been added at UID 185, which is the
default UID dictated by the official Spark-Kubernetes Docker image build.

### CLIs

The following command-line tools have been added onto the original K8s Docker
images:

- [`poetry`](https://python-poetry.org/) to properly manage pip installation
- [AWS CLI](https://aws.amazon.com/cli/) installed via `poetry`
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
