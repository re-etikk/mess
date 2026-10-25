# MESS Operations Console — Security Matrix

| Capability | Super Admin | Operations | Finance | Support | Developer read-only |
|---|---|---|---|---|---|
| Provider review/approval | Yes, with audit | Yes, with reason | No | No | No |
| Suspend provider | Yes, with reason | Yes, with reason | No | Request only | No |
| Edit platform commission defaults | Yes, effective date + audit | No | Propose/review | No | No |
| See subscription/customer status | Need-based | Need-based | Limited to financial reconciliation | Minimum required for ticket | Masked/aggregated only |
| View full payment/settlement ledger | Yes, audited | Limited read | Yes | No | No |
| Issue refunds | Approval policy | Request only | Authorized, maker/checker | Request only | No |
| Change payout/bank destination | Step-up auth + maker/checker | No | Two-person approval | No | No |
| Manage team roles | Yes, MFA | No | No | No | No |
| View raw secrets/service-role key | Never via UI | Never | Never | Never | Never |
| View system health | Yes | Limited | Payment health only | Limited | Yes, masked |
| Feature flag change | Restricted + audit | No | No | No | Read-only |
| Export sensitive reports | Audited, scoped | Scoped | Finance data only | No | No |

## Required controls

- Admin session is authenticated and MFA-enabled for privileged roles.
- Server verifies role for each request, not just UI navigation.
- Admin roles are stored in a protected server-managed table, not user-editable metadata.
- Sensitive changes require reason, confirmation, actor identity and audit record.
- Prefer maker/checker for refunds above a configured threshold, settlement approval and payout destination changes.
- Audit log is append-only to application roles. Do not let UI users update or delete old audit records.
- Developer view uses masked logs and metadata. It must not expose customer PII, payment secrets or database credentials.
- Revoke sessions promptly after role removal or employee departure.
