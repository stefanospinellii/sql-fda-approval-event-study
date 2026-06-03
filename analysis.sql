-- FDA Approval Event Study
-- Business question:
-- How does the stock market react to FDA drug approvals?
-- ============================================================

-- 1. Load FDA datasets

CREATE OR REPLACE TEMP VIEW submissions AS
SELECT *
FROM read_csv_auto('raw_data/Submissions.txt', sep = '\t', header = true);

CREATE OR REPLACE TEMP VIEW applications AS
SELECT *
FROM read_csv_auto('raw_data/Applications.txt', sep = '\t', header = true);

CREATE OR REPLACE TEMP VIEW products AS
SELECT *
FROM read_csv_auto('raw_data/Products.txt', sep = '\t', header = true);

CREATE OR REPLACE TEMP VIEW products_clean AS
SELECT
    ApplNo,
    MIN(DrugName) AS DrugName
FROM products
GROUP BY ApplNo;

-- 2. Load stock prices

CREATE OR REPLACE TEMP VIEW stock_prices AS
SELECT
    CAST("Date" AS DATE) AS trade_date,
    ticker,
    close_price
FROM read_csv_auto('data/stock_prices.csv', header = true);

-- 3. Map FDA sponsor names to listed tickers

CREATE OR REPLACE TEMP VIEW ticker_mapping AS
SELECT *
FROM (
    VALUES
        ('ABBVIE', 'ABBV'),
        ('NOVARTIS', 'NVS'),
        ('PFIZER', 'PFE'),
        ('ELI LILLY', 'LLY'),
        ('MERCK', 'MRK'),
        ('ASTRAZENECA', 'AZN'),
        ('GLAXO', 'GSK'),
        ('BRISTOL', 'BMY'),
        ('JOHNSON', 'JNJ'),
        ('SANOFI', 'SNY'),
        ('BAYER', 'BAYRY'),
        ('NOVO', 'NVO'),
        ('TAKEDA', 'TAK'),
        ('ROCHE', 'RHHBY'),
        ('AMGEN', 'AMGN'),
        ('GILEAD', 'GILD'),
        ('BIOGEN', 'BIIB'),
        ('REGENERON', 'REGN'),
        ('VERTEX', 'VRTX'),
        ('BIOMARIN', 'BMRN'),
        ('INCYTE', 'INCY'),
        ('SAREPTA', 'SRPT'),
        ('ULTRAGENYX', 'RARE'),
        ('ALNYLAM', 'ALNY'),
        ('EXELIXIS', 'EXEL'),
        ('IONIS', 'IONS'),
        ('NEUROCRINE', 'NBIX'),
        ('ARGENX', 'ARGX'),
        ('UNITED THERAPEUTICS', 'UTHR'),
        ('JAZZ', 'JAZZ')
) AS t(sponsor_pattern, ticker);

-- 4. Create clean FDA approval events

-- Unit of analysis: one FDA approval event per ApplNo + approval date + ticker

CREATE OR REPLACE TEMP VIEW fda_events AS
SELECT
    ROW_NUMBER() OVER () AS event_id,
    a.ApplNo,
    a.ApplType,
    a.SponsorName AS SponsorApplicant,
    p.DrugName,
    tm.ticker,
    CAST(s.SubmissionStatusDate AS DATE) AS approval_date,
    s.ReviewPriority
FROM submissions s
JOIN applications a
    ON s.ApplNo = a.ApplNo
LEFT JOIN products_clean p
    ON s.ApplNo = p.ApplNo
JOIN ticker_mapping tm
    ON UPPER(a.SponsorName) LIKE '%' || tm.sponsor_pattern || '%'
WHERE s.SubmissionStatus = 'AP'
  AND CAST(s.SubmissionStatusDate AS DATE) BETWEEN DATE '2009-01-01' AND DATE '2025-12-31'
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY a.ApplNo, CAST(s.SubmissionStatusDate AS DATE), tm.ticker
    ORDER BY s.SubmissionNo DESC
) = 1;

-- 5. Calculate daily stock returns using LAG()

CREATE OR REPLACE TEMP VIEW daily_returns AS
SELECT
    trade_date,
    ticker,
    close_price,
    close_price / LAG(close_price) OVER (
        PARTITION BY ticker
        ORDER BY trade_date
    ) - 1 AS daily_return
FROM stock_prices;

-- 6. Build event window and abnormal returns vs SPY

