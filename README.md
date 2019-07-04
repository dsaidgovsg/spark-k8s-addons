# spark-k8s-addons
Dockerfile setup to install cloud related utilities onto the standard Spark K8s Docker images

echo "spark.hadoop.fs.s3a.impl    org.apache.hadoop.fs.s3a.S3AFileSystem" >> ${SPARK_HOME}/conf/spark-defaults.conf; \
