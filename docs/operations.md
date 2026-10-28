# Operations and Observability

## Purpose

Define how to operate and monitor AI-powered retail solutions in production. Observability must be designed in, not bolted on.

## Key signals

| Signal | What to track | Alert condition |
|---|---|---|
| Latency | End-to-end response time (p50, p95, p99) | p95 exceeds SLO for sustained period |
| Error rate | HTTP 5xx, model failures, tool failures | Error rate > threshold |
| Availability | Service health, dependency health | Service unavailable |
| Cost | Tokens, compute, retrieval per request | Cost spike beyond budget |
| Quality | Grounding rate, abstention rate, escalation rate | Quality degradation trend |
| Safety | Safety violations, unauthorized actions | Any safety violation |

## Observability stack

- **Logs:** Structured, correlation ID, redacted (no PII, no tokens).
- **Metrics:** Request count, latency, error rate, token usage, cost.
- **Traces:** Distributed tracing via OpenTelemetry (W3C trace context).
- **Alerts:** Threshold-based with runbooks and notification channels (SNS, PagerDuty).
- **Dashboards:** Operational view for on-call and business stakeholders.

## Alerting principles

- Alert on symptoms, not causes (latency, errors, not CPU spikes).
- Every alert must have a runbook.
- Avoid alert fatigue: tune thresholds with real data.
- Test alerts: at least one alert must fire and be documented.

## OTLP and tracing

- Instrument with OpenTelemetry (W3C trace context).
- Export to a collector (Jaeger locally, ADOT/X-Ray in AWS).
- Validate end-to-end: traces must be queryable and searchable.
- OTLP export failures must be detected, not silently ignored.

## Incident response

1. Identify scope and impact.
2. Review alerts, logs, and traces by correlation ID.
3. Verify dependency health (model provider, retrieval, databases).
4. Apply rollback if regression correlates with last deployment.
5. Document cause, mitigation, and preventive actions.

## Failure modes to plan for

- Model provider unavailable: fallback or controlled error.
- Retrieval unavailable: fail safely or route to fallback.
- Insufficient evidence: abstain or escalate.
- Model timeout: bounded retry, controlled error.
- Tool failure: do not imply success.
- Approval absent/expired: do not execute.