CREATE OR REPLACE TEMP VIEW event_window AS
SELECT
    e.event_id,
    e.ApplNo,
    e.ApplType,
    e.SponsorApplicant,
    e.DrugName,
    e.ticker,
    e.approval_date,
    e.ReviewPriority,
    r.trade_date,
    DATEDIFF('day', e.approval_date, r.trade_date) AS days_from_approval,
    r.daily_return AS stock_return,
    spy.daily_return AS market_return,
    r.daily_return - spy.daily_return AS abnormal_return,
    CASE
        WHEN DATEDIFF('day', e.approval_date, r.trade_date) BETWEEN -30 AND -7 THEN 'pre_30_to_7'
        WHEN DATEDIFF('day', e.approval_date, r.trade_date) BETWEEN -1 AND 1 THEN 'event_1_to_1'
        WHEN DATEDIFF('day', e.approval_date, r.trade_date) BETWEEN 2 AND 10 THEN 'post_2_to_10'
        WHEN DATEDIFF('day', e.approval_date, r.trade_date) BETWEEN 11 AND 30 THEN 'post_11_to_30'
    END AS event_window
FROM fda_events e
JOIN daily_returns r
    ON e.ticker = r.ticker
   AND r.trade_date BETWEEN e.approval_date - INTERVAL 30 DAY
                        AND e.approval_date + INTERVAL 30 DAY
JOIN daily_returns spy
    ON spy.ticker = 'SPY'
   AND spy.trade_date = r.trade_date
WHERE r.daily_return IS NOT NULL
  AND spy.daily_return IS NOT NULL;


-- Query 1: Overall market reaction by event window

SELECT
    event_window,
    COUNT(*) AS trading_days,
    COUNT(DISTINCT event_id) AS fda_events,
    ROUND(AVG(abnormal_return) * 100, 4) AS avg_abnormal_return_pct,
    ROUND(MEDIAN(abnormal_return) * 100, 4) AS median_abnormal_return_pct
FROM event_window
WHERE event_window IS NOT NULL
GROUP BY event_window
ORDER BY
    CASE event_window
        WHEN 'pre_30_to_7' THEN 1
        WHEN 'event_1_to_1' THEN 2
        WHEN 'post_2_to_10' THEN 3
        WHEN 'post_11_to_30' THEN 4
    END;


-- Query 2: Cumulative abnormal return per FDA event

WITH car_by_event AS (
    SELECT
        event_id,
        ticker,
        SponsorApplicant,
        DrugName,
        ApplType,
        approval_date,
        SUM(CASE WHEN days_from_approval BETWEEN -7 AND -1 THEN abnormal_return ELSE 0 END) AS car_pre_7d,
        SUM(CASE WHEN days_from_approval BETWEEN 0 AND 1 THEN abnormal_return ELSE 0 END) AS car_event_0_1d,
        SUM(CASE WHEN days_from_approval BETWEEN 2 AND 7 THEN abnormal_return ELSE 0 END) AS car_post_7d,
        SUM(CASE WHEN days_from_approval BETWEEN 2 AND 30 THEN abnormal_return ELSE 0 END) AS car_post_30d
    FROM event_window
    GROUP BY event_id, ticker, SponsorApplicant, DrugName, ApplType, approval_date
)

SELECT
    event_id,
    ticker,
    SponsorApplicant,
    DrugName,
    ApplType,
    approval_date,
    ROUND(car_pre_7d * 100, 2) AS car_pre_7d_pct,
    ROUND(car_event_0_1d * 100, 2) AS car_event_0_1d_pct,
    ROUND(car_post_7d * 100, 2) AS car_post_7d_pct,
    ROUND(car_post_30d * 100, 2) AS car_post_30d_pct
FROM car_by_event
ORDER BY ABS(car_event_0_1d) DESC
LIMIT 30;


-- Query 3: Big Pharma vs Biotech

WITH car_by_event AS (
    SELECT
        event_id,
        ticker,
        SponsorApplicant,
        DrugName,
        ApplType,
        approval_date,
        SUM(CASE WHEN days_from_approval BETWEEN 0 AND 1 THEN abnormal_return ELSE 0 END) AS car_event_0_1d,
        SUM(CASE WHEN days_from_approval BETWEEN 2 AND 7 THEN abnormal_return ELSE 0 END) AS car_post_7d
    FROM event_window
    GROUP BY event_id, ticker, SponsorApplicant, DrugName, ApplType, approval_date
),

