# Privacy matrix shape — controller-vs-processor, regulation matrix, sub-processor disclosure, DPIA trigger, 72-hour breach

How to write `## Privacy Posture` in `legal-posture.md`. The load-bearing disciplines from anthill-privacy-dpo + the calibration rules that make the privacy section smart, not rigid.

## Controller vs processor — per-flow declaration

The company's privacy role is NOT a single product-wide attribute. Declare per data flow:

- **Controller** for first-party data the user provides to use the product — account email, billing address, profile info, content the user creates inside the workspace.
- **Processor** for second-party data the customer's end-users generate when the product is B2B SaaS — workspace content, customer-end-user usage events. The customer is the controller; the company is the processor under DPA terms (GDPR Art 28 / LGPD Art 39).
- **Joint controller** (rare; avoid the framing in v1) when the company and the customer jointly determine purpose AND means of processing. Most B2B SaaS is processor-only for customer-end-user data.

Mixed models are common — a B2B SaaS is *controller* for the workspace owner's account info AND *processor* for the workspace's end-user content AND *controller again* for analytics on usage patterns (the company decides what events to track and why). Explicit per-flow declaration prevents the "we're both controller and processor depending on context" ambiguity that fails GDPR Art 28 audits.

### Canonical declaration shape

```markdown
**Controller-vs-processor role (per flow):**

- **First-party account data** (email, password hash, billing address, MFA secret): **Controller**. Company determines purpose (account management, billing, security) and means (storage, encryption, retention).
- **Workspace content** (issues, comments, attachments uploaded by customer end-users): **Processor**. Customer is the controller; company processes per DPA terms.
- **Aggregate product analytics** (feature usage events, performance metrics, error logs): **Controller** (over the aggregate data) AND **Processor** (over per-customer telemetry — customer can opt out at workspace level). Mixed model — explicit because the audit surface differs.
- **Marketing leads** (email opt-ins, contact form submissions): **Controller**. Consent under Art 6(1)(a) is the legal basis; opt-out unsubscribe must be in every email.
```

### Anti-pattern: "we are the controller" blanket statement

```markdown
The Company is the controller for all personal data processed by the Service.
```

False for B2B SaaS — the customer's end-users' data is processor-only territory. Blanket statements fail GDPR Art 28 audits because they incorrectly accept controller obligations for data the company has no controller relationship with.

## Regulation matrix — the dense load-bearing table

The § Privacy Posture § Applicable regulations table is the heart of the privacy section. Format:

```markdown
| Regulation | Trigger | Applicable? | Posture | Counsel review trigger |
|---|---|---|---|---|
| GDPR | EU residents in user base | Yes | DPA + SCCs Module 2 for EU→US transfers; per-purpose consent for marketing emails; 72-hr breach notification to relevant DPA; DPIA for biometric-login feature | Counsel signs off on Privacy Policy + DPA template before first EU customer signs |
| LGPD | Brazil residents in user base | Yes | DPO designated; ANPD breach notification SLA documented; per-purpose consent matching GDPR; international transfer mechanism = SCCs Module 2 (LGPD Art 33) | Counsel signs off on ANPD compliance plan before public launch in BR |
| CCPA / CPRA | California consumers in user base (US-only product or US-included global) | Yes | "Do Not Sell" link present (even if no sale — disclosure mandatory); deletion + access request SLA = 45 days; financial incentive disclosure if loyalty/discount tied to data collection | Counsel signs off on CCPA opt-out flow before US launch |
| PIPEDA | Canadian residents | Conditional — applies if Canadian user volume > minimal | Privacy notice in plain language; consent for secondary purposes; cross-border transfer disclosure | Counsel signs off if Canadian user volume crosses 1k threshold |
| COPPA | Children under 13 reasonably foreseeable in user base | Conditional — applies if minors are foreseeable users (consumer apps almost always trigger) | Age-gate before account creation; verifiable parental consent for under-13; no behavioral advertising to under-13; safe-harbor program opt-in | Counsel signs off on age-gate UX + parental-consent flow before public launch |
| HIPAA | Health data (PHI as defined in 45 CFR 160.103) flows through the product | Conditional — fires if any health data is processed | Covered-entity vs business-associate determination; BAA template with customers; encryption FIPS 140-2 compliant; breach notification 60-day SLA | Counsel signs off on BAA template + BA model before first health-data feature ships |
```

