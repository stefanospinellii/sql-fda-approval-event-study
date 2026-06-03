# FDA Approval Event Study

## Overview

This project investigates how public pharmaceutical companies' stock prices react to FDA drug approvals.

Using FDA approval data and historical stock prices, I built an event study in SQL to measure abnormal returns around approval dates and identify which types of approvals generate the strongest market reactions.

The project was built entirely in SQL using DuckDB. Python was only used to download stock price data from Yahoo Finance.

---

## Business Question

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

---

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

### 1. Average market reaction is small

Across all approvals, average abnormal returns were close to zero.

### 2. A small number of approvals drive most market impact

Some approvals generated exceptionally large reactions:

| Company    | Drug       | Event CAR |
| ---------- | ---------- | --------- |
| Sarepta    | Exondys 51 | +87.7%    |
| Biogen     | Aduhelm    | +38.3%    |
| Sarepta    | Vyondys 53 | +29.5%    |
| Neurocrine | Ingrezza   | +28.3%    |

### 3. Biotech companies react more strongly

Biotech firms showed larger abnormal returns than large pharmaceutical companies.

| Company Group | Events | Median Event CAR |
| ------------- | ------ | ---------------- |
| Biotech       | 1,182  | 0.09%            |
| Big Pharma    | 7,284  | 0.00%            |

### 4. NDA and BLA approvals show similar reactions

The data suggests limited differences between traditional drugs and biologics.

| Application Type | Events | Median Event CAR |
| ---------------- | ------ | ---------------- |
| NDA              | 7,115  | 0.00%            |
| BLA              | 1,294  | 0.00%            |

### 5. Priority Reviews generate slightly stronger reactions

Priority approvals showed higher median abnormal returns than Standard Reviews.

| Review Type | Events | Median Event CAR |
| ----------- | ------ | ---------------- |
| Priority    | 977    | 0.03%            |
| Standard    | 6,308  | 0.00%            |

---

## Repository Structure

```text
sql-fda-approval-event-study/
│
├── README.md
├── analysis.sql
├── run.py
├── setup.py
└── .gitignore
```

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