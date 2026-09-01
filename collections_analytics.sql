-- ==============================================================================
-- COLLECTIONS PERFORMANCE & STRATEGY AUDIT - FULL SQL REPOSITORY
-- ==============================================================================

-- ==============================================================================
-- PART 1: GOLDEN DATASET PIPELINE (DATA CLEANING & TRANSFORMATIONS)
-- ==============================================================================

-- 1. Golden Agents (SCD Type 2 Resolution: Extracting latest snapshot)
CREATE OR REPLACE TABLE golden_agents AS
WITH ranked AS (
    SELECT *, ROW_NUMBER() OVER(PARTITION BY agent_id ORDER BY TRY_CAST(updated_at AS TIMESTAMP) DESC) as rn
    FROM raw_agents
)
SELECT agent_id, employee_code, agent_name, vendor_id, team, status 
FROM ranked WHERE rn = 1;

-- 2. Golden Payments (Deduplication by exact payment_id grain)
CREATE OR REPLACE TABLE golden_payments AS
WITH ranked AS (
    SELECT *, ROW_NUMBER() OVER(PARTITION BY payment_id ORDER BY TRY_CAST(event_at AS TIMESTAMP) ASC) as rn
    FROM raw_payments
)
SELECT 
    payment_id, account_id, payment_reference, 
    TRY_CAST(amount AS DOUBLE) as amount, 
    COALESCE(payment_status, 'UNKNOWN') as payment_status,
    payment_method, provider_id,
    TRY_CAST(event_at AS TIMESTAMP) as payment_timestamp_utc
FROM ranked WHERE rn = 1;

-- 3. Golden Calls (Timezone normalization and key standardization)
CREATE OR REPLACE TABLE golden_calls AS
WITH deduplicated_calls AS (
    SELECT *, ROW_NUMBER() OVER(PARTITION BY call_id ORDER BY TRY_CAST(event_at AS TIMESTAMP) ASC) as rn
    FROM raw_calls
)
SELECT 
    c.call_id, c.account_id,
    CASE 
        WHEN c.timezone = 'Asia/Kolkata' THEN TRY_CAST(c.event_at AS TIMESTAMP) - INTERVAL 5 HOUR - INTERVAL 30 MINUTE
        WHEN c.timezone = 'Asia/Dubai' THEN TRY_CAST(c.event_at AS TIMESTAMP) - INTERVAL 4 HOUR
        ELSE TRY_CAST(c.event_at AS TIMESTAMP)
    END as call_timestamp_utc,
    c.agent_id, 
    c.campaign_id, c.call_status, TRY_CAST(c.duration_sec AS INTEGER) as duration_sec
FROM deduplicated_calls c
WHERE c.rn = 1;

-- 4. Golden Borrowers (Entity Resolution)
CREATE OR REPLACE TABLE golden_borrowers AS
WITH ranked AS (
    SELECT *, ROW_NUMBER() OVER(PARTITION BY borrower_id ORDER BY TRY_CAST(updated_at AS TIMESTAMP) DESC) as rn
    FROM raw_borrowers
)
SELECT borrower_id, name, phone, email, city, state, 
       TRY_CAST(created_at AS TIMESTAMP) as created_at_utc, 
       TRY_CAST(updated_at AS TIMESTAMP) as updated_at_utc
FROM ranked WHERE rn = 1;

-- 5. Golden WhatsApp Events (Deduplication)
CREATE OR REPLACE TABLE golden_whatsapp_events AS
WITH ranked AS (
    SELECT *, ROW_NUMBER() OVER(PARTITION BY whatsapp_event_id ORDER BY TRY_CAST(event_at AS TIMESTAMP) ASC) as rn
    FROM raw_whatsapp_events
)
SELECT whatsapp_event_id, account_id, borrower_id, 
       TRY_CAST(event_at AS TIMESTAMP) as event_at_utc,
       message_id, event_type, template_code, provider_id
FROM ranked WHERE rn = 1;

