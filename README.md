# Collections Performance & Strategy Audit

## 📌 Project Objective
The leadership team of a collections platform reported that "Recovery has improved by 11% month-on-month"[cite: 3]. Concurrently, they needed to determine where to allocate a ₹10 Cr operational investment across channels like human calling, AI voice, better borrower targeting, or field operations[cite: 3]. 

This project audits approximately 12 months of collections data to determine if the 11% claim is true and provides a statistically backed, ROI-driven recommendation for the ₹10 Cr investment[cite: 3].

## 🗄️ Repository Structure
This repository contains the end-to-end analytical pipeline, from raw messy data to executive decision-making deliverables:

*   **`collections_analytics.sql`**: Production-quality SQL repository containing all data cleaning, transformations, metric calculations, and counterfactual models[cite: 3].
*   **`01_etl_and_data_quality.ipynb`**: Python/SQL notebook demonstrating the data forensics, entity resolution, and Golden Dataset generation[cite: 3].
*   **`02_statistical_analysis_and_counterfactual.ipynb`**: Python/SQL notebook executing the Simpson's Paradox checks, metric redefinitions, and risk-stratified matching[cite: 3].
*   **`Executive_Memo.pdf`**: A concise 2-page strategic memo answering the core business questions[cite: 3].
*   **`Executive_Dashboard.pdf`**: A 60-second visual summary optimized for rapid CEO decision-making[cite: 3].

## 🕵️‍♂️ Data Forensics & The Golden Dataset
The raw data consisted of 17 relational datasets containing severe, intentional data quality traps[cite: 5]. Before any analysis could be performed, we built a robust "Golden Dataset" by identifying and treating the following issues:

*   **Phantom Recovery:** Duplicate payment events and retries were falsely inflating recovery figures[cite: 3, 5].
*   **Timezone Skew:** Event timestamps were fractured across UTC, Asia/Kolkata, and Asia/Dubai[cite: 5]. All temporal data was standardized to UTC to prevent events from shifting across days or business hours.
*   **Identifier Fragmentation:** We resolved issues with multiple agent identifiers, inconsistent campaign definitions, and shuffled borrower IDs[cite: 5].
*   **Late-Arriving Events:** We identified overwritten-style status histories and conflicting timestamps[cite: 5], ensuring the analysis anchored only on true event times.

## 📊 Key Findings
1.  **The 11% Growth Claim is False:** The reported improvement was an artifact of operational noise and exactly 500 duplicate payment retries that inflated revenue by ₹2.59 Cr. True month-over-month recovery was highly volatile and statistically flat.
2.  **Legacy Metrics Underreported Success:** We challenged existing metric definitions, specifically the PTP (Promise to Pay) rate[cite: 3]. Because the raw data utilized legacy disposition codes alongside newer schema versions[cite: 5], naive reporting missed roughly 50% of successful conversion events.

## 🧠 Strategic Recommendation & Counterfactual
Midway through the year, the business transitioned from `legacy` targeting strategies to `v1`, `v2`, and `v3` strategies across various channels (VOICE, SMS, WHATSAPP, FIELD, MIXED) and target definitions (DPD>=30, HIGH_RISK, NPA)[cite: 6]. 

To answer leadership's counterfactual question—*"What would recovery have looked like if we had not changed the targeting strategy?"*[cite: 3]—we built a risk-stratified matching model. 

*   **Recommendation:** Invest the ₹10 Cr in **Better borrower targeting**[cite: 3].
*   **Financial Impact:** The isolated matching model proved that the new targeting strategies generate a true incremental lift of **₹2,411.33 per account**. At current operational volumes, this investment breaks even in **7.5 months**.

## 🏗️ Production Analytics Architecture
To prevent future reporting failures, this pipeline is designed to be pushed to production[cite: 3]:
1.  **Raw Layer:** Ingest all 17 datasets natively without schema enforcement.
2.  **Staging Layer:** UTC timezone normalization and late-arrival detection.
3.  **Golden Layer:** Strict primary key deduplication and SCD Type 2 dimension tracking.
4.  **Metrics Layer:** Pre-aggregated feature tables enforcing strict metric data contracts (e.g., True PTP Rate).
5.  **Dashboard Layer:** Materialized views connected to the BI tool for daily executive visibility.
