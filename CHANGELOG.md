# CHANGELOG

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
