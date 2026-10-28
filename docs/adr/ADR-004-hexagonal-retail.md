# ADR-004: Use Hexagonal Architecture for Retail Microservices

- **Status:** Accepted as a reference-design decision
- **Context:** Retail commerce systems require clear separation between business rules (order lifecycle, pricing, inventory) and infrastructure concerns (databases, messaging, HTTP, external providers). Multiple teams (Backend, Full Stack, DevOps) need a shared standard to avoid coupling and enable independent evolution.
- **Decision:** Use hexagonal architecture (ports and adapters) with DDD tactical patterns. Domain layer contains pure business rules with no framework dependencies. Application layer orchestrates use cases through ports. Infrastructure layer provides adapters (web, persistence, messaging, external POS). API contracts are defined with OpenAPI 3.0 before implementation.
- **Alternatives considered:**
  - Traditional MVC: rejected because business logic leaks into controllers and becomes difficult to test and evolve.
  - Layered architecture without ports: simpler initially but allows infrastructure details to leak into domain.
- **Consequences:** Domain is testable without Spring or databases. Adapters are replaceable. Slightly more boilerplate, but improved maintainability and testability.
- **Validation:** Domain tests must pass without Spring context. Coverage gate ≥70% on domain layer. Architecture tests (ArchUnit) should verify dependency direction.