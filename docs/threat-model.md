# Threat Model

## Trust boundaries

1. **User and client boundary** — web, mobile, POS terminals, admin portals.
2. **Identity and policy boundary** — authentication, authorization, role resolution.
3. **Retrieved documents and untrusted content** — catalog data, policies, third-party feeds.
4. **Model provider boundary** — data sent to and received from AI providers.
5. **Tool and commerce-system boundary** — inventory, pricing, order management, fulfillment.
6. **Logging, evaluation, and data-retention boundary** — what is recorded and for how long.

## Key risks

| Risk | Impact | Mitigation |
|---|---|---|
| Prompt injection via retrieved content | Model follows malicious instructions embedded in product descriptions or reviews | Treat retrieved content as data, not instructions; sanitize and validate outputs |
| Excessive permissions | Agent accesses or modifies data beyond its scope | Least-privilege tool allowlist; authorization outside the model |
| Data exfiltration | Sensitive customer or pricing data sent to external model provider | Data classification policy; redact PII; use private endpoints where available |
| Unauthorized price/inventory change | Financial loss, stock discrepancies | Human approval for irreversible actions; audit trail |
| Model hallucination | Incorrect product info, wrong order status, bad recommendations | Grounded retrieval; abstain when evidence is insufficient; citation requirements |
| Supply chain (dependencies) | Vulnerable libraries in production | Dependency scanning in CI; regular updates; SBOM |
| Secrets exposure | Credentials in code or logs | Secret scanning; Secrets Manager; no secrets in state or code |

## Controls

- **Authentication:** JWT-based resource server, issuer/audience validation, JWKS.
- **Authorization:** Object-level (customer sees only their orders), role-based scopes (read/write/manage).
- **Input validation:** Bean Validation on DTOs + domain invariants.
- **Secrets:** Environment variables, Secrets Manager, IAM least privilege.
- **Container:** Non-root user, image scanning.
- **Logs:** Structured, correlation ID, no PII/tokens.
- **Network:** Security groups, TLS in transit (required for production).
- **Rate limiting:** API Gateway/ALB+WAF, body size limits, pagination on list endpoints.

## Non-goals

- This threat model is a starting framework, not a security certification.
- Penetration testing and formal compliance require specialized review.