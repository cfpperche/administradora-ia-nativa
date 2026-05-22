# Regulated aspects checklist — HIPAA, COPPA, PCI, SOC 2, GLBA, FERPA, AI Act, sector-specific triggers

How to write `## Regulated Aspects` in `legal-posture.md`. Each regulated regime has a *trigger* (the condition that fires applicability), a *posture-decision* shape (the v1 stance), and a *counsel-review checkpoint* (the specific event before which outside counsel must sign off).

This is a *trigger-driven* checklist, NOT a "list every regulation that exists" inventory. Posture rows fire ONLY when the trigger applies. Silent omission of an inapplicable regime is correct; emitting `*N/A*` placeholder rows for every conceivable regime is the noise mode the discipline catches.

## The triggers + postures

### HIPAA — health data

**Trigger:** the product processes Protected Health Information (PHI) as defined in 45 CFR 160.103 — individually-identifiable health information that is created, received, maintained, or transmitted by a covered entity or its business associate.

**Trigger applies when ANY of these are true:**
- Product collects health data from individuals (fitness tracking, symptom logging, medication tracking)
- Product receives health data from a covered entity customer (e.g., a clinic using your SaaS to track patient records)
- Product processes health data on behalf of a customer (B2B SaaS where the customer is the covered entity)

**Posture decisions (per applicable row):**
- **Covered Entity (CE) vs Business Associate (BA) vs neither.** Most B2B SaaS that touches health data is BA; the customer is the CE. Direct-to-consumer health apps (without clinical involvement) often are NEITHER — HIPAA applies to clinical settings + covered entities, not to all health data.
- **BAA template.** Required if BA status. Counsel signs off on the BAA template; customers sign at contract execution.
- **Encryption posture.** HIPAA Security Rule § 164.312 requires encryption "to the extent reasonable and appropriate"; the practical interpretation is FIPS 140-2 compliant encryption at rest + TLS 1.3 in transit. AES-256 at rest is the baseline.
- **Breach notification SLA.** HIPAA Breach Notification Rule § 164.404 — notify affected individuals within 60 days; HHS within 60 days; media if breach affects 500+ in a state.
- **Training mandate.** HIPAA requires workforce training; engineers handling PHI must complete annual HIPAA training. The training program is documented in `security.md`; the posture row commits to it.

**Counsel-review checkpoint:** outside counsel signs off on the BAA template + BA-status determination via 1-line email confirmation BEFORE the first health-data-flowing feature ships.

**Anti-pattern:** "we have a HIPAA-compliant cloud provider" — the cloud provider is one piece of the puzzle; the company is independently responsible for HIPAA's administrative + technical + physical safeguards.

---

### COPPA — children under 13

**Trigger:** the product is directed at children under 13, OR the product has actual knowledge that it collects personal information from children under 13.

