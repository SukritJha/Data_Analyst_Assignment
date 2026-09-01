# 📌 Collections Performance & Strategy Audit

**Core Objective:** Audit 12 months of collections data to verify a reported 11% month-on-month growth claim and allocate a ₹10 Cr operational investment[cite: 2].

### 🚨 1. Executive Verdict
* **Growth Claim:** The 11% growth is false[cite: 2]. It was an illusion caused by data duplication.
* **Investment ROI:** The new targeting strategy fails to show statistically significant causal lift when controlled for time biases.
* **Action:** **Hold the ₹10 Cr investment.** Initiate a strictly controlled A/B pilot instead.

---

### 🕵️‍♂️ 2. Data Forensics: The "Golden Dataset"
The raw synthetic data (Seed 42) spanned 17 relational datasets intentionally injected with structural flaws[cite: 6]. We built a reliable "Golden Dataset"[cite: 2] by fixing:

* **Phantom Recovery ➔** Deduplicated payment references and duplicate payment events[cite: 6]. 
* **Timezone Skew ➔** Standardized mixed UTC, Asia/Kolkata, and Asia/Dubai timestamps into strict UTC[cite: 6].
* **Fragmented IDs ➔** Resolved inconsistent identifiers and multiple agent identifiers[cite: 6].
* **Metric Blindspots ➔** Adjusted logic to capture both new and legacy disposition codes[cite: 6].

---

### 🧠 3. Counterfactual ROI (Targeting Strategy)
**Question:** What would recovery have looked like if we had not changed the targeting strategy?[cite: 2]

* **The Bias Trap ➔** Raw sums showed massive success, purely due to **attribution-window bias**[cite: 2]. Treatment accounts simply had more days to accrue payments.
* **The Fix ➔** Enforced a strict 90-day observation window for all accounts.
* **Financial Impact ➔** Incremental lift shrank to just ₹1,094 per account. 
* **Statistical Proof ➔** A bootstrap test 95% Confidence Interval crossed zero (indistinguishable from noise).

---

### 🏗️ 4. Production Data Architecture
Designed for daily leadership use, moving from raw ingestion to a 60-second CEO review[cite: 2].

**Data Pipeline Flow:**
`[Raw] ➔ [Staging] ➔ [Clean] ➔ [Golden] ➔ [Feature] ➔ [Metrics] ➔ [Dashboard]`[cite: 2]

* **1. Raw:** Ingest all 17 datasets natively with no schema enforcement[cite: 6].
* **2. Staging:** Detect late-arriving events[cite: 2, 6].
* **3. Clean:** Standardize timezones and resolve conflicting timestamps[cite: 6].
* **4. Golden:** Deduplicate and track overwritten-style status history[cite: 6].
* **5. Metrics:** Pre-aggregate data and enforce strict metric definitions[cite: 2].
* **6. Dashboard:** Output to a single executive screen optimized for decisions[cite: 2].