-- 6. Golden Accounts (Timezone Normalization)
CREATE OR REPLACE TABLE golden_accounts AS
SELECT
    account_id, borrower_id, loan_type,
    TRY_CAST(principal_amount AS DOUBLE) as principal_amount,
    TRY_CAST(outstanding_amount AS DOUBLE) as outstanding_amount,
    TRY_CAST(dpd AS INTEGER) as dpd, risk_segment, status,
    CASE
        WHEN timezone = 'Asia/Kolkata' THEN TRY_CAST(opened_at AS TIMESTAMP) - INTERVAL 5 HOUR - INTERVAL 30 MINUTE
        WHEN timezone = 'Asia/Dubai' THEN TRY_CAST(opened_at AS TIMESTAMP) - INTERVAL 4 HOUR
        ELSE TRY_CAST(opened_at AS TIMESTAMP)
    END as opened_at_utc,
    schema_version
FROM raw_accounts;

-- 7. Golden Promises to Pay (Resolving the Borrower ID Shuffle Trap)
CREATE OR REPLACE TABLE golden_promises_to_pay AS
SELECT
    p.ptp_id, p.account_id, a.borrower_id as borrower_id,
    TRY_CAST(p.event_at AS TIMESTAMP) as event_at_utc,
    p.agent_id, TRY_CAST(p.promised_amount AS DOUBLE) as promised_amount,
    TRY_CAST(p.promised_date AS DATE) as promised_date,
    p.status, p.source
FROM raw_promises_to_pay p
JOIN raw_accounts a ON p.account_id = a.account_id;

-- 8. Golden Account Status History (Append-only log)
CREATE OR REPLACE TABLE golden_account_status_history AS
SELECT
    history_id, account_id, TRY_CAST(event_at AS TIMESTAMP) as event_at_utc,
    status, changed_by, source, TRY_CAST(recorded_at AS TIMESTAMP) as recorded_at_utc
FROM raw_account_status_history;


-- ==============================================================================
-- PART 2: DATA FORENSICS & AUDITS
-- ==============================================================================

-- A. Payment Forensics (Phantom Recovery)
SELECT 
    (SELECT COUNT(DISTINCT payment_reference) FROM raw_payments WHERE payment_reference IN (
        SELECT payment_reference FROM raw_payments GROUP BY payment_reference HAVING COUNT(DISTINCT account_id) > 1
    )) as trap_reference_collisions,
    (SELECT COUNT(*) FROM (
        SELECT payment_id FROM raw_payments GROUP BY payment_id HAVING COUNT(*) > 1
    )) as duplicated_payment_ids,
    (SELECT SUM(TRY_CAST(amount AS DOUBLE)) FROM (
        SELECT payment_id, MAX(TRY_CAST(amount AS DOUBLE)) * (COUNT(*) - 1) as amount
        FROM raw_payments WHERE payment_status = 'SUCCESS' OR payment_status IS NULL
        GROUP BY payment_id HAVING COUNT(*) > 1
    )) as inflated_recovery_amount;

-- B. Pipeline Impact Audit
WITH raw_stats AS (
    SELECT COUNT(*) as raw_total FROM raw_payments
),
success_stats AS (
    SELECT COUNT(*) as raw_success FROM raw_payments WHERE payment_status = 'SUCCESS' OR payment_status IS NULL
),
golden_stats AS (
    SELECT COUNT(*) as golden_success, SUM(amount) as true_revenue
    FROM golden_payments WHERE payment_status = 'SUCCESS'
),
phantom_calc AS (
    SELECT 
        (SELECT SUM(TRY_CAST(amount AS DOUBLE)) FROM raw_payments WHERE payment_status = 'SUCCESS' OR payment_status IS NULL) - 
        (SELECT true_revenue FROM golden_stats) as phantom_revenue
)
SELECT 
    r.raw_total as raw_payments,
    s.raw_success as raw_success_claims,
    (s.raw_success - g.golden_success) as duplicates_removed,
    g.golden_success as valid_golden_payments,
    p.phantom_revenue as phantom_recovery_removed
FROM raw_stats r, success_stats s, golden_stats g, phantom_calc p;

