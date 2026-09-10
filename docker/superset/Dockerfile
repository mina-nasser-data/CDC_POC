FROM apache/superset:6.0.0

USER root

RUN uv pip install --python /app/.venv/bin/python \
    psycopg2-binary \
    sqlalchemy-risingwave==1.0.0

# Compatibility patch: Superset 6 passes `connection=`,
# while sqlalchemy-risingwave 1.0.0 expects `conn`.
RUN python -c "p='/app/.venv/lib/python3.10/site-packages/sqlalchemy_risingwave/base.py'; s=open(p).read(); s=s.replace('def get_view_names(self, conn, schema=None, **kw):', 'def get_view_names(self, connection, schema=None, **kw):').replace('rows = conn.execute(text(sql))', 'rows = connection.execute(text(sql))'); open(p,'w').write(s)"

COPY superset_config.py /app/pythonpath/superset_config.py

USER superset