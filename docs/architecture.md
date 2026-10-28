# Reference Architecture — Retail AI

## 1. Business problem

Retail organizations need reliable, grounded, and auditable AI assistance across commerce workflows: product discovery, order tracking, customer support, inventory intelligence, and pricing optimization. Incorrect answers, excessive permissions, uncontrolled automation, and tight coupling to a single AI provider create operational, security, and commercial risk.

## 2. Target outcomes

Set baselines before implementation. Candidate measures:

- Resolution rate without human intervention
- Evidence-supported answer rate
- Escalation rate for ambiguous or high-risk requests
- Median and p95 end-to-end latency
- Cost per resolved request
- Unauthorized-action rate
- User satisfaction and re-open rate
- Order accuracy and fulfillment time

Do not claim targets or improvements until they are agreed with stakeholders and measured.

## 3. Logical components

| Component | Responsibility | Key control |
|---|---|---|
| Experience/API | Accept requests and return responses | Authentication, rate limits, CORS |
| Identity and policy | Resolve identity, role, and allowed scope | Least privilege, deny by default |
| Orchestrator | Route work through defined workflows | Bounded workflows, timeouts |
| Retrieval | Search approved knowledge sources | Document-level authorization, source metadata |
| Model gateway | Route requests to approved models | Provider abstraction, quotas, data policy |
| Tool gateway | Expose approved commerce actions | Allowlist, schema validation, authorization |
| Approval service | Obtain human authorization for sensitive actions | Explicit approval and expiry |
| Evaluation | Test quality, safety, and regressions | Versioned datasets and release gates |
| Observability | Track health, cost, and outcomes | Redaction and retention controls |
| Knowledge ingestion | Index approved content | Provenance, access synchronization |
| Order domain | Manage order lifecycle and business rules | Hexagonal isolation, domain validation |
| Catalog domain | Product search, pricing, inventory | Cache, search engine, vector index |

## 4. Trust boundaries

1. User and client boundary
2. Enterprise identity and policy boundary
3. Retrieved documents and other untrusted content
4. Model provider boundary
5. Tool and enterprise-system boundary
6. Logging, evaluation, and data-retention boundary
7. Commerce system boundary (POS, inventory, fulfillment)

Treat retrieved content and tool outputs as data, not instructions. Authorization must be enforced outside the model.

## 5. Request lifecycle

1. Authenticate the caller.
2. Authorize access to the requested workflow and data.
3. Validate and classify the request.
4. Retrieve only documents the caller is permitted to access.
5. Generate an answer with source references.
6. Validate grounding, policy compliance, and uncertainty.
7. For sensitive operations (pricing change, inventory adjustment, order cancellation), create a proposal and wait for explicit approval.
8. Execute approved actions through narrowly scoped tools.
9. Return the result and record a privacy-aware audit event.
10. Capture feedback for evaluation.

## 6. Deployment options

| Option | Advantages | Trade-offs |
|---|---|---|
| Managed model + managed retrieval | Faster initial delivery, reduced model operations | Provider dependency, usage charges, data-processing review |
| Managed model + self-managed retrieval | More control over data and retrieval | Additional infrastructure and operational burden |
| Local model + local retrieval | Greater local control, potentially predictable marginal inference cost | Hardware capacity, quality variance, maintenance |
| Hybrid routing | Can balance task quality, latency, and cost | More routing logic, testing, and operational complexity |

Choose using workload requirements, data classification, latency, quality, residency, operational capability, and measured TCO — not vendor preference.

## 7. Failure behavior

- Retrieval unavailable: fail safely or route to a clearly identified fallback.
- Insufficient evidence: abstain or escalate; do not invent a policy answer.
- Model timeout: enforce a bounded retry policy and return a controlled error.
- Tool failure: do not imply that the action succeeded.
- Approval absent or expired: do not execute.
- Evaluation regression: block release until reviewed.

## 8. Architecture questions to resolve

- Which business workflow is in scope?
- What data classifications are allowed?
- Which identity provider and authorization source are authoritative?
- Which actions are read-only, reversible, sensitive, or irreversible?
- What are the latency, availability, and cost constraints?
- Who owns approval, incident response, and evaluation sign-off?
- What is the POS integration strategy (API vs. event-driven)?
- How is order data persisted and partitioned at scale?