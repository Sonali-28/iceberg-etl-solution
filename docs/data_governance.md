# Part 2 – Data Governance, Lineage & PII Masking

This document addresses **Part 2 – Data Governance** of the assignment.

The goal is to design how we would:
- Track **data lineage** across the pipeline
- Implement **data governance** (ownership, glossary, metadata)
- Handle **PII masking** in a way that still enables analytics

The implementation here is intentionally lightweight but maps directly to how a production‑grade
solution could be implemented.

## 1. Data Lineage & Governance Tooling

### 1.1. Recommended Tool

A good fit for this environment is a modern, open‑source data catalog and lineage tool such as:

- **DataHub** (LinkedIn‑origin, supports ingestion from files, data warehouses, stream systems)
- or **OpenMetadata** (similar scope, strong lineage & quality integrations)

Either one provides:

- Automated ingestion of metadata about:
  - Datasets (e.g. `customer_data`, `sales_data`)
  - Pipelines / jobs (e.g. *Jobber ETL* in this repo)
  - Downstream analytics tables (e.g. `enriched_sales`, `agg_sales_by_customer`, etc.)
- Column‑level metadata and ownership
- Search, discovery, and documentation (business glossary, tags, owners)
- Lineage graphs showing how data flows from raw sources to final tables

### 1.2. How Lineage Would Be Captured

At a high level:

1. **Source ingestion**
   - Register `customer_data.parquet` and `sales_data.csv` as *source datasets* in the catalog.
   - Attach metadata such as:
     - Source location (e.g. S3 path, GCS bucket, or local path)
     - Owner team (e.g. *Data Engineering*)
     - Data classification (e.g. PII present / not present)

2. **Pipeline metadata**
   - Register the ETL pipeline (this repo) as an *ingestion job* or *data pipeline* in DataHub/OpenMetadata.
   - Use an integration (e.g., DataHub’s Airflow or CLI emitter) from the ETL job to push lineage events:
     - Input datasets: `customer_data`, `sales_data`
     - Output datasets: `enriched_sales`, `agg_sales_by_customer`,
       `agg_sales_by_mall_category`, `agg_daily_sales`
   - Each run of the pipeline emits a run‑event linked to those datasets.

3. **Downstream consumption**
   - Any BI dashboards or ML models that use these tables also publish their dependencies
     (e.g., a Power BI or Looker connector reporting that a dashboard reads from `agg_sales_by_mall_category`).
   - This creates a full lineage path:
     `raw sources -> enriched/aggregates -> dashboards/models`.

4. **Governance**
   - Use the catalog to:
     - Define **data owners** and **stewards** for each dataset.
     - Document schema, data types, and business definitions.
     - Apply tags (e.g., `pii`, `customer_profile`, `fact_table`).
     - Attach SLAs and quality expectations.

In this project, we would embed a small metadata‑emitter step at the end of `main.py` that, in a real
environment, pushes lineage events to the chosen catalog.

## 2. PII Masking Strategy

The `customer_data` source is likely to contain PII (e.g. names, emails, phone numbers, address details).
`sales_data` mainly contains transactional information, but the **`customer_id`** column itself is often treated
as a *quasi‑identifier*.

### 2.1. PII Classification

Typical PII fields in the customer dataset might include:

- Direct identifiers:
  - Full name
  - Email address
  - Phone number
  - Exact street address
- Quasi‑identifiers:
  - Precise date of birth
  - Exact postal code
  - Customer ID if it can be mapped back to a specific person externally

For internal analytics, most use‑cases do **not** need direct identifiers – they only need
**segmented or aggregated behaviour** (e.g., spend by age bucket, region, segment).

### 2.2. Masking / Anonymisation Techniques

For this pipeline, we could implement the following approach when producing **analytics‑ready** tables:

- **Tokenisation / hashing of `customer_id`:**
  - Replace the raw `customer_id` with a cryptographically secure hash or token in analytics tables.
  - Keep the mapping in a highly restricted, separate key‑mapping table accessible only to authorised services.

- **Dropping or redacting direct identifiers:**
  - Columns like name, email, phone should **not** appear in `enriched_sales` or aggregates used by general analysts.
  - Either drop them entirely in the transformation, or replace with static tokens like `"REDACTED"`.

- **Generalisation of granular attributes:**
  - Instead of exact date of birth, expose only age bands (e.g. `18–25`, `26–35`, etc.).
  - Instead of full address, keep only city / region / country for analysis.

- **Row‑level and column‑level security:**
  - Use the target storage layer (e.g. Lakehouse / Warehouse) to define policies that only allow specific roles
    to query raw PII tables.
  - Provide separate **de‑identified views** for most users.

### 2.3. How Masking Fits into the Data Flow

A typical layered architecture could look like:

1. **Raw / Bronze layer**
   - Contains exact copies of the source files as delivered (`customer_data`, `sales_data`).
   - Strict ACLs; only data engineering / platform teams can read.

2. **Clean / Silver layer**
   - Data is cleaned, normalised, and joined (similar to the `enriched_sales` table in this repo).
   - PII fields are **still present**, but the layer is restricted to a small group (e.g. data science team).

3. **Analytics / Gold layer**
   - PII fields are removed or masked according to the strategy above.
   - Tables like `agg_sales_by_customer`, `agg_sales_by_mall_category`, `agg_daily_sales` contain
     aggregate metrics, not per‑row PII.
   - This layer is exposed to a wider analyst audience and BI tools.

In this repository, the **transform step** could be extended with a simple `apply_pii_masking()` function, e.g.:

```python
def apply_pii_masking(enriched_df: pd.DataFrame) -> pd.DataFrame:
    df = enriched_df.copy()
    # Example: drop direct identifiers if present
    for col in ["customer_name", "email", "phone"]:
        if col in df.columns:
            df.drop(columns=[col], inplace=True)

    # Example: hash customer_id
    if "customer_id" in df.columns:
        import hashlib
        df["customer_id"] = df["customer_id"].apply(
            lambda x: hashlib.sha256(str(x).encode("utf-8")).hexdigest()
        )
    return df
```

This function would be called **before** writing analytics tables for general consumption.

### 2.4. Policy & Catalog Integration

The chosen data governance tool (DataHub / OpenMetadata):

- Marks PII columns with appropriate tags (e.g., `pii`, `pii-sensitive`).
- Documents which tables are:
  - `raw_pii` – restricted
  - `masked` – suitable for analysts
- Surfaces lineage so it’s clear which analytics tables are derived from PII sources.

Combined with IAM / role‑based access in the underlying storage system, this enforces that:

- Only authorised users can access raw PII.
- Most users work exclusively with masked / aggregated data, minimising privacy risk.

## 3. Summary

- Use a modern catalog + lineage tool (DataHub/OpenMetadata) to register datasets, pipelines, and
  downstream assets, giving full visibility into data lineage.
- Implement PII masking at the transformation layer and expose only masked / aggregated tables
  to the majority of users.
- Use layered zones (raw, clean, analytics) and role‑based access control to enforce governance
  and privacy guarantees end‑to‑end.
