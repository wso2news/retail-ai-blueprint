# SPEC-REAL - retail-ai-blueprint

> Aprobada por LORD 2026-11-15. Fuente de verdad: docs/ + codigo real en este repo.
> HEAD: 2dbfa3853d80a7483f32497c92b0c4500375be46
> Repo: retail-ai-blueprint

## Alcance real

Blueprint de IA para retail: arquitectura hexagonal, autonomia acotada, portabilidad de proveedor, grounding por retrieval, persistencia de datos, performance y observabilidad.

## Evidencia verificable

- docs/architecture.md - arquitectura del sistema
- docs/adr/ADR-001-bounded-autonomy.md - autonomia acotada
- docs/adr/ADR-002-provider-portability.md - portabilidad de proveedor
- docs/adr/ADR-003-retrieval-grounding.md - grounding por retrieval
- docs/adr/ADR-004-hexagonal-retail.md - hexagonal retail
- docs/adr/ADR-005-data-persistence.md - persistencia
- docs/adr/ADR-006-performance-observability.md - performance y observabilidad
- docs/threat-model.md - modelo de amenazas
- docs/cost-analysis.md - analisis de costo
- docs/evaluation.md - evaluacion
- docs/operations.md - operaciones
- api-specification.md, architecture.md, data-model.md, implementation-plan.md, requirements.md, security.md, testing-strategy.md - espejos en raiz de docs/

## Reglas

- No inventar codigo que no existe. Este repo es blueprint / documentacion, no servicio ejecutable.
- Todo cambio futuro debe citar evidencia en docs/ o codigo.
- WRITE = 1 archivo de test que verifica que README.md existe, sin tocar codigo de producto.

## Estado

- SPEC-REAL aprobada. Pendiente WRITE test.
