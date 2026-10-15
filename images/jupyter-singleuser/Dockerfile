# Custom JupyterHub single-user image for the medallion EDA + modeling
# stage. Based on pyspark-notebook (Spark 4.2.0 / Hadoop 3.5.0 / Java 21,
# with pandas + pyarrow), plus S3A jars so Spark reads RustFS over s3a://,
# the S3/EDA Python libs, and the starter notebooks.
FROM quay.io/jupyter/pyspark-notebook:spark-4.2.0

# S3A support for Spark. The bundled Spark has NO aws/s3a jars, so we add
# them. hadoop-aws MUST match the bundled Hadoop (3.5.0), which pulls:
#   - AWS SDK v2 bundle 2.35.4            (aws-java-sdk-v2.version)
#   - analyticsaccelerator-s3 1.3.1       (amazon-s3-analyticsaccelerator-s3.version)
# Hadoop 3.5.0 references the analytics-accelerator classes unconditionally
# (stream factory AND the request-audit path), so that jar is required even
# when we force the classic input stream. Versions resolved from the Hadoop
# parent POM; baked in for reproducible, offline-at-runtime S3 access.
USER root
RUN cd "${SPARK_HOME}/jars" && \
    curl -fsSLO https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.5.0/hadoop-aws-3.5.0.jar && \
    curl -fsSLO https://repo1.maven.org/maven2/software/amazon/awssdk/bundle/2.35.4/bundle-2.35.4.jar && \
    curl -fsSLO https://repo1.maven.org/maven2/software/amazon/s3/analyticsaccelerator/analyticsaccelerator-s3/1.3.1/analyticsaccelerator-s3-1.3.1.jar && \
    chown "${NB_UID}:${NB_GID}" hadoop-aws-3.5.0.jar bundle-2.35.4.jar analyticsaccelerator-s3-1.3.1.jar
USER ${NB_UID}

# S3 + EDA + MLflow Python libs.
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt

# Starter notebooks -> /opt/examples (copied into each user's home by a
# postStart hook in the JupyterHub values; see k8s/jupyterhub/values.yaml).
COPY --chown=${NB_UID}:${NB_GID} examples/ /opt/examples/