### Posture column discipline

Each posture sentence carries 2-3 SPECIFIC commitments, NOT "we comply with X". Anti-pattern: "GDPR | EU residents | Yes | We are GDPR compliant". Useless — every product claims GDPR compliance; the posture section's job is to surface the *specific* commitments that distinguish "compliant" from "compliant in name only".

### Counsel review trigger column

Every applicable row has a counsel-review trigger — the specific event that fires the outside-counsel sign-off. Common triggers:

- First customer of class X (first EU customer for GDPR; first California consumer for CCPA; first BR resident for LGPD)
- First feature of class X (first health-data feature for HIPAA; first AI-classification feature for AI Act high-risk)
- Public launch (CCPA / COPPA / state employment privacy laws all fire at public launch)
- Annual review (SOC 2 Type II observation window starts)

Without a trigger column, the row degrades to "counsel will review eventually" — the procrastination mode the discipline catches.

## Data categories table

Per anthill-privacy-dpo § Step 3 template. One row per data category:

```markdown
| Data Category | Purpose | Legal Basis | Retention Period | Deletion Mechanism |
|---|---|---|---|---|
| Email address (account) | Transactional communications, account recovery | Contract (GDPR Art 6(1)(b)) | Duration of subscription + 30 days post-cancellation | User-initiated via Settings → Delete Account (90-day grace); admin-initiated via support ticket within 7 days |
| Password hash | Authentication | Contract (Art 6(1)(b)) | Duration of subscription + 30 days | Cascade with account deletion |
| Workspace content (issues, comments, attachments) | Product functionality | Contract (Art 6(1)(b)) — customer is controller, company is processor | Customer-controlled retention per DPA terms; default 7 years; customer can set lower retention per workspace | Customer-initiated via workspace settings; cascade with workspace deletion |
| Usage analytics (page views, feature toggles, performance events) | Product improvement | Legitimate Interest (Art 6(1)(f)) — balancing test documented; opt-out available | 24 months from collection, then aggregated and anonymized | Per-user opt-out via Settings → Privacy; cohort-level via workspace admin |
| Marketing preferences (newsletter opt-in, product update opt-in) | Email marketing | Consent (Art 6(1)(a)) — unbundled per-purpose opt-in at signup | Until withdrawn + 12 months for re-opt-in window | Unsubscribe link in every email (immediate); Settings → Email Preferences |
| Support ticket content | Customer support | Contract (Art 6(1)(b)) | 2 years from ticket close | Auto-purged via support tool; user can request earlier via DPO email |
```

### Legal basis values (per GDPR Art 6)

- **Consent (Art 6(1)(a))** — explicit, unbundled, per-purpose, withdrawable. Default for marketing email + non-essential cookies + behavioral advertising. NOT the default for account/billing flows.
- **Contract (Art 6(1)(b))** — necessary to perform a contract with the data subject. Default for account creation + billing + core product functionality.
- **Legal Obligation (Art 6(1)(c))** — required by law. Default for tax records + breach notification + records-of-processing.
- **Vital Interest (Art 6(1)(d))** — protect life. Rare in B2B SaaS; relevant for healthcare emergency-response features.
- **Public Task (Art 6(1)(e))** — exercise of official authority. Almost never applies to private companies.
- **Legitimate Interest (Art 6(1)(f))** — necessary for legitimate interests pursued by the controller, balanced against data-subject rights. Default for product analytics + fraud prevention + security monitoring. Requires documented balancing test (Legitimate Interest Assessment — LIA).

### Anti-pattern: Consent as default

Anthill-privacy-dpo anti-pattern #1. Consent looks deferential but creates fragility — withdrawal of consent forces feature removal. Use Contract for account/billing flows; Legitimate Interest (with documented LIA) for analytics; Consent only where withdrawal-without-feature-loss is acceptable (marketing email, behavioral ads).

## Sub-processor disclosure table

Per GDPR Art 28(2) and LGPD Art 39 — the controller's prior authorization for each sub-processor. Format:

