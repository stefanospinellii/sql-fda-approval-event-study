import duckdb
from pathlib import Path

base = Path(__file__).parent
sql_file = base / "sql" / "analysis.sql"
outputs_dir = base / "outputs"
outputs_dir.mkdir(exist_ok=True)

con = duckdb.connect()

sql = sql_file.read_text(encoding="utf-8")

queries = [
    ("01_overall_event_car_summary", "Query 1: Overall Event CAR Summary"),
    ("02_top_market_moving_events",
     "Query 2: Top 20 market-moving FDA approval events"),
    ("03_big_pharma_vs_biotech", "Query 3: Big Pharma vs Biotech"),
    ("04_nda_vs_bla", "Query 4: NDA vs BLA"),
    ("05_priority_vs_standard", "Query 5: Priority vs Standard Review"),
    ("06_event_window_summary", "Query 6: Event window abnormal return summary"),
]

# Split SQL into setup part and query sections
setup_sql = sql.split("-- Query 1: Overall Event CAR Summary")[0]
con.execute(setup_sql)

for i, (filename, marker) in enumerate(queries):
    start = sql.index(f"-- {marker}")
    if i + 1 < len(queries):
        next_marker = queries[i + 1][1]
        end = sql.index(f"-- {next_marker}")
        query_sql = sql[start:end]
    else:
        query_sql = sql[start:]

    result = con.execute(query_sql).fetchdf()
    output_path = outputs_dir / f"{filename}.csv"
    result.to_csv(output_path, index=False)

    print(f"\n{filename}")
    print(result.to_string(index=False))
    print(f"Saved to {output_path}")
