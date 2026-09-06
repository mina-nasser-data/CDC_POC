FROM apache/superset:6.0.0

USER root

RUN uv pip install --python /app/.venv/bin/python psycopg2-binary

COPY superset_config.py /app/pythonpath/superset_config.py

USER superset