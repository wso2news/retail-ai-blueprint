# ADR-002: Isolate Model and Cloud Provider Dependencies

- **Status:** Accepted as a reference-design decision
- **Context:** Model capabilities, pricing, availability, and contractual terms change. Tight coupling increases switching cost and reduces negotiation leverage.
- **Decision:** Define a provider-neutral application contract for model requests, metering, timeouts, errors, and policy metadata. Keep provider-specific adapters and configuration separate. Support multiple models for different tasks (e.g., fast model for classification, large model for reasoning).
- **Alternatives considered:**
  - Single-provider implementation throughout: simpler initially but increases lock-in.
  - Abstract every provider feature: rejected because it can erase useful provider-specific capabilities and add needless complexity.
- **Consequences:** Easier comparative testing and potential migration; an abstraction layer must still expose provider-specific limitations explicitly.
- **Validation:** Run the same representative evaluation suite against each supported adapter and document unsupported features.