# Jobber ETL Solution – Multi-Format Open Table Format Pipeline

This repository contains a production-ready end-to-end ETL pipeline supporting **Apache Iceberg**, **Delta Lake**, **Apache Hudi**, and native **Parquet** backends.

## Key Features

- **Multi-format OTF Support**: Iceberg, Delta Lake, Hudi, Parquet with intelligent fallback
- **Absolute Imports**: No relative import errors; works with module execution
- **Intelligent Path Resolution**: Auto-discovers data files across multiple search strategies
- **Comprehensive Unit Tests**: 37 passing tests with pytest fixtures
- **CI/CD Ready**: GitHub Actions workflow for multi-version testing
- **Production Logging**: Structured logging with file and console outputs
- **Data Validation**: Pre-transformation constraint validation
- **Config Management**: YAML-based pipeline configuration

## 1. Prerequisites & Installation

### 1.1 Python Environment

```bash
# Requires Python 3.8+
python --version  # Should be 3.8 or higher
```

### 1.2 Core Dependencies

```bash
pip install -r requirements.txt
```

### 1.3 Optional OTF Backends

Install additional dependencies for specific backends:

```bash
# For Apache Iceberg support
pip install pyiceberg

# For Delta Lake support
pip install deltalake

# For Apache Hudi support
pip install pyspark
```

**Note:** If optional dependencies are not installed, the pipeline gracefully falls back to Parquet format.

## 2. Project Structure

```
jobber_etl_solution/
├── README.md
├── requirements.txt
├── pytest.ini                          # Pytest configuration
├── config/
│   └── pipeline_config.yml             # YAML pipeline configuration
├── src/
│   └── jobber_pipeline/
│       ├── __init__.py
│       ├── config.py                   # Configuration management with path resolution
│       ├── logger.py                   # Structured logging setup
│       ├── exceptions.py               # Custom exceptions
│       ├── extract.py                  # Data extraction from CSV/Parquet
│       ├── validators.py               # Data validation constraints
│       ├── transform.py                # Data cleaning and aggregation
│       ├── load.py                     # Multi-format table writers (Iceberg/Delta/Hudi/Parquet)
│       ├── main.py                     # Pipeline orchestration
│       └── data/                       # Sample data files
│           ├── customer_data.parquet
│           └── sales_data.csv
├── tests/
│   ├── __init__.py
│   ├── conftest.py                     # Pytest fixtures (sample data, config, logger)
│   ├── test_extract.py                 # 5 tests for DataExtractor
│   ├── test_validators.py              # 9 tests for validation constraints
│   ├── test_transform.py               # 24 tests for transformations
│   └── test_load.py                    # 13 tests for OTF writers
├── docs/
│   └── data_governance.md
└── .github/
    └── workflows/
        └── ci.yml                      # GitHub Actions CI/CD pipeline
```

## 3. Configuration

### 3.1 Pipeline Configuration (YAML)

Edit `config/pipeline_config.yml`:

```yaml
input:
  customer_path: "data/customer_data.parquet"
  sales_path: "data/sales_data.csv"

output:
  base_output_dir: "output"
  backend: "parquet"              # Options: "parquet", "iceberg", "delta", "hudi"
  partitions:
    invoice_date: []
  iceberg_warehouse: "/tmp/iceberg_warehouse"

logging:
  level: "INFO"
  log_file: "output/pipeline.log"

validation:
  sales:
    min_quantity: 1
    min_price: 0.0
  customer:
    valid_genders: ["M", "F"]
    max_age: 120
```

### 3.2 Selecting OTF Backend

Modify the `backend` field in config:

```yaml
# Use native Parquet (always available)
backend: "parquet"

# Use Apache Iceberg (requires: pip install pyiceberg)
backend: "iceberg"

# Use Delta Lake (requires: pip install deltalake)
backend: "delta"

# Use Apache Hudi (requires: pip install pyspark)
backend: "hudi"
```

## 4. Running the Pipeline

### 4.1 Basic Execution

```bash
export PYTHONPATH=src
python -m jobber_pipeline.main --config config/pipeline_config.yml
```

### 4.2 With Specific Backend

```bash
# Delta Lake backend
PYTHONPATH=src python -m jobber_pipeline.main --config config/pipeline_config.yml
# (After updating config to backend: "delta")
```

