# Collections Performance & Strategy Audit

## 📌 Project Objective
The leadership team of a collections platform reported that "Recovery has improved by 11% month-on-month"[cite: 2]. Concurrently, they needed to determine where to allocate a ₹10 Cr operational investment across channels[cite: 2].
This project audits approximately 12 months of collections data to determine if the 11% claim is true and provides a statistically backed, ROI-driven recommendation for the ₹10 Cr investment[cite: 2].

## 🗄️ Repository Structure
* **`collections_analytics.sql`**: Production-quality SQL repository containing all data cleaning, transformations, metric calculations, and counterfactual models[cite: 2].
* **`01_etl_and_data_quality.ipynb`**: Python/SQL notebook demonstrating data forensics and Golden Dataset generation.
* **`02_statistical_analysis_and_counterfactual.ipynb`**: Python/SQL notebook executing Simpson's Paradox checks and risk-stratified matching.
* **`Executive_Memo.pdf`**: A concise 2-page strategic memo answering the core business questions[cite: 2].
* **`Executive_Dashboard.pdf`**: A 60-second visual summary optimized for rapid CEO decision-making[cite: 2].

## 🕵️‍♂️ Data Forensics & The Golden Dataset
The raw data consisted of 17 relational datasets containing severe, intentional data quality traps[cite: 3]. Before analysis, we built a robust "Golden Dataset" by treating:
* **Phantom Recovery**: Duplicate payment references were falsely inflating recovery figures[cite: 3]. 
* **Timezone Skew**: Event timestamps were fractured across UTC, Asia/Kolkata, and Asia/Dubai[cite: 3]. All temporal data was standardized to UTC.
* **Identifier Fragmentation**: We resolved issues with multiple agent identifiers and inconsistent campaign definitions[cite: 3].
* **Late-Arriving Events**: We identified overwritten-style status history and conflicting timestamps[cite: 3].

## 📊 Key Findings
* **The 11% Growth Claim is False**: The reported improvement was an artifact of exactly 500 duplicate payment retries that inflated revenue by ₹2.59 Cr. True recovery was statistically flat.
* **Legacy Metrics Underreported Success**: Because the raw data utilized legacy disposition codes alongside newer schema versions[cite: 3], naive PTP reporting missed roughly 50% of true conversion events.

## 🧠 Strategic Recommendation & Counterfactual
Midway through the year, the business transitioned from legacy targeting strategies to v1, v2, and v3 strategies[cite: 5]. 
To answer leadership's counterfactual question—"What would recovery have looked like if we had not changed the targeting strategy?"[cite: 2]—we built a risk-stratified matching model.

* **The Bias Trap:** Initial raw sums suggested massive success, but this was driven by **attribution-window bias**[cite: 2]. Treatment accounts simply had longer timeframes to accrue payments.
* **The Fix:** We enforced a strict 90-day observation window for both groups.
* **Financial Impact:** Normalized data reveals the new targeting strategies generate an incremental lift of only **₹1,094.47 per account**. A 1000-iteration bootstrap test resulted in a 95% Confidence Interval that crosses zero ([-₹329.79 to ₹2304.51]), meaning the lift is statistically indistinguishable from noise.
* **Recommendation:** **HOLD the full ₹10 Cr investment.** The data is insufficient to make a reliable recommendation for full deployment[cite: 2]. Recommend launching a strictly controlled A/B pilot with rigid 90-day attribution windows to prove causal lift.

## 🏗️ Production Analytics Architecture
To prevent future reporting failures, this pipeline is designed for production:
* **Raw Layer**: Ingest all 17 datasets natively.
* **Staging Layer**: UTC timezone normalization and late-arrival detection.
* **Golden Layer**: Strict primary key deduplication and SCD Type 2 dimension tracking.
* **Metrics Layer**: Pre-aggregated feature tables enforcing strict metric data contracts.
* **Dashboard Layer**: Materialized views connected to the BI tool for daily executive visibility.