```markdown
| Sub-processor | Purpose | Data Categories | DPA Reference | Cross-Border Mechanism |
|---|---|---|---|---|
| Stripe | Payment processing | Billing address, last 4 of card, transaction history | https://stripe.com/legal/dpa | SCCs Module 2 (controller→processor) for EU data |
| Auth0 | Authentication | Email, password hash, MFA secret, session metadata | https://auth0.com/docs/secure/data-privacy-and-compliance/auth0-dpa | SCCs Module 2 for EU data; Auth0 EU region available |
| OpenAI | LLM features for issue summarization, semantic search | Customer-controlled — content submitted to LLM at customer's per-feature opt-in | https://openai.com/policies/data-processing-addendum | SCCs Module 2; OpenAI EU data residency available since 2024 |
| Sentry | Error monitoring | Stack traces, user-agent strings, IP addresses, error event payloads (PII-scrubbed at SDK layer) | https://sentry.io/legal/dpa/ | SCCs Module 2 for EU data |
| PostHog | Product analytics | Event payloads, user identifiers, session recordings (opt-in only) | https://posthog.com/handbook/company/security#data-processing-agreement | SCCs Module 2; PostHog EU Cloud option |
| Resend | Transactional email | Recipient email address, message content (transactional only — no marketing) | https://resend.com/legal/dpa | SCCs Module 2; US-hosted, EU customers via SCCs |
| Vercel | Web application hosting | All processed data (transit) | https://vercel.com/legal/dpa | SCCs Module 2; EU region available |
| Neon | Postgres database hosting | All stored data (at rest) | https://neon.tech/dpa | SCCs Module 2; EU region available |
```

### Sub-processor exhaustiveness rule

Every third party that touches personal data appears in the table. "We use various third-party services" prose fails GDPR Art 28(2). Vague entries ("our cloud provider", "our email service") fail too — name the specific vendor.

### Adding new sub-processors

GDPR Art 28(2) requires the controller's *general or specific prior authorization* for new sub-processors. Posture: company commits to 30-day advance notice of new sub-processors via in-product banner + email; customer can object by terminating the contract within the notice period.

## DPIA trigger heuristic — GDPR Art 35

When the following fires (any one is sufficient), DPIA is MANDATORY before processing commences:

- **Systematic monitoring of public areas at scale** (CCTV + facial recognition; not typical SaaS but flag for clarity)
- **Sensitive data at scale** (health, biometric, racial / ethnic origin, political opinions, religious beliefs, sexual orientation, genetic data, criminal convictions) — "at scale" interpreted per WP29 guidance as ≥5,000 data subjects OR ≥250,000 events
- **Automated decision-making with legal or similarly significant effects** (credit scoring, employment decisions, automated content moderation that bans accounts, AI-driven triage that affects user outcomes materially)
- **Large-scale profiling** — building user profiles that drive personalized recommendations / pricing / content ordering at scale
- **Innovative use of new technologies** — novel applications that lack established precedent (early LLM features in 2023-2024 qualified; by 2026 LLM features in B2B SaaS may NOT trigger by novelty alone — fact-specific)
- **Combining datasets that would surprise the data subject** — joining purchase data + location data + biometric data

### Anti-pattern: "We'll do a DPIA when we have time"

DPIA is BEFORE processing, not after. Processing starts ANY time the system is configured to collect the data, not when users first generate it. Procrastinated DPIA = retroactive compliance theater that fails enforcement.

### DPIA scope shape

A DPIA covers: (1) description of processing operations + purpose; (2) necessity + proportionality assessment; (3) risk to data subjects' rights; (4) mitigation measures. Outside counsel + the DPO co-author the actual DPIA artifact; the posture document names the trigger + the engagement timing.

## 72-hour breach notification — GDPR Art 33

When a personal data breach is detected:

- **Within 72 hours of becoming aware**, notify the supervisory authority (the lead DPA — Ireland DPC for EU-resident-data-flowing-through-Ireland-entity; per-country DPA for direct exposure)
- Include: nature of breach, categories + approximate number of data subjects affected, likely consequences, mitigation measures taken
- **Within reasonable time** (typically within the same 72 hours), notify affected data subjects when high risk to their rights and freedoms is likely (Art 34)

### LGPD parallel (ANPD)

LGPD Art 48 requires notification to ANPD + affected data subjects "in a reasonable time frame as defined by ANPD" — currently 2 business days for high-risk breaches per ANPD Resolution CD/ANPD 15/2024.

### Posture-document commitment

The posture document commits to the SLA + the internal escalation playbook (who detects → who decides notification → who drafts the notice). The actual playbook lives in `security.md`; the posture row names the SLA.