### 4.3 Output Flow Architecture

The pipeline uses a **factory pattern** to route output based on the configured backend. This enables multi-format support with intelligent path resolution.

#### Output Routing Logic

```
Pipeline Configuration (config/pipeline_config.yml)
    │
    └─► backend: "parquet" | "iceberg" | "delta" | "hudi"
            │
            ▼
    get_writer() Factory Function (load.py)
            │
    ┌───────┼───────────────────┬──────────┐
    │       │                   │          │
    ▼       ▼                   ▼          ▼
  Parquet Iceberg           Delta Lake   Hudi
    │       │                   │          │
    ▼       ▼                   ▼          ▼
  output/ warehouse/        warehouse/  warehouse/
```

#### Backend-Specific Output Paths

**1. Parquet Backend** (Simple, lightweight)
```
config/output/
├── sales.parquet
├── customer.parquet
├── enriched_sales.parquet
├── agg_daily_sales.parquet
├── agg_sales_by_customer.parquet
└── agg_sales_by_mall_category.parquet
```
- **Location**: `config/output/`
- **Format**: Flat file structure (one file per table)
- **Use Case**: Quick prototyping, simple ETL
- **Features**: Lightweight, no metadata overhead

**2. Iceberg Backend** (Enterprise-grade, recommended)
```
config/warehouse/default/
├── sales/
│   ├── data/
│   │   └── 00000-0-UUID.parquet (actual data)
│   ├── metadata/
│   │   ├── UUID-m0.avro
│   │   ├── snap-*.avro
│   │   └── *.metadata.json (versioning info)
│   └── v1.metadata.json
├── customer/
│   ├── data/
│   ├── metadata/
│   └── v1.metadata.json
├── enriched_sales/
│   ├── data/
│   ├── metadata/
│   └── v1.metadata.json
├── agg_daily_sales/          (partitioned by date)
│   ├── data/
│   ├── metadata/
│   └── v1.metadata.json
├── agg_sales_by_customer/
│   ├── data/
│   ├── metadata/
│   └── v1.metadata.json
└── agg_sales_by_mall_category/
    ├── data/
    ├── metadata/
    └── v1.metadata.json
```
- **Location**: `config/warehouse/default/`
- **Format**: Hierarchical (data + metadata structure)
- **Use Case**: Production data lakes, enterprise governance
- **Features**: ACID transactions, time travel, schema evolution, partition pruning

**3. Delta Lake Backend** (Intermediate complexity)
```
config/warehouse/
├── sales/
│   ├── _delta_log/ (transaction log)
│   ├── part-00000.parquet
│   └── part-00001.parquet
├── customer/
│   ├── _delta_log/
│   ├── part-00000.parquet
│   └── ...
├── enriched_sales/
│   ├── _delta_log/
│   └── ...
└── (other tables...)
```
- **Location**: `config/warehouse/`
- **Format**: Parquet files with transaction logs
- **Use Case**: Data warehouses, analytics
- **Features**: ACID transactions, versioning

**4. Hudi Backend** (Real-time analytics)
```
config/warehouse/
├── sales/
│   ├── .hoodie/ (Hudi metadata)
│   ├── part-00000.parquet
│   └── ...
└── (other tables...)
```
- **Location**: `config/warehouse/`
- **Format**: Parquet with Hudi metadata
- **Use Case**: Incremental processing, streaming
- **Features**: Incremental writes, change data capture (CDC)

#### Output Table Specifications

All backends produce the same 6 tables:

| Table | Rows | Columns | Details |
|-------|------|---------|---------|
| **sales** | 99,457 | 7 | Raw sales transactions (invoice_no, customer_id, category, quantity, price, invoice_date, shopping_mall) |
| **customer** | 99,457 | 4 | Customer master data (customer_id, gender, age, payment_method) |
| **enriched_sales** | 99,457 | 11 | Sales enriched with customer demographics (all 7 sales cols + 4 customer cols) |
| **agg_daily_sales** | 797 | 4 | Daily aggregates: daily sales totals by date (invoice_date, total_quantity, total_amount, num_transactions) |
| **agg_sales_by_customer** | 99,457 | 5 | Customer-level aggregates: total spending per customer (customer_id, total_quantity, total_amount, avg_price, num_transactions) |
| **agg_sales_by_mall_category** | 80 | 6 | Mall × Category analysis: sales breakdown by mall and product category (shopping_mall, category, num_transactions, total_quantity, total_amount, avg_price) |

