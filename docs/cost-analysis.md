# Cost and TCO Framework

## Purpose

Provide a structured approach to estimating and comparing costs for retail AI solutions. Costs depend on workload, provider, deployment model, and operational maturity.

## Cost categories

| Category | Examples | Notes |
|---|---|---|
| Model inference | Per-token charges, per-request fees | Dominant cost for LLM-based solutions |
| Retrieval/infrastructure | Vector database, search engine, caching | Scales with catalog size and query volume |
| Compute | ECS tasks, Lambda, EC2 instances | Baseline + variable; auto-scaling affects this |
| Storage | MongoDB, S3, EBS volumes | Order data, logs, embeddings |
| Networking | ALB, data transfer, NAT Gateway | Often underestimated |
| Observability | CloudWatch, X-Ray, log storage | Retention policies matter |
| Development | Engineering time, CI/CD runners, tooling | Often the largest cost |
| Compliance | Security review, penetration testing, audit | Required for production |

## Estimation approach

1. Define the **workload profile**: requests/day, peak concurrency, average tokens per request.
2. Identify **cost drivers**: model tokens, retrieval queries, compute hours, storage GB.
3. Estimate **per-unit cost** for each driver at the chosen provider.
4. Apply **growth factors**: seasonal peaks, catalog growth, user adoption.
5. Include **operational overhead**: monitoring, on-call, maintenance.
6. Compare **options** (managed vs. self-hosted, single vs. multi-model).

## Key trade-offs

- **Managed services** reduce operational burden but increase per-unit cost and provider dependency.
- **Self-hosted** models reduce marginal inference cost but require hardware capacity, maintenance, and quality validation.
- **Caching** reduces model calls but adds complexity and stale-data risk.
- **Hybrid routing** (fast model for classification, large model for reasoning) can balance cost and quality.

## What to avoid

- Claiming savings without measured data.
- Comparing providers on price alone (quality, latency, reliability matter).
- Ignoring seasonal peaks and growth.
- Treating infrastructure cost as the only cost (engineering time dominates early phases).