```markdown
**Breach notification commitment:**

- Detection-to-decision: 4 hours (security on-call → CTO → DPO)
- Decision-to-supervisory-authority: 72 hours (GDPR Art 33) / 2 business days (LGPD ANPD)
- Decision-to-affected-data-subjects: 72 hours when high risk to rights and freedoms is likely (Art 34)
- Internal playbook: `docs/security.md § Incident Response`
- Annual tabletop exercise: documented in `security.md § Incident Response § Tabletop Cadence`
```

## DSAR-window-per-regulation precision

Data Subject Access Request (DSAR) response windows are **per-regulation, NOT a blanket SLA**. Posture-document commits should name the per-regulation window AND default to the strictest applicable window when multiple regulations apply.

| Regulation | DSAR response window | Extension | Citation |
|---|---|---|---|
| GDPR (EU) | 30 days | +60 days for complex requests; data subject notified within the initial 30-day window | Art 12(3) |
| LGPD (Brazil) | 15 days | No statutory extension; ANPD may issue guidance | Art 19 |
| CCPA / CPRA (California) | 45 days | +45 days for complex requests; consumer notified within the initial 45-day window | § 1798.130(a)(2) |
| PIPEDA (Canada) | 30 days | +30 days for complex requests | s. 8(3) |
| HIPAA (US health) | 30 days (designated record set) | +30 days one-time extension | 45 CFR § 164.524(b)(2) |
| UK GDPR | 30 days | +60 days for complex requests | Art 12(3) (mirrors EU GDPR) |
| Swiss FADP | 30 days | Reasonable extension on notification | Art 25 |

### Default to the strictest applicable window

When a product serves users across multiple jurisdictions, the operational SLA should default to the strictest applicable window across the user base — typically **LGPD's 15 days** for any product with Brazilian users. The blanket "30-day response" anti-pattern under-serves LGPD subjects and creates regulatory exposure.

### Posture-document shape

```markdown
**Data Subject Rights — DSAR response commitments:**

- **GDPR (EU):** 30 days per Art 12(3); +60 day extension available for complex requests with notification
- **LGPD (Brazil):** **15 days per Art 19** — strictest applicable window; operational default
- **CCPA / CPRA (California):** 45 days per § 1798.130(a)(2); +45 day extension available
- **PIPEDA (Canada):** 30 days per s. 8(3); +30 day extension available
- **Internal operational SLA:** **15 days across all jurisdictions** (defaults to LGPD strictness; over-serves GDPR / CCPA / PIPEDA at no cost)
```

### Anti-pattern: blanket "30-day response"

```markdown
**DSAR response window:** 30 days for all data subjects.
```

Under-serves LGPD subjects (15-day window) by 15 days; the LGPD subject is told their request will be answered in 30 days when statute requires 15. Counsel reading this catches it; the agent writing the posture should catch it first.

## GDPR article-grid matrix — fillable template

When GDPR applies AND the product is non-trivial (more than the smallest dev-tool class), the § Privacy Posture includes an article-grid sub-section as the reusable audit substrate counsel hands to enterprise customers during procurement. Format:

