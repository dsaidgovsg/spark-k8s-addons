# CHANGELOG

## v5

- Use non-versioned constant path for `py4j import.
- Build only for 3.1.3, 3.2.2, 3.3.0 and 3.3.1, and their related supported Hadoop
  variants (dropped all 2.y.z versions).
- Change base image version to `v3`.

## v4

- Add support up to 3.1.1 for Spark 3.y.z.
- Drop 2.4.5 and 2.4.6 and only support 2.4.7 as the last supported
  2.4.z version.
- Remove `pyenv` and use native Python only. `pip` installation is recommended
  to be managed by `poetry`.
- Change group of `/opt/spark/work-dir` to be `spark` instead of `root`.
- Ensure `/opt/spark/work-dir` to be have mode `g+w` for all built versions.

## v3

- Remove `conda` and switch to multiple Python builds managed by `pyenv`.

## v2

- `CONDA_PREFIX` is the default prefix to contain all `conda install` bins and
  libs. `PATH` is prepended with `${CONDA_PREFIX}/bin` so that the executables
  in this default Conda prefix will take precedence.
- Switch to Debian base set-up due to official change in Kubernetes Docker base
  image used.

## v1

- Set locale for Alpine to `en_US.utf8`.
- Add Postgres JDBC JAR.
- Basic setup for Spark 2.4.4 from `v1`
  [`spark-k8s`](https://github.com/guangie88/spark-k8s).
