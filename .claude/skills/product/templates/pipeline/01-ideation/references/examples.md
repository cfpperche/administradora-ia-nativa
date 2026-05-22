# Ideation — Good vs Bad Examples

Reference these examples when generating concepts and opportunity map entries. The goal is specificity, honesty, and grounded signal — not impressive-sounding filler.

Ported verbatim from anthill `anthill-product-ideator/references/examples.md`.

---

## Concept Entry

### Good

```
**InvoiceAI**
Tagline: "Close your books in 15 minutes — AI that reads, matches, and flags invoices your accountant would miss."
Scale: SMB SaaS
Model: Subscription ($49/mo per seat)
Hook: Connect your inbox + accounting tool in 3 clicks. First invoice matched in under 60 seconds.
Retain: Every invoice processed trains a company-specific matching model. Accuracy compounds month-over-month. Switching means retraining from zero.
Refer: Accountants share it with 3-5 clients on average. Referral built into the "invite your bookkeeper" onboarding step.
Mechanics: Data flywheel (matching model improves per account), workflow automation, expert-in-the-loop (flags for human review above threshold)
Risk: QuickBooks and Xero have invoice matching on their roadmap. If they ship it natively, the standalone case weakens. Differentiation needs to be speed + accuracy, not just feature parity.
JTBD: When I receive supplier invoices, I want to reconcile them against POs without touching each one, so I can close the month without a 3-hour manual review.
```

**Why this is good:** The tagline is concrete (15 minutes, specific action). The hook describes a real activation moment. The retain explains the switching cost mechanically — "retraining from zero" is not vague. The risk is honest and names the specific threat. JTBD is a complete sentence tied to a real workflow, not a platitude.

---

### Bad

```
**SmartInvoice Pro**
Tagline: "AI-powered invoice management for modern businesses."
Scale: Enterprise
Model: TBD
Hook: Streamlines your invoicing workflow.
Retain: Saves time and reduces errors.
Refer: Users will naturally recommend it.
Mechanics: AI, automation
Risk: Competitive market.
JTBD: Help businesses manage invoices better.
```

**Why this is bad:** The tagline is a Mad Libs template ("AI-powered X for modern Y"). The hook describes an outcome, not an action the user takes. Retain names a benefit ("saves time") without explaining why switching is painful. Refer is wishful thinking with no mechanism. Mechanics are not from the catalog — "AI" is not a mechanic. Risk is a non-answer. JTBD is a company goal, not a user job statement.

---

## Opportunity Map Entry

### Good

```
### Pain Point: Invoice reconciliation is manual and error-prone for sub-50-person companies

**Signal strength:** High
**Evidence:**
- "I spend 3-4 hours every month-end matching invoices to POs. Half the errors come from suppliers who reformat their PDFs." — r/Accounting, 847 upvotes [3]
- QuickBooks Community forum thread "invoice matching" has 2,300+ replies dating to 2019, no native resolution [4]
- G2 reviews for Bill.com (4.1, 1,200+ reviews): top complaint category is "manual matching steps" (38% of 1-star reviews) [5]

**Frequency:** Monthly trigger (month-end close), affects accounts payable roles at all company sizes
**Persona:** Bookkeeper or controller at 10-50 person company, using QuickBooks or Xero, no dedicated AP team
**White space:** Existing tools automate large-enterprise EDI workflows. Sub-50 companies are underserved — too small for SAP Concur, too complex for spreadsheets.
```

**Why this is good:** Three independent citations from different source types (community forum, product forum, review data). Frequency is precise (monthly, specific trigger event). Persona is actionable — names the role, tool stack, and team size. White space is a falsifiable claim: large-enterprise tools exist, sub-50 is underserved.

---

### Bad

```
### Pain Point: Businesses struggle with invoicing

**Signal strength:** High
**Evidence:**
- Many companies report invoicing is a challenge
- Industry analysts note this is a growing problem
- Customers want better invoice tools

**Frequency:** Regular
**Persona:** Business users
**White space:** Opportunity exists in this space.
```

**Why this is bad:** No citations — "many companies report" is fabricated confidence. "Industry analysts note" requires a source or it is noise. Frequency ("regular") is meaningless without a trigger. Persona ("business users") describes no one specifically. White space is a tautology. An opportunity map entry without real quotes and real citations should be discarded, not polished.

---

## Mechanics Breakdown — Core Value statement

The Core Value section is where the brief states *what the product fundamentally IS* — the structural opinion that engineering can build a state machine around. Weak Core Value statements list features; strong ones name a primitive.

### Good — "primitive as first-class workflow state"

```
**Layer 1 — Core Value:** Triage as a first-class workflow state, not a filter on the backlog.

Existing tools treat triage as something you do TO a backlog (filter the queue, batch-update, archive noise). The product treats triage as its own state: every new issue lands in a dedicated keyboard-navigable queue, and the team's job is to drain that queue to zero each morning. Three keystrokes per issue (T to open, P to set priority, A to assign) clear noise in 60 seconds.

The state machine is opinionated:
  New → Triaged → Backlog → Cycle → Done
                                    ↘ Cancelled
                                    ↘ Snoozed
No custom statuses on the free tier — the discipline is part of the product.
```

**Why this is good:** It names a structural primitive (Triage = its own state) that engineering can encode as a database enum + screen + state-transition diagram on day one. The contrast vs. existing tools is concrete (filter vs. state). The Hook (3-keystroke drain) flows naturally from the primitive. Engineering reads this and knows what to build.

### Bad — feature list

```
**Layer 1 — Core Value:** Fast keyboard-driven workflow with command palette, smart filters, AI-suggested priorities, GitHub integration, and analytics dashboards.
```

**Why this is bad:** Feature list, not a primitive. "Fast keyboard-driven workflow" is a quality, not a state-machine opinion. Engineering reading this doesn't know what to BUILD — they just know what to make fast. Anti-pattern Pattern 2 (Feature List Without Value Loop). Fix: pick the *one* primitive the workflow centers on, and let other features serve it.

The rule of thumb: if you remove a feature from the list, does the product still work? If yes, that feature isn't core. The Core Value section names what cannot be removed.
