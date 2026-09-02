# Golden Dataset — Collections Analytics

8 golden (cleaned, deduplicated, entity-resolved) tables exported as Parquet
from `collections_analytics.duckdb`. Full derivation, forensics, and
cleaning logic is in `01_data_engineering_and_forensics.ipynb`.

| File | Rows | Primary Key | Notes |
|---|---|---|---|
| golden_payments.parquet | 25,000 | payment_id | Deduped from 25,500 raw (500 exact re-ingestion duplicates removed) |
| golden_calls.parquet | 90,000 | call_id | Deduped from 91,350 raw; timestamps normalized to UTC |
| golden_agents.parquet | 1,000 | agent_id | Collapsed from 30,000 noisy snapshot rows (latest per agent_id) |
| golden_borrowers.parquet | 11,015 | borrower_id | Collapsed from 30,600 noisy snapshot rows (latest per borrower_id) |
| golden_accounts.parquet | 30,000 | account_id | Source of truth for borrower_id resolution; timestamps normalized to UTC |
| golden_promises_to_pay.parquet | 18,000 | ptp_id | borrower_id resolved via account_id (raw borrower_id was ~98% unreliable) |
| golden_whatsapp_events.parquet | 60,000 | whatsapp_event_id | Deduped on true PK |
| golden_account_status_history.parquet | 60,000 | history_id | Kept as full append-only log — no dedup (genuine status transitions, not noise) |

## Regenerating

Run `01_data_engineering_and_forensics.ipynb` top to bottom against the raw
CSVs to rebuild `collections_analytics.duckdb` from scratch, or load these
Parquet files directly:

```python
import duckdb
con = duckdb.connect()
con.execute("CREATE TABLE golden_payments AS SELECT * FROM 'golden_payments.parquet'")
```

or in pandas:
```python
import pandas as pd
df = pd.read_parquet('golden_payments.parquet')
```