```markdown
### GDPR article-grid (Applicable / Control / Evidence-location)

| Article | Requirement | Applicable? | Control | Evidence location |
|---|---|---|---|---|
| Art 5 | Principles relating to processing (lawfulness, fairness, transparency, purpose limitation, data minimisation, accuracy, storage limitation, integrity/confidentiality, accountability) | Yes | Data-categories table limits collection to identified purposes; retention schedule enforces storage limitation; security measures section addresses integrity/confidentiality | `legal-posture.md § Data Categories`, `§ Security Measures` |
| Art 6 | Lawfulness of processing (legal basis required for every processing activity) | Yes | Each processing activity in the data-categories table mapped to a specific Art 6(1) basis (Contract / Legitimate Interest / Consent / Legal Obligation) | `legal-posture.md § Legal Basis`, `§ Data Categories` |
| Art 7 | Conditions for consent (where consent is the basis) | Partial / Yes / No | Marketing email + AI features rely on granular opt-in; revocation surface = in-app settings | `legal-posture.md § Legal Basis`; gap: granular in-app revocation UI is v1.x deliverable |
| Art 8 | Child's consent (under 16, or as Member State lowers to 13) | No (if product not directed to minors) / Yes (if minors are reasonably foreseeable) | Age-gate at signup; representation of legal age (18+); no behavioral advertising to under-13 | `legal-posture.md § Scope`, `§ Regulated Aspects § COPPA` |
| Art 12 | Transparent information, communication, modalities (free of charge, plain language) | Yes | Privacy Policy is the canonical transparent notice; presented at signup and accessible from in-app footer | `legal-posture.md`; planned in-app placement: `/legal/privacy` |
| Art 13 | Information to be provided where data are collected from the data subject | Yes | Signup flow presents Privacy Policy and consent statements before account creation | `legal-posture.md`, `prototype-v2/screens/02-onboarding.html` |
| Art 14 | Information to be provided where data have NOT been obtained from the data subject (e.g. imported corpus from third-party tools) | Partial | Imported corpus carries identifiers of individuals who are not the product's User; Customer Controller responsible for notifying under Art 14; product surfaces this in DPA + import flow | `legal-posture.md § Data Categories`; gap: in-app notice to Customer Controller about Art 14 obligations at import time is a polish deliverable |
| Art 15-22 | Data subject rights (access, rectification, erasure, restriction, portability, objection, automated decisions) | Yes | Procedures documented in § Data Subject Rights; 15-30-45 day response windows per regulation; manual handling at v1; DSAR runbook is a polish deliverable | `legal-posture.md § Data Subject Rights`; gap: DSAR runbook documentation is a polish deliverable |
| Art 24 | Responsibility of the controller (appropriate technical and organisational measures) | Yes | Security measures section documents the v1 baseline; `security.md` is the engineering-readable elaboration | `legal-posture.md § Security Measures`, `security.md` |
| Art 25 | Data protection by design and by default | Partial | Pseudonymization in IP storage (IP-class only, never full IP); non-enumerable primary keys; minimal-permission OAuth scopes; gap: no formal "privacy by design review" gate in engineering process | `legal-posture.md § Security Measures`, `system-design.md § Data Model`, `security.md § Threat Model` |
| Art 28 | Processor (engagement of sub-processors; written contract; equivalent obligations downstream) | Yes | Each sub-processor has a published DPA with the company; customer-facing DPA (separate document) flows down Art 28 obligations to the Customer Controller's processor role for imported data | `legal-posture.md § Sub-Processors`; planned DPA: separate document, canonical version part of the legal-posture deliverable |
| Art 30 | Records of processing activities (RoPA) | Yes | Internal RoPA maintained at `docs/compliance/ropa.md` (founder-authored, reviewed quarterly); the data-categories table is the customer-facing extract | `docs/compliance/ropa.md` (planned deliverable); evidence of intent: `legal-posture.md § Data Categories` |
| Art 32 | Security of processing (encryption, pseudonymisation, restoration after incident, regular testing) | Partial / Yes | TLS 1.3 in transit; column-encryption for sensitive tokens; storage-level encryption inherited from sub-processors; gap: no formal "regular testing" cadence beyond annual sensitive-secret-leak drill | `legal-posture.md § Security Measures`, `security.md § Secrets`; gap: penetration test schedule is a v1.x deliverable |
| Art 33 | Notification of a personal data breach to the supervisory authority (72 hours) | Partial / Yes | Incident response plan covers detection and internal escalation; supervisory authority notification SOP documented in security playbook | `legal-posture.md § Breach notification`, `security.md § Threat Model § Incident Response` |
| Art 34 | Communication of a personal data breach to the data subject (without undue delay when high risk) | Partial / Yes | Template communication for data-subject breach notification drafted as polish deliverable | gap: data-subject breach-notification template is a polish deliverable |
| Art 35 | Data protection impact assessment for high-risk processing | Yes (DPIA required) / Yes (no DPIA required at v1) | DPIA trigger analysis concludes no DPIA required at v1; template on file for v2 AI-assisted features when funded | `legal-posture.md § DPIA Trigger Statement` |
| Art 37 | Designation of the data protection officer | No (not mandatory at SMB scale) / Yes (mandatory) | Company is not a public authority, does not perform regular and systematic monitoring on large scale, does not process special categories at scale; DPO designation not mandatory at v1; contact privacy@<domain> routes to founder | `legal-posture.md § DPO Contact` |
| Art 44-49 | Transfers to third countries | Yes | SCCs Module 2 with each sub-processor; current data residency is named region; EU-region residency deferred per documented deciding signal | `legal-posture.md § Sub-Processors`, `system-design.md § Open Decisions` |
```

