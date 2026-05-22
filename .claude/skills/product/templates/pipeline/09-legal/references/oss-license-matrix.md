# OSS license matrix — MIT, Apache 2.0, LGPL, GPL, AGPL, BUSL, SaaS implications

How to write `## Licensing` in `legal-posture.md`. The load-bearing disciplines from anthill-ip-counsel + the calibration rules that make the licensing section smart, not rigid. AGPL network-copyleft is the single most load-bearing OSS risk in SaaS — flag it loud.

## The compatibility matrix

```markdown
| License | Copyleft | Modification Notice | Patent Grant | SaaS Implications |
|---|---|---|---|---|
| MIT | None | No | No (implicit only) | Safe for SaaS; safe to ship in proprietary product; attribution required (the license text + copyright notice) |
| BSD-2 / BSD-3 | None | No | No (implicit only) | Safe for SaaS; identical posture to MIT |
| Apache 2.0 | None | Yes (modified-file marker) | Yes (explicit, with retaliation clause) | Safe for SaaS; the explicit patent grant is the reason to PREFER Apache 2.0 over MIT for projects shipping novel algorithms |
| ISC | None | No | No | Safe for SaaS; equivalent to MIT |
| MPL 2.0 | File-level (weak copyleft) | Yes | Yes (limited) | Safe for SaaS at project level; modifications to MPL-licensed FILES must be open-sourced; new files in your project staying separate from MPL files are NOT contagious |
| LGPL v2.1 / v3 | Weak (library-level) | Yes | No (v2.1) / Yes (v3) | Safe IF used as a dynamically-linked library; modification of LGPL source triggers source-disclosure; static linking is the gray-area trap — many lawyers treat static linking as derivative work |
| GPL v2 / v3 | Strong (linking is contagious) | Yes | No (v2) / Yes (v3) | Distribution triggers copyleft — but "distribution" historically did NOT include SaaS delivery; GPL component in a SaaS stack is technically fine for the OUTPUT, but you cannot distribute the binary without releasing your source. The risk is when the company ships an on-prem version or SDK |
| AGPL v3 | Network (SaaS triggers copyleft) | Yes | Yes (explicit) | **CRITICAL** — SaaS delivery counts as "use over a network" which triggers source-disclosure of any derivative work. ANY AGPL component in a SaaS stack requires either source disclosure of your entire derivative OR a commercial license from the AGPL component's vendor |
| BUSL 1.1 (Business Source License) | Time-delayed (converts to OSS after change date — typically 4 years) | Yes | No | Source-available with delayed-open conversion; SaaS use of BUSL components REQUIRES compliance with the "Additional Use Grant" the component's vendor publishes — read the grant; not all BUSL grants permit SaaS use |
| Elastic License v2 (ELv2) | Source-available, not OSS | Yes | No | Specifically prohibits providing the software as a hosted service to third parties — direct conflict with SaaS use cases that resell the component as part of a competing service |
| SSPL (Server Side Public License) | Strong + service-source-disclosure | Yes | No | MongoDB's license; "if you offer SSPL software as a service, all source for the service must be open-sourced" — broader than AGPL's network copyleft. Avoid in SaaS stack unless using a commercial license |
| Proprietary / commercial | N/A | N/A | Per license terms | Whatever the vendor's terms say — read the agreement |
```

## The four most-common license decisions

### Your project's own license

For shipped product (SaaS app, library, SDK, CLI):

- **MIT** — most permissive, easiest adoption. Pick when the goal is broad ecosystem reuse and there's no patent concern (no novel patentable algorithms in the shipped code). Examples: most React/Vue/Angular component libraries; most utility libraries.
- **Apache 2.0** — permissive with explicit patent grant. Pick when:
  - The project ships novel algorithms (patent grant protects downstream users + contributors from patent litigation)
  - The project will accept contributions from many parties (contributors implicitly grant patents under Apache 2.0)
  - The target adopter is a large enterprise (legal teams prefer Apache 2.0 for the explicit patent grant)
  Examples: most Apache Software Foundation projects, Kubernetes, most CNCF projects, TensorFlow, Pulumi.