**Trigger applies when ANY of these are true:**
- Audience is explicitly children (educational apps, kids' games, family-oriented services)
- Audience is "general audience" but the product knows or should know that a meaningful number of users are under 13 (consumer apps with no age gate often trigger here — under-13 users are reasonably foreseeable in most consumer apps)
- Product collects from any user under 13 even occasionally

**Posture decisions:**
- **Age-gate before account creation.** Default v1 posture: ask date-of-birth at signup; refuse account creation for under-13 unless the parental-consent flow is built. Anti-pattern: under-13-friendly UX without the gate (creates COPPA liability silently).
- **Verifiable Parental Consent (VPC) flow.** Required to collect any personal info from under-13. VPC methods: signed paper consent (oldest, most rigorous); credit-card transaction ($0.01 verification); video call with parent; government-ID verification. FTC publishes the approved methods list at 16 CFR § 312.5(b).
- **No behavioral advertising to under-13.** COPPA Rule § 312.4 prohibits using under-13 data for behavioral advertising; first-party contextual ads only.
- **Safe-harbor program opt-in.** FTC-approved safe-harbor programs (TRUSTe, iKeepSafe, ESRB, PRIVO, kidSAFE) provide regulatory safe harbor and a clearer compliance path. Posture: opt-in to one of the FTC-approved programs BEFORE public launch when COPPA fires.

**Counsel-review checkpoint:** outside counsel signs off on age-gate UX + parental-consent flow + privacy notice for parents BEFORE public launch when COPPA fires.

**Anti-pattern:** "we just won't market to kids" — actual knowledge is the trigger, not marketing intent. If the product is fun + free + has minimal barriers to entry, under-13 users will arrive regardless.

---

### PCI DSS — payment-card data

**Trigger:** the product accepts, processes, stores, or transmits cardholder data (full Primary Account Number — PAN — and/or related authentication data).

**Trigger applies when:**
- Product accepts credit-card payments directly (the card data flows through your servers, even briefly)
- Product stores cardholder data (rare; almost never the right architecture)
- Product transmits cardholder data to a third party (gateway, processor)

**Trigger does NOT apply when:**
- Stripe Checkout redirects the user to Stripe's hosted page (the card data never touches your servers); your scope is SAQ-A only
- Stripe Elements (tokenized iframe) where Stripe's iframe handles the input and your code never sees the PAN; your scope is SAQ-A or SAQ-A-EP

**Posture decisions:**
- **SAQ-A (minimal scope)** — Stripe Checkout / hosted redirect model. Your role: validate Stripe's compliance + maintain a written information security policy + complete the SAQ-A annual self-assessment. This is the default v1 posture for SaaS.
- **SAQ-A-EP (moderate scope)** — Stripe Elements / tokenized iframe model. Your role: SAQ-A's scope PLUS validate the iframe-loading page is served over HTTPS with restricted security headers.
- **SAQ-D (full scope)** — direct card-data handling. AVOID for v1. Requires quarterly ASV scans + annual penetration tests + full PCI DSS Self-Assessment Questionnaire D. Cost: $50k-200k annually + engineering overhead.

**Counsel-review checkpoint:** outside counsel + payments-team confirm SAQ-A scope claim is accurate via review of the Stripe integration architecture BEFORE first paid customer.

**Anti-pattern:** "Stripe handles PCI for us" — Stripe handles PCI for Stripe; the customer (your company) is still responsible for the SAQ-A self-assessment + maintaining the integration in a way that preserves SAQ-A scope.

---

### SOC 2 — service organization controls

**Trigger:** enterprise customers require SOC 2 Type II as a procurement gate. NOT a regulation per se — a customer-driven compliance frame. Usually a Series A milestone, not a v1 requirement.

**Trigger applies when:**
- Sales pipeline includes Fortune 1000 or regulated-vertical customers (banking, healthcare, government) that mandate SOC 2 in vendor risk assessment
- Enterprise prospects ask for the SOC 2 report during procurement
- Investors require SOC 2 readiness as part of Series A / B diligence

**Posture decisions:**
- **Type I readiness in v1.** Controls documented; observation window starts. Cost: $10k-30k for the auditor + 1-3 months of engineering effort to document controls.
- **Type II at scale.** 6-month observation window of operating effectiveness. Audit fires after 6 months of evidence collected. Cost: $30k-80k for the auditor.
- **Vanta / Drata / Secureframe mediation.** SaaS tools that automate evidence collection; mandatory for any company below ~$10M ARR; reduces cost + engineering overhead 50-70%.
- **Trust Services Criteria scope.** Pick from: Security (mandatory baseline); Availability; Processing Integrity; Confidentiality; Privacy. For most B2B SaaS, Security + Availability + Confidentiality is the v1 scope; Privacy adds CCPA / GDPR overlay.

**Counsel-review checkpoint:** Counsel reviews the SOC 2 readiness assessment + scope decision BEFORE Vanta/Drata onboarding begins. Re-review at each annual audit.

**Anti-pattern:** "we'll get SOC 2 when we need it" — the 6-month observation window means SOC 2 Type II takes 9-12 months from start to audit-report-in-hand. Starting AFTER the first enterprise customer requests it costs the deal.

---

### GLBA — financial-services consumer data

**Trigger:** the product is a "financial institution" under the Gramm-Leach-Bliley Act — a broad definition that includes lenders, financial advisors, fintech apps, mortgage brokers, debt collectors, and some retail products with consumer financing.

**Trigger applies when:**
- Product offers financial products (loans, advances, credit, payment plans)
- Product processes consumer financial data on behalf of a regulated entity (B2B fintech serving banks)
- Product handles tax preparation, financial advice, investment management

**Posture decisions:**
- **Privacy notice (initial + annual).** GLBA Privacy Rule requires a notice at relationship-start + annually if information-sharing practices change. Plain language; not the GDPR-style detailed legal-basis disclosure.
- **Safeguards Rule** (16 CFR § 314). Comprehensive information security program; designated Qualified Individual; risk assessment; multi-factor authentication; encryption; vendor oversight; incident response plan. The 2023 amendments made these requirements explicit.
- **Pretexting + identity protection.** GLBA + state laws (e.g., NY DFS Cybersecurity Regulation) require identity verification before account access.

**Counsel-review checkpoint:** Outside counsel + fintech-specialist counsel sign off on GLBA Safeguards Rule program BEFORE the first paid financial-product feature ships.

**Anti-pattern:** "we're not a bank so GLBA doesn't apply" — the definition is broad; many "tech companies" qualify as financial institutions if they touch consumer-financial-product surfaces.

---

### FERPA — student education records

**Trigger:** the product is an "educational agency or institution" that receives federal Department of Education funding, OR the product processes education records on behalf of such an institution (B2B EdTech).

**Trigger applies when:**
- Product is sold to schools, school districts, universities, or other federally-funded institutions
- Product processes student records (grades, attendance, disciplinary records, IEP/504 plans, identifiers)

**Posture decisions:**
- **Directory vs sensitive record split.** Directory information (name, address, phone, email, attendance) MAY be disclosed without parental consent if the institution publishes a directory-info policy. Sensitive records (grades, disciplinary, health) require parental consent (or student consent if 18+).
- **School-official designation.** If the product processes records on behalf of the school, the contract must designate the product as a "school official" with legitimate educational interest; this is the FERPA equivalent of a DPA.
- **Parental access rights.** Parents (or 18+ students) have right to inspect + review education records within 45 days of request. The mechanism must exist in v1 if FERPA fires.
- **PPRA + COPPA overlap.** Pupil Protection Rights Amendment (PPRA) overlaps with FERPA for surveys; COPPA fires when EdTech products serve under-13 students.

**Counsel-review checkpoint:** EdTech-specialist counsel signs off on FERPA school-official contract template + parental-access mechanism BEFORE first K-12 customer signs.

**Anti-pattern:** "FERPA applies to schools, not vendors" — FERPA's scope extends to vendors via the school-official designation; vendor non-compliance triggers the school's penalties.

---

### AI Act (EU) — AI systems and General-Purpose AI

**Trigger:** the product reaches EU users AND contains an AI system as defined in EU Regulation 2024/1689 (AI Act).

**Trigger applies when:**
- Product has EU users (any consumer with EU residence; any B2B customer with EU operations)
- Product includes an AI system — broadly defined to include LLM-based features, ML-driven classification, automated decision-making, biometric identification, recommendation systems

**Applicability dates:**
- **2 February 2025:** prohibited practices (social scoring; emotion recognition in workplace / education; biometric categorization based on sensitive attributes; predictive policing)
- **2 August 2025:** general-purpose AI model obligations (transparency, training-data summary)
- **2 August 2026:** general AI Act applicability — high-risk AI systems must complete conformity assessment; transparency obligations for limited-risk AI
- **2 August 2027:** high-risk AI in Annex III (employment, education, law enforcement, biometric ID) — full applicability

**Posture decisions:**
- **Risk-tier classification.** Most B2B SaaS LLM features are **limited-risk** under Art 52 — transparency obligations only (user disclosure that AI is generating output). Biometric / employment scoring / education scoring / law-enforcement use cases jump to **high-risk** (Annex III) with full conformity assessment. Prohibited practices (Art 5) cannot ship at all in EU.
- **Transparency obligations (Art 52).** Users must be informed they are interacting with AI (e.g., chatbots labeled as AI); AI-generated synthetic content must be marked as artificially generated; emotion-recognition + biometric-categorization systems must inform individuals.
- **High-risk system obligations (Art 6 + Annex III).** Conformity assessment + technical documentation + risk management + transparency + human oversight + accuracy/robustness/cybersecurity + post-market monitoring. NOT a 1-week task.
- **General-Purpose AI (GPAI) provider obligations (Art 53-55).** If your product is or contains a GPAI model (foundation model that can be adapted to many downstream tasks), separate obligations apply: technical documentation, training-data summary, copyright compliance posture.

**Counsel-review checkpoint:** EU-specialized counsel signs off on AI Act risk-tier classification + transparency UX BEFORE first EU customer reaches public launch.

**Anti-pattern:** "we'll deal with AI Act later" — high-risk classification requires conformity assessment which can take 3-9 months; starting late blocks EU launch.

---

### State employment privacy laws — employee data

**Trigger:** product processes employee personal data (HR-tech, time-tracking, monitoring tools, employee surveys).

**Posture decisions:**
- **Illinois BIPA** (Biometric Information Privacy Act). If the product collects biometric identifiers (fingerprints, facial recognition, voice prints) from Illinois residents, BIPA requires written consent + retention/destruction schedule + $1k-5k per-violation statutory damages. Class-action liability is the load-bearing risk.
- **California CCPA for employees** (since Jan 2023). California-resident employees have CCPA rights (access, deletion, correction) for employment-related data.
- **NY 2023 employment regulations.** Disclosure of monitoring (email, internet, phone) is mandatory at hire + annually. Includes B2B HR-tech serving NY employers.
- **EU GDPR for employees.** GDPR Art 88 + member-state employment law overlays. Works councils may have consultation rights for monitoring tools.

**Counsel-review checkpoint:** employment-law counsel signs off on monitoring posture + BIPA compliance BEFORE first Illinois OR EU employee data feature ships.

---

### Trade-secret protection

**Trigger:** the product or company has proprietary algorithms, customer lists, pricing models, source code, or other confidential commercial information that derives independent economic value from secrecy.

**Posture decisions:**
- **NDAs with contractors signed BEFORE access.** Retroactive NDAs are unenforceable in many jurisdictions; signing-before-access is the rule.
- **Access controls + audit logs.** Trade-secret status requires "reasonable measures" to maintain secrecy (Defend Trade Secrets Act § 1839(3)(A)).
- **Confidentiality marking.** Documents containing trade secrets marked `CONFIDENTIAL — TRADE SECRET`; not legally mandatory but evidentially helpful.
- **No-public-disclosure rule.** Conference talks, blog posts, open-source release, public demos destroy trade-secret status for the disclosed portions. Pre-disclose-to-counsel rule prevents accidental loss.

**Counsel-review checkpoint:** IP-counsel reviews trade-secret protection program annually + ad-hoc when significant public-disclosure events are planned (talks, papers, blog posts).

---

### IP Assignment — Founder IPAA + Contractor / Employee PIIA

**Trigger:** the company exists and has founders OR engages contractors / employees who write code, designs, or other copyrightable material. Universal at v1 — every product company has this trigger.

**Why this is its own row (not folded into Trade-secret):** trade-secret protection covers the *information*; IP assignment covers *ownership chain of title*. They are orthogonal — a company can have rigorous trade-secret discipline (NDAs, access controls, marking) AND a broken IP chain (unassigned founder code, contractor-owned designs). Investors diligence the IP chain at Series A; unassigned-contractor or unassigned-founder exposure is a deal-killer. Surfacing IP-assignment as its own row — and as explicit § Open Decisions rows in `legal-posture.md` § Open Decisions — is the discipline.

**The two artifacts:**

1. **Founder IP Assignment Agreement (Founder IPAA).** Executed at entity formation, assigning all founder work-product (pre-incorporation code, designs, brand assets, domain names, founder-developed algorithms) to the company. Without this, the founder's pre-incorporation code is owned by the founder personally; on a Series A funding event, the diligence process surfaces the gap and demands retroactive assignment — which the founder may then leverage for an unfavorable equity adjustment.

   **Deciding signal:** at entity formation, before any Company code is committed to the company's repositories. The Founder IPAA is a corporate-counsel deliverable; flagged in `legal-posture.md § Open Decisions` with `[founder] [counsel-review]`.

2. **PIIA (Proprietary Information and Inventions Assignment Agreement) for contractors and employees.** Executed BEFORE first commit / first day for any contractor or employee. The PIIA: (a) assigns all work-product produced during the engagement to the company; (b) includes a perpetual royalty-free license back to the contractor for pre-existing materials they bring; (c) covers post-engagement confidentiality + non-solicitation as the local jurisdiction permits; (d) names the inventions-disclosure obligation. Retroactive PIIA is unenforceable in many jurisdictions (California Labor Code § 2870 + similar state statutes); signing-before-engagement is the rule.

   **Deciding signal:** before the first contractor's / first employee's first commit. The roadmap's part-time designer (~10 hr/wk weeks 2-14) OR the first-engineer-hire is the standard trigger. Flagged in `legal-posture.md § Open Decisions` with `[founder] [counsel-review]`.

**Posture commitment shape (in `legal-posture.md` § Licensing):**

```markdown
**IP Assignment posture:**

- **Founder IPAA:** scheduled at entity formation (Delaware Certificate of Incorporation filed → counsel supplies template → founder executes → file in cap-table records). Currently pending — entity formation has not yet completed. Tracked in § Open Decisions row N.
- **Contractor PIIA:** template prepared; first execution trigger is the part-time designer engagement at roadmap week 2. Tracked in § Open Decisions row N+1.
- **Employee PIIA:** template prepared (same shape as contractor PIIA + employment-specific clauses); first execution trigger is the first-engineer-hire post-Series-A.
```

**Counsel-review checkpoint:** outside corporate counsel signs off on the IPAA + PIIA templates BEFORE first execution. Series A IP-chain-of-title diligence re-validates.

**Anti-pattern:** burying IP-assignment under § Regulated Aspects § Trade-secret as a sub-paragraph. Trade-secret protection and IP-assignment are orthogonal disciplines; collapsing them lets investors / acquirers / Series A diligence catch the gap that the founder thought was covered.

---

### Trademark posture — brand-name protection

**Trigger:** the product has a brand name worth protecting (most consumer-facing products + most B2B with a distinctive product name).

**Posture decisions:**
- **Clearance search BEFORE public launch.** USPTO TESS + EUIPO eSearch + state secretary-of-state filings + common-law search (Google, App Store, GitHub). Paid clearance services (Compumark, Corsearch) for higher-stakes brands.
- **Strength analysis.** Generic (no protection) → Descriptive (weak, requires secondary meaning) → Suggestive (moderate, registrable) → Arbitrary (strong) → Fanciful (strongest, e.g., "Kodak", "Exxon"). Pick fanciful when possible.
- **Filing strategy.** USPTO for US (Intent-to-Use vs Use-in-Commerce); EUIPO Madrid System for EU + international. Filing cost: $250-1000 USPTO + $1500-3000 EU.
- **Use-in-Commerce maintenance.** US trademarks require continued use; affidavits required at 5-6 years + 9-10 years + every 10 years.

**Counsel-review checkpoint:** trademark-specialist counsel runs clearance search + recommends filing strategy BEFORE public launch with the v1 brand name.

**Anti-pattern:** launching without clearance + later receiving a cease-and-desist forcing a costly rebrand.

---

## Trigger-driven omission discipline

A posture document for a B2B SaaS dev tool with no health data, no minor users, no education records, no biometrics, no financial products would emit:

- § Regulated Aspects § SOC 2 (because enterprise customers will require it eventually)
- § Regulated Aspects § AI Act (only if AI is in the stack AND EU users are reachable)
- § Regulated Aspects § Trade Secret (because proprietary algorithms exist)
- § Regulated Aspects § Trademark (because the product has a brand name)
- § Regulated Aspects § Sub-processor disclosure (covered in § Data Handling; cross-reference)

The document would NOT emit HIPAA / COPPA / GLBA / FERPA / BIPA rows — silent omission is correct because the triggers don't fire. Emitting `*N/A*` rows for every conceivable regime is the noise mode the discipline catches.

## Counsel-review checkpoint discipline

Every applicable row carries a counsel-review checkpoint with TWO elements:

1. **WHO** signs off — outside counsel, EdTech-specialist counsel, employment-law counsel, IP-counsel, etc.
2. **WHEN** — a specific event (first customer of class X, first feature of class Y, public launch, annual review).

Anti-pattern: "Counsel will review eventually" — no who, no when. The discipline catches this — every checkpoint names a specific triggering event.

## Concern-tag discipline

Per the prompt's § 6, rows in § Regulated Aspects MAY carry `[counsel-review]` concern tag in addition to the standard step-11 allow-list. Examples:

```markdown
- **HIPAA — health data.** Posture: Business Associate (BA) status for v1; BAA template required. Encryption FIPS 140-2 compliant. 60-day breach notification SLA. Counsel-review checkpoint: outside counsel signs off on BAA template via 1-line email before first health-data feature ships. [counsel-review] [engineering] [founder]
```

The `[counsel-review]` tag signals the row CANNOT be self-closed by the founder — outside counsel sign-off is structurally required. `[engineering]` signals the technical implementation; `[founder]` signals the business-decision component.

## Anti-patterns the checklist catches

- **Inventory-of-all-regulations** — emit only triggered rows, silent omission for inapplicable.
- **"X may apply" hedging** — fire or don't fire; if uncertain, name the counsel-review trigger that resolves the uncertainty.
- **Procrastinated SOC 2** — 9-12 month timeline; start before the first enterprise customer asks.
- **Retroactive HIPAA / DPIA / BAA** — the SLA is "before processing begins"; retroactive compliance is theater.
- **"We're not a bank" GLBA dismissal** — GLBA definition is broad; many tech companies trigger.
- **"AI Act doesn't apply yet" deferral** — high-risk conformity assessment is 3-9 months; cannot wait until applicability date.
- **Trademark filing AFTER launch** — clearance + filing BEFORE launch is the cheap path; rebrand-after-cease-and-desist is the expensive path.
- **Trade-secret status assumed for public-disclosed material** — public disclosure destroys; flag pre-disclosure events to counsel.
