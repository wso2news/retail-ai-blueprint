# ADR-003: Ground Answers in Authorized Sources

- **Status:** Accepted as a reference-design decision
- **Context:** General-purpose model knowledge may be stale, incomplete, or inappropriate for organization-specific policies, pricing, and inventory rules.
- **Decision:** Retrieve from approved, permission-filtered sources; retain source metadata; require evidence references for factual policy answers; abstain or escalate when evidence is insufficient.
- **Alternatives considered:**
  - Model-only answers: rejected for organization-specific operational guidance.
  - Fine-tuning as the primary knowledge store: rejected because it complicates frequent updates and does not replace access-controlled retrieval.
  - Retrieval without permission filtering: rejected due to cross-user disclosure risk.
- **Consequences:** Requires ingestion quality, access synchronization, retrieval evaluation, and source lifecycle management.
- **Validation:** Test citation support, outdated/conflicting sources, insufficient evidence, and cross-access attempts.