- **AGPL v3** — network copyleft. Pick when the goal is to FORCE SaaS competitors to open-source their derivatives. The AGPL trap is intentional. Examples: MongoDB (pre-SSPL), GhostBSD, Mastodon. Risk: lawyers at potential B2B customers will reject AGPL components in their stack, narrowing adoption.
- **Proprietary** — closed-source. Pick when the business model is selling the binary or hosted service and no value comes from external contributions. Examples: most B2B SaaS products' own code.
- **Source-Available (BUSL / Elastic License v2)** — delayed-OSS or restricted-OSS. Pick when:
  - Goal is to prevent competitors from offering the software as a service while still allowing self-hosting + internal modification
  - Long-term plan is to convert to OSS after a competitive window (BUSL's change-date conversion)
  Examples: HashiCorp Terraform (BUSL since 2023), Elasticsearch (ELv2 since 2021), CockroachDB (BUSL since 2019).

### Your project's OSS component dependencies

Audit every dependency in `package.json` / `Cargo.toml` / `requirements.txt` / `go.mod` / `pom.xml`. Tools that help: `license-checker` (npm), `cargo-license` (Cargo), `pip-licenses` (Python), `go-licenses` (Go).

For each dependency, the matrix question:

- **What's the license?** (MIT / Apache 2.0 / LGPL / GPL / AGPL / BUSL / etc)
- **What's the use?** (statically linked / dynamically linked / API consumed at runtime / dev-only tool / build-time-only)
- **What's the distribution model?** (SaaS only / SaaS + on-prem / SDK / binary)
- **What's the copyleft risk?** (None for MIT/Apache; Critical for AGPL in SaaS; review for GPL when distributing on-prem)
- **What's the action required?** (None / replace / commercial license / source disclosure)

### AGPL in SaaS — the load-bearing warning

AGPL v3 § 13 ("Remote Network Interaction") extends GPL's copyleft to network interaction. The trigger: if your SaaS product modifies an AGPL component AND makes the modified version available to remote users (which any SaaS does), you must offer the source code to those remote users.

The interpretation lawyers disagree on: does USING an AGPL component without modifying it trigger the network-copyleft? Conservative reading: yes, the entire combined work is a derivative under AGPL § 13. Liberal reading: only modifications trigger disclosure. The conservative reading is what enterprise customers' lawyers apply when reviewing your stack.

Posture for SaaS stacks:

1. **Identify AGPL components** in the dependency tree (npm: `license-checker --onlyAllow 'MIT;Apache-2.0;BSD-2-Clause;BSD-3-Clause;ISC' --excludePrivatePackages` will fail with AGPL listed)
2. **Flag each as `Critical — network copyleft triggered`** in the § Licensing § OSS component table
3. **Action required:** replace with MIT/Apache 2.0 alternative OR obtain commercial license from the AGPL vendor (most AGPL vendors offer dual licensing — MongoDB pre-SSPL did this; ImageMagick, GhostBSD do this) OR adopt AGPL for your own derivative (rare; only when AGPL is the deliberate strategy)

Example flagging:

```markdown
| Component | License | Version | Use | Distribution Model | Copyleft Risk | Action Required |
|---|---|---|---|---|---|---|
| libpdf | AGPL v3 | 2.1.0 | PDF rendering in SaaS backend | SaaS (no binary distribution) | **Critical — network copyleft triggered** | Replace with MIT alternative (`pdf-lib`, `pdfkit`) OR obtain libpdf commercial license ($X/year) before launch |
```

### GPL in SaaS — the gray-area distinction

GPL v2/v3 § 0 defines "distribution" as conveyance — historically interpreted as physical/digital binary distribution, NOT SaaS delivery. So a GPL component in a SaaS-only product does NOT trigger source disclosure of your derivative (just the GPL component itself, which you can already source from upstream).

The risk: if your product ships an on-prem version OR an SDK OR a downloadable client, distribution fires and GPL's copyleft applies. Flag GPL components in the table with a posture row:

```markdown
| Component | License | Version | Use | Distribution Model | Copyleft Risk | Action Required |
|---|---|---|---|---|---|---|
| readline-via-gnu | GPL v3 | 8.2 | CLI input handling (dev tool) | SaaS + downloadable CLI binary | **Moderate — distribution triggers copyleft for the CLI binary** | If CLI binary distributes, the CLI's GPL'd parts must be source-disclosed; rest of company code can stay proprietary IF readline is dynamically linked. Counsel review for static-linking question. |
```

### LGPL — the linking distinction

LGPL is weak copyleft at the library level. Dynamically linked LGPL libraries do NOT contaminate your application; statically linked LGPL libraries may (the FSF says yes, lawyers disagree).

Posture: for SaaS stacks, LGPL components dynamically loaded are fine; statically linked LGPL components require source-disclosure of the modified LGPL library (not your entire app). Flag for counsel review when static linking is the model.

## License-choice rationale — the mandatory paragraph

Every § Licensing § Own license declaration MUST carry a 1-paragraph rationale. Without it, the choice is decorative and the founder can't defend it to a board / customer / acquirer.

### Canonical rationale shapes

```markdown
**License-choice rationale (Apache 2.0):** v1 ships a novel ranking algorithm in the issue-triage feature (system-design § Services § TriageScorer). Apache 2.0's explicit patent grant (Section 3) protects downstream users from patent litigation by the company AND prevents contributors from later asserting patents against the project. MIT's silence on patents would leave both gaps. The slight overhead of Apache 2.0's modified-file-marker requirement is acceptable given the patent protection it provides. Counsel reviewed 2026-04-12.
```

```markdown
**License-choice rationale (Proprietary):** v1 is a closed-source B2B SaaS product; no external contributions are anticipated; the value proposition is the hosted service + the relationship with customer-end-users. Proprietary licensing keeps the source closed and the business model focused on subscription revenue. The product's own license is the standard SaaS Master Subscription Agreement (MSA); customer-end-users are bound by ToS (clickwrap at signup); enterprise customers may negotiate MSA addendums.
```

```markdown
**License-choice rationale (BUSL 1.1):** v1 ships a self-hostable analytics platform. BUSL 1.1 with a 4-year change date allows internal use + non-commercial use + research use immediately while preventing competitors from offering the platform as a managed service. After the change date (4 years), the BUSL-licensed version converts to Apache 2.0 — the OSS community gets long-term continuity even if the company sunsets the service. This is the "elasticity" model HashiCorp Terraform adopted in 2023 and CockroachDB adopted in 2019; it balances OSS-community goodwill with competitive moat.
```

### Anti-pattern: decorative license choice

```markdown
**License:** MIT.
```

No rationale. The choice is undefended; the founder can't answer "why MIT not Apache?" in a 30-minute counsel call. The MIT-with-no-rationale also signals the founder hasn't thought about patents, contributor agreements, or downstream attribution requirements.

## Bridge mode — when product has no shipped OSS or no OSS dependencies

For Micro-Product / CLI helper with single-developer authorship and no published OSS:

```markdown
## Licensing

**The product's own license:** Proprietary; v1 ships closed-source as a hosted SaaS. No SDK, no on-prem binary, no public OSS release planned for v1.

**License-choice rationale:** Solo-founder product; no contributor community to attract; the value proposition is the hosted service. Re-evaluate at v2 if public OSS release becomes a wedge.

**OSS component compatibility:** Compact calibration — full audit deferred to public-launch readiness gate. Top-level dependencies confirmed clean per `npx license-checker --excludePrivatePackages` run 2026-05-14 (output: all MIT / Apache 2.0 / ISC / BSD; no GPL / AGPL / LGPL / SSPL detected). Re-run before public launch.
```

The H2 emits; the section's contents declare the compact posture explicitly.

## License choice by product type — calibration heuristic

| Product type | Default own-license | Rationale |
|---|---|---|
| Consumer mobile app (closed-source) | Proprietary | App-store distribution; no external contribution surface; standard EULA via ToS clickwrap |
| Consumer mobile app (open-source) | GPL v3 | Network-copyleft doesn't fire on mobile distribution; viral copyleft attractive for movement-building products (mastodon-pattern) |
| B2B SaaS (closed-source) | Proprietary | Standard B2B SaaS pattern; MSA is the customer contract |
| B2B SaaS (source-available with anti-compete) | BUSL 1.1 (4-year change date) | Hashicorp / CockroachDB / Sentry pattern; protects against AWS-style commercialization |
| Developer tool / library (broad-adoption goal) | MIT or Apache 2.0 | MIT for utility libraries; Apache 2.0 for substantial framework with patent surface |
| Developer tool / SDK (with patent claims) | Apache 2.0 | Explicit patent grant protects ecosystem |
| Enterprise infrastructure with anti-compete | Elastic License v2 or SSPL | Elasticsearch / MongoDB pattern; explicit no-resale-as-service clause |
| AI model weights (with usage restrictions) | OpenRAIL-M or Apache 2.0 + usage policy | Specific to AI; OpenRAIL-M permits modification but restricts certain uses |
| AI training code (research) | Apache 2.0 or MIT | Permissive default; if patent surface, Apache 2.0 |

These are DEFAULTS — the rationale paragraph defends the choice when the default fits, or defends the deviation when it doesn't.

## Transitive-dependency posture — framework-level is necessary but NOT sufficient

The § Licensing § OSS components table in `legal-posture.md` typically lists the **framework-level** dependencies declared in system-design § Stack (Next.js, React, Prisma, Tailwind, …). That inventory is what counsel can verify by eye at the posture-document layer. But it is **not the full risk surface** — a typical Next.js + React + Prisma SaaS pulls **600-1500 transitive dependencies** through its `package-lock.json`; a Rust + Tokio service pulls hundreds via `Cargo.lock`; a Python + FastAPI service pulls 80-200 via `poetry.lock` / `requirements.txt`. A single AGPL-licensed transitive dep — pulled three layers deep by an innocuous logger or color formatter — is the dominant probabilistic risk and the framework-level table is structurally blind to it.

### The discipline

Every posture document MUST acknowledge the gap explicitly. The acknowledgement shape:

```markdown
**OSS component compatibility:** top-level dependencies per system-design § Stack; full transitive audit via `npx license-checker --excludePrivatePackages` fires before public launch (Phase 5 polish per roadmap). The framework-level table below is necessary but NOT sufficient — the actual `package-lock.json` carries ~800 transitive dependencies; the transitive audit is the load-bearing risk-surface check.
```

Then a § Open Decisions row with deciding signal = end of polish / before public launch:

```markdown
| N | Transitive-dependency license audit via `license-checker` (or `cargo-license` / `pip-licenses` / `go-licenses`) | end of polish phase / before public launch | Run `npx license-checker --excludePrivatePackages --onlyAllow 'MIT;Apache-2.0;BSD-2-Clause;BSD-3-Clause;ISC;MPL-2.0;PostgreSQL'`; fail-build CI gate added; flag any AGPL/GPL/LGPL/SSPL/Elastic-License-v2 hit as `Critical — network copyleft triggered` | [engineering] [counsel-review] |
```

### Stack-specific tool inventory

| Stack | Transitive-audit tool | One-line invocation |
|---|---|---|
| npm / pnpm / yarn (Node.js) | `license-checker` | `npx license-checker --excludePrivatePackages --onlyAllow 'MIT;Apache-2.0;BSD-2-Clause;BSD-3-Clause;ISC;MPL-2.0'` |
| Rust (Cargo) | `cargo-license` or `cargo-about` | `cargo license --json \| jq '[.[] \| .license] \| unique'` |
| Python (pip / poetry / pdm / uv) | `pip-licenses` or `licensecheck` | `pip-licenses --format=json --with-license-file` |
| Go modules | `go-licenses` | `go-licenses report ./...` |
| Ruby (Bundler) | `license_finder` | `license_finder --format json` |
| Maven (Java) | `license-maven-plugin` | `mvn license:add-third-party` |

The tool-run report is what counsel + engineering jointly review at the Phase 5 polish gate. CI integration (fail-build on disallowed license) prevents regression.

### Anti-pattern: declared framework-level inventory treated as the full audit

```markdown
| Component | License | Version | Use | Distribution Model | Copyleft Risk | Action Required |
|---|---|---|---|---|---|---|
| Next.js | MIT | 15.x | Frontend | SaaS | None | None |
| React | MIT | 19.x | UI | SaaS | None | None |
| Prisma | Apache 2.0 | 6.x | ORM | SaaS | None | None |
```

No transitive-audit acknowledgement. The table looks clean but is structurally blind to the 800 transitive deps pulled in by these three roots. Counsel reading this document at the briefing call sees the framework-level cleanliness AND the deferred transitive audit as a known-and-managed gap, not a missing-audit blind spot.

## Patent strategy — software-only v1 stacks

For software-only products at the pre-revenue stage, the **default posture is no patent filings**. The reasons compound:

1. **Alice/Mayo § 101 prosecution risk.** US Supreme Court decisions *Alice Corp. v. CLS Bank International* (2014) and *Mayo Collaborative Services v. Prometheus Laboratories* (2012) established that abstract ideas — including algorithms implemented in software — are not patent-eligible unless they recite "significantly more" than the abstract idea itself. Software algorithmic surfaces (keyboard routers, import-pipeline orchestrators, free-tier-cap enforcement, recommendation rankers) face § 101 rejection at high rates (~50-70% for software-only applications post-Alice; varies by USPTO art unit). The cited rejection grounds: "the claims are directed to an abstract idea (data manipulation, automating a manual process, optimization) and do not amount to significantly more."

2. **Prosecution cost is not justified at pre-revenue.** USPTO prosecution costs $10k-$50k per application (attorney fees + filing fees + office-action responses). For a pre-revenue startup, the same capital is better deployed on customer acquisition, runway, or hiring.

3. **Defensive value is low for SMB / SaaS.** Patents matter for: (a) defensive cross-licensing posture (large enterprises with patent portfolios); (b) NPE / patent-troll litigation defense (general liability + E&O insurance is cheaper); (c) Series B+ fundraising signaling (Seed/A investors do not weight patents heavily). None of these apply at pre-revenue scale.

4. **Trade-secret protection is the better posture.** Algorithmic differentiation that is NOT observable from the user-facing behavior (a proprietary ranking model, a trained-on-customer-data ML model, a non-obvious data-pipeline optimization) is better protected as a trade secret — NDAs + access controls + no public disclosure. Patent disclosure forfeits trade-secret protection in exchange for a 20-year monopoly that the § 101 prosecution risk may not deliver.

### When to revisit

The patent-posture line in § Licensing should declare the revisit signal:

> **Patent strategy posture:** no patent filings at v1 due to Alice/Mayo § 101 prosecution risk; revisit at $5M ARR OR when a genuinely-novel non-obvious method emerges (e.g. hardware/software co-design, biotech adjacency, true algorithmic invention with prior-art search supporting non-obviousness). Re-evaluation triggers a § Open Decisions row; until then, NO software-only patent filings.

### When patents DO matter at v1

- **Hardware products** (medical devices, IoT, semiconductor) — § 101 doesn't reject hardware claims the same way; patents are load-bearing for hardware moats.
- **Biotech / pharma** — patent-eligible subject matter is the entire competitive moat.
- **True novel methods with strong prior-art support** — once-in-a-decade situations; counsel sizes the patentability + freedom-to-operate (FTO) gap before any filing.
- **Acqui-hire defense** — an acquirer may value a defensive patent portfolio; this is the post-Series-A consideration, not v1.

For these cases, the patent posture is NOT the default-skip line — it is a § Open Decisions row with `[counsel-review] [founder]` concern tags and a deciding signal naming the specific filing window.

### Anti-pattern: patent silence

The posture document that omits any mention of patents is the regression mode. Counsel reading the document doesn't know whether the founder considered patents and rejected them (deliberate posture) or never considered them (uninformed). The explicit declaration — even when the declaration is "no filings, here's why" — is the discipline.

## Anti-patterns the discipline catches

- **AGPL component in SaaS stack without flagging** — the load-bearing risk; surface every AGPL dependency as `Critical — network copyleft triggered`.
- **GPL / AGPL / OSS license treated as interchangeable** — MIT ≠ GPL; each has distinct obligations.
- **License chosen without rationale paragraph** — the choice is decorative; counsel can't defend it.
- **Missing OSS audit in stacks of 50+ dependencies** — the dependency tree of a modern Node.js / Rust / Python project has hundreds of transitive deps; a tool-run audit is mandatory before public launch.
- **Framework-level OSS inventory treated as complete audit** — the system-design § Stack table is the framework-level surface; the actual risk surface is the full transitive tree. Acknowledge the gap explicitly; queue the transitive audit as a § Open Decisions row with deciding signal = before public launch.
- **Patent posture silence** — the document that never mentions patents leaves counsel unable to distinguish "founder considered and rejected" from "founder never considered". Declare the posture explicitly even when the posture is no-filings.
- **Static-linking gray area for LGPL ignored** — flag for counsel review when static linking is the model.
- **Self-asserting "GPL is fine in SaaS"** — GPL distribution is gray-area when on-prem / SDK / downloadable client is in scope; flag for counsel review.
- **Proprietary product licensing OSS components under proprietary** — re-licensing OSS-licensed components under proprietary is a license violation. You can ship them under their original license inside your proprietary product, but you cannot relicense.
- **No attribution / NOTICE / LICENSE file in distributions** — MIT / BSD / Apache 2.0 all require attribution; Apache 2.0 specifically requires NOTICE file aggregation. Tooling: `oss-attribution-generator` (npm), `cargo-about` (Rust).
- **Source-available product self-labeled as "open source"** — BUSL / Elastic License v2 / SSPL are NOT OSS per OSI definition. Mislabeling damages community trust + invites legal challenges.
