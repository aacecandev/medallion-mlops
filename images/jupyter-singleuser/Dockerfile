# Custom JupyterHub single-user image for the medallion EDA stage.
# Bakes in the data/S3 libraries (no more %pip install in notebooks) and
# ships the starter notebooks. Base is pinned to an immutable dated tag.
FROM quay.io/jupyter/minimal-notebook:2026-10-12

# Data + S3 libraries.
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt && \
    fix-permissions "${CONDA_DIR}"

# Starter notebooks. These go to /opt/examples (NOT /home/jovyan, which
# is shadowed by the per-user PVC at runtime). A postStart hook in the
# JupyterHub values copies them into each user's home on first start, so
# they land editable without clobbering later edits.
COPY --chown=${NB_UID}:${NB_GID} examples/ /opt/examples/
