# FDA Approval Event Study

## Overview

This project investigates how public pharmaceutical companies' stock prices react to FDA drug approvals.

Using FDA approval data and historical stock prices, I built an event study in SQL to measure abnormal returns around approval dates and identify which types of approvals generate the strongest market reactions.

The project was built entirely in SQL using DuckDB. Python was only used to download stock price data from Yahoo Finance.

---

## Research Questions

> How does the stock market react to FDA drug approvals?

More specifically:

* Do FDA approvals create abnormal returns?
* Do biotech companies react differently from large pharmaceutical companies?
* Do biologics (BLA) generate stronger reactions than traditional drugs (NDA)?
* Do Priority Reviews create larger market reactions than Standard Reviews?
* Which FDA approvals generated the strongest stock market movements?

---

## Data Sources

### FDA Approval Data

Downloaded from the FDA Orange Book datasets:

* Applications.txt
* Submissions.txt
* Products.txt

### Market Data

Daily stock prices downloaded through Yahoo Finance for:

* Large pharmaceutical companies
* Biotechnology companies
* SPY (market benchmark)

Period covered:

2009 - 2025

---

## Methodology

1. Load FDA approval data
2. Match sponsors to listed companies
3. Identify approval events
4. Calculate daily stock returns using SQL window functions
5. Calculate abnormal returns relative to SPY
6. Build event windows around approval dates
7. Aggregate cumulative abnormal returns (CAR)

### Key Metrics

**Daily Return**

Daily return measures the percentage change in a stock price from one trading day to the next.

```text
Daily Return = (Today's Closing Price / Previous Closing Price) - 1
```

**Abnormal Return**

Abnormal return measures how much a stock outperformed or underperformed the broader market on a given day.

```text
Abnormal Return = Stock Return - Market Return
```

In this project, market return was measured using **SPY**, the ticker of the SPDR S&P 500 ETF. Because SPY tracks the S&P 500 Index, it was used as a proxy for overall U.S. market performance.

A positive abnormal return indicates that a stock outperformed the broader market, while a negative abnormal return indicates underperformance.

**Cumulative Abnormal Return (CAR)**

CAR measures the total abnormal performance over a specific event window.

```text
CAR = Sum of Abnormal Returns over the event window
```

For example, a 7-day CAR of 2% means the stock outperformed the broader U.S. market by 2 percentage points during that event window.

## SQL Techniques Used

* CTEs
* Window Functions
* LAG()
* ROW_NUMBER()
* QUALIFY
* CASE WHEN
* GROUP BY
* MEDIAN()
* Multi-table joins
* Event window calculations

---

## Key Findings

### 1. Average approval reaction is close to zero

Across 8,466 FDA approval events, the average event CAR was 0.07% and the median event CAR was 0.00%.

| Events | Mean Event CAR | Median Event CAR |
|-------:|---------------:|-----------------:|
| 8,466 | 0.07% | 0.00% |

The low average reaction suggests that many FDA approvals may already be anticipated by investors before the official decision date. Clinical trial results, analyst expectations, management guidance and regulatory updates may already be incorporated into stock prices.

### 2. A small number of approvals drive most market impact

| Company | Drug | Event CAR |
|----------|----------|----------:|
| Sarepta | Exondys 51 | +87.71% |
| Biogen | Aduhelm | +38.30% |
| Sarepta | Vyondys 53 | +29.54% |
| Neurocrine | Ingrezza | +28.34% |

These approvals were concentrated among companies whose future growth prospects depended heavily on a limited number of products. In such cases, FDA approval can significantly reduce uncertainty around future revenues and valuation. 

### 3. Biotech companies react more strongly than Big Pharma

| Company Group | Events | Mean Event CAR | Median Event CAR |
|--------------|-------:|---------------:|-----------------:|
| Biotech | 1,182 | 0.35% | 0.09% |
| Big Pharma | 7,284 | 0.02% | 0.00% |

Biotech companies are usually more dependent on a smaller product pipeline, so a single approval can have a larger valuation impact.

### 4. NDA and BLA approvals show similar reactions

| Application Type | Events | Mean Event CAR | Median Event CAR |
|------------------|-------:|---------------:|-----------------:|
| BLA | 1,294 | 0.03% | 0.00% |
| NDA | 7,115 | 0.07% | 0.00% |

The results suggest that investors may care more about a treatment's commercial potential than its regulatory pathway. Whether a product is approved through an NDA or BLA appears to have limited influence on market reactions.

### 5. Priority Reviews generate slightly stronger reactions

| Review Type | Events | Mean Event CAR | Median Event CAR |
|-------------|-------:|---------------:|-----------------:|
| Priority | 977 | 0.27% | 0.03% |
| Standard | 6,308 | 0.04% | 0.00% |

Priority Review status may signal stronger clinical relevance or larger commercial opportunity.

## Outputs

Running `python run.py` generates the result tables used in the analysis and saves them to the `outputs/` folder.

Generated files:

- `01_overall_event_car_summary.csv`
- `02_top_market_moving_events.csv`
- `03_big_pharma_vs_biotech.csv`
- `04_nda_vs_bla.csv`
- `05_priority_vs_standard.csv`
- `06_event_window_summary.csv`

## Running the Project

### 1. Install Dependencies

```bash
pip install duckdb yfinance pandas
```

### 2. Run the Analysis

From the project root directory, execute:

```bash
python run.py
```

The script will:

* Download historical stock price data using Yahoo Finance
* Load FDA approval events into DuckDB
* Calculate abnormal returns and cumulative abnormal returns (CARs)
* Generate the analysis tables used in the project findings