**Total Data**: 398,705 records across all tables

#### How to Switch Backends

**Current Setup** (using Iceberg):
```bash
# Check current backend
grep "backend:" config/pipeline_config.yml
# Output: backend: "iceberg"

# Data is in: config/warehouse/default/
```

**Switch to Parquet**:
```bash
# Edit config/pipeline_config.yml
sed -i '' 's/backend: "iceberg"/backend: "parquet"/' config/pipeline_config.yml

# Re-run pipeline
PYTHONPATH=src python -m jobber_pipeline.main --config config/pipeline_config.yml

# Data will now be in: config/output/
```

**Switch to Delta Lake**:
```bash
# Install Delta Lake support
pip install deltalake

# Edit config/pipeline_config.yml
sed -i '' 's/backend: "iceberg"/backend: "delta"/' config/pipeline_config.yml

# Re-run pipeline
PYTHONPATH=src python -m jobber_pipeline.main --config config/pipeline_config.yml

# Data will be in: config/warehouse/
```

#### Verifying Output

**Check Iceberg Tables**:
```bash
# List all tables
ls -la config/warehouse/default/

# Count rows in a specific table
PYTHONPATH=src python3 << 'EOF'
import pandas as pd
df = pd.read_parquet("config/warehouse/default/enriched_sales/data/00000-0-*.parquet")
print(f"Enriched Sales: {len(df):,} rows")
EOF
```

**Check Parquet Output**:
```bash
# List all Parquet files
ls -lh config/output/*.parquet

# Read a table
PYTHONPATH=src python3 << 'EOF'
import pandas as pd
df = pd.read_parquet("config/output/enriched_sales.parquet")
print(f"Enriched Sales: {len(df):,} rows")
EOF
```

## 5. Testing

### 5.1 Run All Tests

```bash
export PYTHONPATH=src
pytest tests/ -v
```

### 5.2 Run Specific Test Module

```bash
# Test OTF writers
pytest tests/test_load.py -v

# Test transformations
pytest tests/test_transform.py -v

# Test data validation
pytest tests/test_validators.py -v

# Test data extraction
pytest tests/test_extract.py -v
```

### 5.3 Test Coverage

```bash
pytest tests/ --cov=src/jobber_pipeline --cov-report=html
# View coverage at htmlcov/index.html
```

### 5.4 Test Fixtures

The test suite uses comprehensive fixtures defined in `tests/conftest.py`:

- `sample_sales_df`: Test sales data (5 rows, 7 columns)
- `sample_customer_df`: Test customer data (3 rows, 4 columns)
- `temp_warehouse`: Temporary directory for output
- `mock_logger`: Mock logger for capturing log messages
- `test_pipeline_config`: Complete pipeline configuration
- `test_output_config`: Output configuration with temp paths

## 6. OTF Backend Architecture

### 6.1 Writer Classes

```python
# Abstract base class
class BaseTableWriter(ABC):
    def write_table(df, table_name, partition_cols=None) -> None
    def read_table(table_name) -> pd.DataFrame
    def list_tables() -> List[str]
    def describe_table(table_name) -> Dict

# Concrete implementations
class IcebergWriter(BaseTableWriter)      # Apache Iceberg
class DeltaLakeWriter(BaseTableWriter)    # Delta Lake
class HudiWriter(BaseTableWriter)         # Apache Hudi (Spark-based)
class DeltaLikeParquetWriter(BaseTableWriter)  # Native Parquet with Delta-like layout
```

### 6.2 Writer Factory with Fallback

```python
def get_writer(config: OutputConfig, logger) -> BaseTableWriter:
    # Attempts to load requested backend
    # Falls back to DeltaLikeParquetWriter if optional deps missing
    # Logs warning on fallback
```



### 6.3 Example: Write with Iceberg