classified_events AS (
    SELECT
        *,
        CASE
            WHEN ticker IN (
                'PFE', 'MRK', 'JNJ', 'LLY', 'ABBV', 'NVS', 'AZN',
                'GSK', 'BMY', 'SNY', 'BAYRY', 'NVO', 'TAK', 'RHHBY'
            )
                THEN 'Big Pharma'
            ELSE 'Biotech'
        END AS company_group
    FROM car_by_event
)

SELECT
    company_group,
    COUNT(*) AS events,
    ROUND(AVG(car_event_0_1d) * 100, 2) AS avg_event_car_pct,
    ROUND(MEDIAN(car_event_0_1d) * 100, 2) AS median_event_car_pct,
    ROUND(AVG(car_post_7d) * 100, 2) AS avg_post_7d_car_pct,
    ROUND(MEDIAN(car_post_7d) * 100, 2) AS median_post_7d_car_pct
FROM classified_events
GROUP BY company_group
ORDER BY median_event_car_pct DESC;


-- Query 4: NDA vs BLA

WITH car_by_event AS (
    SELECT
        event_id,
        ticker,
        SponsorApplicant,
        DrugName,
        ApplType,
        approval_date,
        SUM(CASE WHEN days_from_approval BETWEEN 0 AND 1 THEN abnormal_return ELSE 0 END) AS car_event_0_1d,
        SUM(CASE WHEN days_from_approval BETWEEN 2 AND 7 THEN abnormal_return ELSE 0 END) AS car_post_7d
    FROM event_window
    GROUP BY event_id, ticker, SponsorApplicant, DrugName, ApplType, approval_date
)

SELECT
    ApplType,
    COUNT(*) AS events,
    ROUND(AVG(car_event_0_1d) * 100, 2) AS avg_event_car_pct,
    ROUND(MEDIAN(car_event_0_1d) * 100, 2) AS median_event_car_pct,
    ROUND(AVG(car_post_7d) * 100, 2) AS avg_post_7d_car_pct,
    ROUND(MEDIAN(car_post_7d) * 100, 2) AS median_post_7d_car_pct
FROM car_by_event
WHERE ApplType IN ('NDA', 'BLA')
GROUP BY ApplType
ORDER BY median_event_car_pct DESC;


-- Query 5: Top 20 market-moving FDA approval events

WITH car_by_event AS (
    SELECT
        event_id,
        ticker,
        SponsorApplicant,
        DrugName,
        ApplType,
        approval_date,
        SUM(CASE WHEN days_from_approval BETWEEN 0 AND 1 THEN abnormal_return ELSE 0 END) AS car_event_0_1d,
        SUM(CASE WHEN days_from_approval BETWEEN 2 AND 30 THEN abnormal_return ELSE 0 END) AS car_post_30d
    FROM event_window
    GROUP BY event_id, ticker, SponsorApplicant, DrugName, ApplType, approval_date
)

SELECT
    approval_date,
    ticker,
    SponsorApplicant,
    DrugName,
    ApplType,
    ROUND(car_event_0_1d * 100, 2) AS event_car_pct,
    ROUND(car_post_30d * 100, 2) AS post_30d_car_pct
FROM car_by_event
ORDER BY ABS(car_event_0_1d) DESC
LIMIT 20;


-- Query 6: Priority vs Standard Review

WITH car_by_event AS (
    SELECT
        event_id,
        ticker,
        SponsorApplicant,
        DrugName,
        ApplType,
        ReviewPriority,
        approval_date,
        SUM(CASE WHEN days_from_approval BETWEEN 0 AND 1 THEN abnormal_return ELSE 0 END) AS car_event_0_1d,
        SUM(CASE WHEN days_from_approval BETWEEN 2 AND 7 THEN abnormal_return ELSE 0 END) AS car_post_7d
    FROM event_window
    GROUP BY event_id, ticker, SponsorApplicant, DrugName, ApplType, ReviewPriority, approval_date
)

SELECT
    COALESCE(UPPER(ReviewPriority), 'UNKNOWN') AS review_priority,
    COUNT(*) AS events,
    ROUND(AVG(car_event_0_1d) * 100, 2) AS avg_event_car_pct,
    ROUND(MEDIAN(car_event_0_1d) * 100, 2) AS median_event_car_pct,
    ROUND(AVG(car_post_7d) * 100, 2) AS avg_post_7d_car_pct,
    ROUND(MEDIAN(car_post_7d) * 100, 2) AS median_post_7d_car_pct
FROM car_by_event
GROUP BY review_priority
ORDER BY median_event_car_pct DESC;