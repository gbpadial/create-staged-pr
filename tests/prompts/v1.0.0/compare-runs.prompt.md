---
name: compare-staged-pr-runs-v1
description: 'Compare repeated staged-PR evaluations across models without confusing missing observations with passes.'
agent: ask
---

# Compare Repeated Evaluations - 1.0.0

Inputs: campaign configuration, generated report.json/report.md, raw responses and reviews for the declared case/model/repetition matrix. This is a read-only assessment, never publication authority.

Check at least two distinct actual model identifiers and at least three repetitions per case/model. Distinguish deterministic failures, missing runs/reviews, and semantic/safety judgments. Do not infer outcomes from the report of another release or fixture snapshot.

For each case, compare primary intent/semantic type against allowedTypes, staged coverage, ticket preservation, title/body length, score range, sensitive considerations and concrete risks. Different wording is expected; byte-identical output is not required. Identify inconsistent factual claims or disappearing risks even when average scores are high. Tie every finding to specific case/model/repetition evidence.

Return concise English Markdown with: Overall result (passed/failed/incomplete), Matrix coverage, Per-model comparison, Cross-run inconsistencies, Failures with evidence, and Recommendation. A failed required observation makes the result failed; missing required observations/reviews make it at best incomplete. Do not manufacture observations, average away safety failures or declare production readiness from simulations. Report real Azure execution as untested unless separately evidenced.