```python
from jobber_pipeline.config import OutputConfig
from jobber_pipeline.load import get_writer
from jobber_pipeline.logger import create_logger

config = OutputConfig(
    base_output_dir="output",
    backend="iceberg",
    partitions={"invoice_date": []},
    iceberg_warehouse="/tmp/iceberg_warehouse"
)
logger = create_logger("my_pipeline", "output/logs")
writer = get_writer(config, logger)

# writer is now IcebergWriter
writer.write_table(sales_df, "sales_table")
```

## 7. Troubleshooting

### 7.1 ImportError: "attempted relative import with no known parent package"

**Solution:** Use absolute imports and set PYTHONPATH:

```bash
export PYTHONPATH=src
python -m jobber_pipeline.main --config config/pipeline_config.yml
```

### 7.2 Data Files Not Found

**Solution:** The pipeline uses intelligent path resolution:

1. Tries config-relative paths (config dir + specified path)
2. Tries project-root-relative paths
3. Recursively searches project for filename

Place data files in `src/jobber_pipeline/data/` or `data/` at project root.

### 7.3 Backend Not Available

**Solution:** Check which backends are installed:

```bash
python -c "
try:
    import pyiceberg
    print('✓ Iceberg available')
except ImportError:
    print('✗ Iceberg not available')

try:
    import deltalake
    print('✓ Delta Lake available')
except ImportError:
    print('✗ Delta Lake not available')
    
try:
    import pyspark
    print('✓ Hudi (Spark) available')
except ImportError:
    print('✗ Hudi not available')
"
```

Install missing backends with `pip install <backend>`.

## 8. CI/CD Pipeline

### 8.1 GitHub Actions

The repository includes `.github/workflows/ci.yml` which:

- Runs on Python 3.8, 3.9, 3.10, 3.11, 3.13
- Installs dependencies and runs linting
- Executes 37 unit tests
- Generates coverage reports
- Tests end-to-end pipeline execution
- Tests all OTF backends (with graceful fallback)

### 8.2 Local CI Simulation

```bash
# Run linting
flake8 src/jobber_pipeline --max-complexity=10

# Run tests with coverage
pytest tests/ --cov=src/jobber_pipeline --cov-report=term

# Run end-to-end pipeline
PYTHONPATH=src python -m jobber_pipeline.main --config config/pipeline_config.yml
```

## 9. Data Governance

See `docs/data_governance.md` for:

- Data lineage and governance architecture
- PII masking strategies
- Integration with OpenMetadata / DataHub
- Quality metrics and monitoring


## 10. Performance Considerations

- **Data Loading**: Uses PyArrow for efficient columnar reads
- **Partitioning**: Supports date-based partitioning for large datasets
- **Backend Selection**: Delta Lake and Iceberg offer ACID transactions; Parquet is lightweight
- **Memory**: Pandas DataFrames; consider chunking for 10GB+ datasets

## 11. Query & Inspection

### 11.1 Query Output Tables

Use the `query_warehouse.py` utility to inspect generated tables:

```bash
export PYTHONPATH=src
python src/jobber_pipeline/query_warehouse.py
```

This displays:
- All available tables (enriched_sales, agg_daily_sales, agg_sales_by_customer, agg_sales_by_mall_category, customer, sales)
- Row counts for each table
- Column names and data types
- Sample data from each table

### 11.2 Manual Inspection

```python
import pandas as pd

# Read a specific table
df = pd.read_parquet("output/enriched_sales.parquet")
print(df.head())
print(df.info())
```

## 12. Next Steps / Roadmap

- [ ] Add stream processing support (Kafka)
- [ ] Implement incremental loading (CDC)
- [ ] Add Apache Spark distributed processing
- [ ] Performance benchmarks for each backend
- [ ] Advanced data quality rules (Great Expectations)
- [ ] Integration with dbt for transformation versioning
- [ ] Automated schema evolution

## 13. Support & Documentation

- **Issues**: Report bugs via GitHub Issues
- **Docs**: See `docs/` folder for detailed guides
- **Logs**: Check `output/pipeline.log` for execution details
- **Tests**: Run `pytest -v` for detailed test output
- **Governance**: Review `docs/data_governance.md` for lineage, PII strategies, and compliance

---

**Last Updated**: 2024 | **Python**: 3.8+ | **Status**: Production Ready
