import duckdb
from pathlib import Path

base = Path(__file__).parent
sql_file = base / "sql" / "analysis.sql"

con = duckdb.connect()

sql = sql_file.read_text(encoding="utf-8")
result = con.execute(sql).fetchdf()

print(result.to_string(index=False))
