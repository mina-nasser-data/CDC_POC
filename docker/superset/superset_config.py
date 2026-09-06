SQLALCHEMY_DATABASE_URI = "postgresql+psycopg2://superset:superset@superset-db:5432/superset"

SQLALCHEMY_ENGINE_OPTIONS = {
    "pool_pre_ping": True,
}