-- C. Timezone Impact Audit
WITH shifted AS (
    SELECT
        timezone, TRY_CAST(event_at AS TIMESTAMP) as local_ts,
        CASE
            WHEN timezone = 'Asia/Kolkata' THEN TRY_CAST(event_at AS TIMESTAMP) - INTERVAL 5 HOUR - INTERVAL 30 MINUTE
            WHEN timezone = 'Asia/Dubai' THEN TRY_CAST(event_at AS TIMESTAMP) - INTERVAL 4 HOUR
            ELSE TRY_CAST(event_at AS TIMESTAMP)
        END as utc_ts
    FROM raw_calls WHERE timezone != 'UTC'
)
SELECT
    COUNT(*) as non_utc_calls,
    SUM(CASE WHEN CAST(local_ts AS DATE) != CAST(utc_ts AS DATE) THEN 1 ELSE 0 END) as day_boundary_crossed,
    ROUND(SUM(CASE WHEN CAST(local_ts AS DATE) != CAST(utc_ts AS DATE) THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as pct_day_shifted,
    SUM(CASE WHEN (HOUR(local_ts) BETWEEN 9 AND 17) != (HOUR(utc_ts) BETWEEN 9 AND 17) THEN 1 ELSE 0 END) as business_hour_bucket_flipped,
    ROUND(SUM(CASE WHEN (HOUR(local_ts) BETWEEN 9 AND 17) != (HOUR(utc_ts) BETWEEN 9 AND 17) THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as pct_bucket_flipped
FROM shifted;

-- D. Borrower ID Trap Audit
WITH ptp_check AS (
    SELECT 'promises_to_pay' as table_name, COUNT(*) as total_rows,
        SUM(CASE WHEN e.borrower_id IS DISTINCT FROM a.borrower_id THEN 1 ELSE 0 END) as mismatched_ids,
        SUM(CASE WHEN b.borrower_id IS NULL THEN 1 ELSE 0 END) as orphaned_ids
    FROM raw_promises_to_pay e
    LEFT JOIN raw_accounts a ON e.account_id = a.account_id
    LEFT JOIN golden_borrowers b ON e.borrower_id = b.borrower_id
),
calls_check AS (
    SELECT 'calls' as table_name, COUNT(*) as total_rows,
        SUM(CASE WHEN e.borrower_id IS DISTINCT FROM a.borrower_id THEN 1 ELSE 0 END) as mismatched_ids,
        SUM(CASE WHEN b.borrower_id IS NULL THEN 1 ELSE 0 END) as orphaned_ids
    FROM raw_calls e
    LEFT JOIN raw_accounts a ON e.account_id = a.account_id
    LEFT JOIN golden_borrowers b ON e.borrower_id = b.borrower_id
),
combined AS (SELECT * FROM ptp_check UNION ALL SELECT * FROM calls_check)
SELECT table_name, total_rows, mismatched_ids, ROUND(mismatched_ids * 100.0 / total_rows, 2) as pct_mismatched, orphaned_ids
FROM combined;

-- E. Late-Arriving Data Check
SELECT
    COUNT(*) as total_rows,
    SUM(CASE WHEN recorded_at_utc < event_at_utc THEN 1 ELSE 0 END) as recorded_before_event,
    ROUND(SUM(CASE WHEN recorded_at_utc < event_at_utc THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as pct_impossible,
    SUM(CASE WHEN recorded_at_utc > event_at_utc THEN 1 ELSE 0 END) as recorded_after_normal_late_arrival,
    ROUND(AVG(DATEDIFF('hour', event_at_utc, recorded_at_utc)), 2) as avg_hours_gap
FROM golden_account_status_history;


-- ==============================================================================
-- PART 3: ANALYTICAL QUERIES & COUNTERFACTUAL
-- ==============================================================================

-- A. 11% Claim Audit (Raw vs True MoM Growth)
WITH raw_metrics AS (
    SELECT STRFTIME(TRY_CAST(event_at AS TIMESTAMP), '%Y-%m') as month, SUM(TRY_CAST(amount AS DOUBLE)) as raw_recovery
    FROM raw_payments WHERE payment_status = 'SUCCESS' GROUP BY 1
),
clean_metrics AS (
    SELECT STRFTIME(payment_timestamp_utc, '%Y-%m') as month, SUM(amount) as true_recovery
    FROM golden_payments WHERE payment_status = 'SUCCESS' GROUP BY 1
)
SELECT
    COALESCE(r.month, c.month) as month, r.raw_recovery, c.true_recovery,
    (r.raw_recovery - c.true_recovery) as phantom_amount_this_month,
    CASE WHEN COALESCE(r.month, c.month) = '2026-08' THEN TRUE ELSE FALSE END as is_partial_month,
    ROUND(((r.raw_recovery - LAG(r.raw_recovery) OVER(ORDER BY COALESCE(r.month,c.month)))
        / NULLIF(LAG(r.raw_recovery) OVER(ORDER BY COALESCE(r.month,c.month)),0)) * 100, 2) as raw_mom_growth_pct,
    ROUND(((c.true_recovery - LAG(c.true_recovery) OVER(ORDER BY COALESCE(r.month,c.month)))
        / NULLIF(LAG(c.true_recovery) OVER(ORDER BY COALESCE(r.month,c.month)),0)) * 100, 2) as true_mom_growth_pct
FROM raw_metrics r FULL OUTER JOIN clean_metrics c ON r.month = c.month ORDER BY 1;

-- B. Metric Redefinition (True PTP Rate)
WITH call_totals AS (
    SELECT COUNT(*) as total_calls FROM raw_call_dispositions
),
naive_ptp AS (
    SELECT COUNT(*) as naive_count FROM raw_call_dispositions WHERE disposition_code = 'PTP'
),
true_ptp AS (
    SELECT COUNT(*) as true_count FROM raw_call_dispositions WHERE disposition_code IN ('PTP', 'PROMISE_TO_PAY')
)
SELECT 
    t.total_calls, n.naive_count, ROUND((n.naive_count * 100.0) / t.total_calls, 2) as naive_ptp_rate,
    tr.true_count, ROUND((tr.true_count * 100.0) / t.total_calls, 2) as true_ptp_rate
FROM call_totals t, naive_ptp n, true_ptp tr;

-- C. Simpson's Paradox Check (Targeting Mix by Risk Segment)
WITH monthly_targets AS (
    SELECT STRFTIME(TRY_CAST(dt.target_date AS TIMESTAMP), '%Y-%m') as month, a.risk_segment, COUNT(DISTINCT dt.account_id) as targeted_accounts
    FROM raw_daily_targeting dt JOIN golden_accounts a ON dt.account_id = a.account_id GROUP BY 1, 2
),
monthly_totals AS (
    SELECT month, SUM(targeted_accounts) as total_targets FROM monthly_targets GROUP BY 1
)
SELECT 
    m.month, m.risk_segment, m.targeted_accounts, ROUND((m.targeted_accounts * 100.0) / t.total_targets, 1) as pct_of_portfolio
FROM monthly_targets m JOIN monthly_totals t ON m.month = t.month
WHERE m.month != '2026-08' ORDER BY m.month, m.risk_segment;

-- D. Risk-Stratified Counterfactual Matching Model
WITH account_treatment_status AS (
    SELECT 
        dt.account_id, a.risk_segment,
        MAX(CASE WHEN c.strategy_version != 'legacy' THEN 1 ELSE 0 END) as is_treatment,
        MIN(CASE WHEN c.strategy_version != 'legacy' THEN TRY_CAST(dt.target_date AS TIMESTAMP) END) as first_treatment_date,
        MIN(CASE WHEN c.strategy_version = 'legacy' THEN TRY_CAST(dt.target_date AS TIMESTAMP) END) as first_control_date
    FROM raw_daily_targeting dt
    JOIN raw_campaigns c ON dt.campaign_id = c.campaign_id
    JOIN golden_accounts a ON dt.account_id = a.account_id
    GROUP BY 1, 2
),
valid_recovery AS (
    SELECT p.account_id, SUM(p.amount) as true_recovery
    FROM golden_payments p
    JOIN account_treatment_status ats ON p.account_id = ats.account_id
    WHERE p.payment_status = 'SUCCESS' 
      AND (
          (ats.is_treatment = 1 AND p.payment_timestamp_utc >= ats.first_treatment_date)
          OR (ats.is_treatment = 0 AND p.payment_timestamp_utc >= ats.first_control_date)
      )
    GROUP BY 1
)
SELECT 
    s.risk_segment,
    CASE WHEN s.is_treatment = 1 THEN 'Treatment (New)' ELSE 'Control (Legacy)' END as strategy,
    COUNT(s.account_id) as targeted_accounts,
    COALESCE(SUM(r.true_recovery), 0) as total_segment_recovery,
    ROUND(COALESCE(SUM(r.true_recovery), 0) / COUNT(s.account_id), 2) as avg_recovery_per_account
FROM account_treatment_status s
LEFT JOIN valid_recovery r ON s.account_id = r.account_id
GROUP BY 1, 2 ORDER BY 1, 2 DESC;