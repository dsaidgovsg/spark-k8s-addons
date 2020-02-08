# `spark-k8s-addons`

![CI Status](https://img.shields.io/github/workflow/status/guangie88/spark-k8s-addons/CI/master?label=CI&logo=github&style=for-the-badge)

CI Dockerfile setup to install cloud related utilities onto the standard Spark
K8s Docker images.

The Spark K8s Docker images are built using
[this repository](https://github.com/guangie88/spark-k8s).

Note that the images here are Debian based because of how the official script
generates the Spark-Kubernetes images.

## Add-ons

### User `spark`

A more human-friendly `spark` username has been added at UID 185, which is the
default UID dictated by the official Spark-Kubernetes Docker image build.

### CLIs

The following command-line tools have been added onto the original K8s Docker
images:

- Miniconda3 (i.e. `conda` command)
  - This specially uses the compiled and linked variants found
    [here](https://repo.anaconda.com/pkgs/misc/conda-execs/), so that upgrading
    Python in deriving images will not affect `conda` command itself. This does
    not require any preset Python version to run `conda` as a result. The set-up
    also generally assumes to never perform `conda activate` so that the
    deriving images do not need to worry which environment to install to.
    However, do note that the user has to be `root` instead of `spark` to
    install anything from `conda`. `conda install` always installs into the
    default `conda` environment, as defined by `CONDA_PREFIX` environment
    variable.
- [AWS CLI](https://aws.amazon.com/cli/) installed via `conda`. Since `aws` CLI
  requires Python, this forces a certain version of Python to be installed into
  the default `conda` environment, but the Python version is left unspecified.
  (Though we generally try to pick the lowest possible Python version for
  easier Python version upgrade in deriving images).
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

For Linux user, you can download Tera CLI v0.3 at
<https://github.com/guangie88/tera-cli/releases> and place it in `PATH`.

Otherwise, you will need `cargo`, which can be installed via
[rustup](https://rustup.rs/).

Once `cargo` is installed, simply run `cargo install tera-cli --version=^0.3.0`.
