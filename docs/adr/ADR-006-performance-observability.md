# ADR-006: Performance, Observability, and Alerting

- **Status:** Proposed for evaluation
- **Context:** Retail platforms must maintain service levels during peak demand (seasonal events, promotions). Without observability and alerting, degradation goes unnoticed until customers complain.
- **Decision:** Define SLOs before measuring (latency p95, error rate, availability). Use OpenTelemetry for distributed tracing. Export metrics and logs to cloud monitoring. Define alerts with runbooks. Run load tests with explicit pass/fail thresholds.
- **Alternatives considered:**
  - Reactive observability (add after problems): rejected because there is no baseline to compare against.
  - Vendor-specific agents only: rejected because it increases lock-in and reduces portability.
- **Consequences:** Requires upfront investment in instrumentation. Alerts without notification channels (SNS) are declarations, not operations. OTLP export must be validated end-to-end, not assumed.
- **Validation:** Load test with thresholds enabled and exit status checked. Verify log delivery, metric collection, and at least one alert firing with documented result.