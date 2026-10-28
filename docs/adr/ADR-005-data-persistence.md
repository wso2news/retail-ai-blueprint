# ADR-005: Data Persistence and Sharding Strategy

- **Status:** Proposed for evaluation
- **Context:** Retail order data has high read/write volume, especially during peak seasons. The aggregate pattern (order + embedded items) fits document databases. Cross-aggregate queries (customer orders, status filtering) require indexing strategy.
- **Decision:** Use MongoDB as the persistence layer for the order aggregate. Embed order items (bounded, read together). Reference customer and product by ID (separate aggregates). Propose `{customerId: "hashed"}` as shard key for uniform distribution and targeted reads. Store calculated totals (denormalized) for listing performance.
- **Alternatives considered:**
  - Relational database: viable but requires joins for order+items; document model fits the read pattern better.
  - Composite shard key `{customerId, _id}`: better locality but risks jumbo chunks for high-volume customers.
- **Consequences:** Single-document reads/writes are atomic. Cross-shard queries (by status, by SKU) require scatter-gather or supporting indexes. Shard key is difficult to change later.
- **Validation:** Load synthetic data, verify chunk distribution, run `explain()` on representative queries, measure write throughput under peak load.