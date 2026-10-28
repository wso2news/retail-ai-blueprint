# Evaluation Plan

## Purpose

Define how to test quality, safety, and regressions of AI-powered retail solutions before release. Evaluation must be repeatable, versioned, and tied to explicit release gates.

## Evaluation dimensions

| Dimension | What to measure | Example metric |
|---|---|---|
| Grounding | Answer supported by retrieved evidence | Citation support rate |
| Accuracy | Factual correctness of responses | Fact-check pass rate |
| Safety | No harmful, unauthorized, or policy-violating content | Safety violation rate |
| Latency | End-to-end response time | p50, p95, p99 |
| Cost | Resource consumption per request | Tokens, compute, retrieval cost |
| Abstention | Correct refusal when evidence is insufficient | Appropriate abstention rate |
| Escalation | Correct routing to human when needed | Escalation accuracy |

## Test set design

1. Define representative queries from real commerce workflows.
2. Include edge cases: ambiguous questions, out-of-scope requests, conflicting sources, adversarial inputs.
3. Version the test set and track changes.
4. Separate training/validation/test splits to avoid overfitting.

## Release gates

- All critical safety tests must pass.
- Grounding rate must meet the agreed threshold.
- p95 latency must be within SLO.
- Cost per request must be within budget.
- No regression in previously passing tests.

## Regression testing

- Re-run the full evaluation suite on every change (model, prompt, retrieval, or policy).
- Track metric trends over time.
- Block release on regression until reviewed and approved.

## What to avoid

- Claiming accuracy without a test set.
- Using the same data for tuning and evaluation.
- Ignoring safety metrics in favor of accuracy alone.
- Treating evaluation as a one-time activity.