### How to populate

The agent fills the `Applicable? / Control / Evidence location` columns with project-specific entries — citing the legal-posture document itself, the system-design document, the security playbook, the cost-estimate, and the roadmap. Gaps that surface (rows where Control is "partial" or Evidence-location names a deferred deliverable) become § Open Decisions rows OR § Risks entries.

### Why this is reusable audit substrate

Enterprise customers during procurement send the company a "GDPR readiness questionnaire" with these articles enumerated. The article-grid IS that questionnaire pre-answered. Without it, every procurement cycle re-derives the same map; with it, the same artifact serves: (1) outside-counsel briefing (the document's primary purpose); (2) enterprise procurement (handed to customer's compliance team); (3) regulator inquiry (handed to lead DPA on Art 30 record request); (4) internal RoPA bootstrapping (the Art 30 record is a structurally similar table).

### When to omit

Omit the article-grid for: (a) Micro-Product / CLI helper / dev-tool with no GDPR exposure (no EU users, no EU customers, no EU sub-processors); (b) products where the broader Privacy Posture is in compact-degenerate mode (no PII collected); (c) products where GDPR applicability is genuinely conditional + no EU customer has materialized AND no design-partner is EU-based (in which case the matrix appears as a forward-anchor in § Open Decisions row "Build GDPR article-grid before first EU customer signs"). For any product with active GDPR applicability, the article-grid is mandatory — it is the audit substrate, not optional decoration.

## Cross-border transfers — when data leaves the EU/UK/Brazil/etc

Default mechanism for EU→US transfer: **SCCs Module 2** (controller→processor). Module 1 (controller→controller), Module 3 (processor→processor), Module 4 (processor→controller) for the other shapes. Adequacy decisions cover some destinations (UK, Switzerland, Japan, Canada commercial data, Israel, Argentina, Uruguay, Faroe Islands, Guernsey, Isle of Man, Jersey, New Zealand, South Korea, Andorra) — list adequacy WHERE adequacy applies, fall back to SCCs WHERE adequacy doesn't.

### Data Privacy Framework (DPF) — US-specific

The EU-US Data Privacy Framework (replacing the invalidated Privacy Shield) is an adequacy decision specific to companies that self-certify with the US Department of Commerce. Posture: if the company OR any sub-processor is DPF-certified, the framework may be used as an adequacy mechanism. Most B2B SaaS rely on SCCs Module 2 as belt-and-suspenders since DPF could be challenged again.

## Bridge mode — when product has minimal PII

For Micro-Product / CLI helper / dev-tool with no auth + no user accounts + no PII collected, § Privacy Posture degenerates:

```markdown
## Privacy Posture

*Compact calibration: this product collects no personal data. § Privacy Posture and § Data Handling sub-processor disclosure degenerate per the prompt's § 5 product-class calibration ladder.*

**Confirmed signals:**
- No user accounts created.
- No analytics collection (or anonymous-only, no per-user identifiers).
- No marketing email collection.
- No payment processing (or no card data — free / sponsored product).

**Posture:** privacy notice exists for transparency; no regulation matrix applies because the trigger (personal-data processing) is absent.
```

Schema-required H2 still emits; the H2's contents declare the degeneration so reviewers can see WHY the section is light.

## Anti-patterns the discipline catches

- **Consent as default legal basis** — covered; use Contract / Legitimate Interest where applicable.
- **Vague sub-processor disclosure** — covered; exhaustive named-vendor table is the requirement.
- **"We are the controller" blanket** — covered; per-flow declaration.
- **Retroactive DPIA** — covered; DPIA fires BEFORE processing.
- **72-hour breach notification "best effort"** — the SLA is binary; either the 72-hour window is met or it's a regulatory violation.
- **GDPR + CCPA conflation** — they have distinct rights frameworks. CCPA has no "legitimate interest" basis; GDPR has no "do not sell" concept. Mirror anthill-privacy-dpo anti-pattern.
- **Privacy policy without data-flow map** — covered; the data-categories table IS the map.
- **Generic retention ("as long as needed")** — covered; specific period per category with business or legal justification.
