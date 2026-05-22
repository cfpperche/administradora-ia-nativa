# Product Growth Mechanics Catalog

Proven growth and retention mechanics for software products. Each includes: what it is, why it works psychologically, real-world proof with data, and application notes for new products.

Use these as building blocks when generating concepts. Layer 2-3 per concept.

Ported from anthill `anthill-product-ideator/references/mechanics-catalog.md`. Content travels verbatim — these are domain mechanics, not anthill-specific.

---

## ACQUISITION MECHANICS (how users discover and sign up)

### 1. Product-Led Growth (PLG)
**What:** The product itself drives acquisition — free tier or freemium lets users experience value before paying.
**Psychology:** Try-before-buy reduces risk, reciprocity ("they gave me this for free"), and switching cost after investment.
**Proof:**
- **Slack**: 80%+ of paid conversions start from free teams. Users invite colleagues → organic growth.
- **Notion**: Free for personal, viral templates shared publicly. 30M+ users.
- **Figma**: Free tier → teams adopt → company pays. $20B acquisition by Adobe (cancelled, but validates model).
**Application:** Default model for any product targeting SMB or prosumers. Free tier must deliver real value, not a crippled demo.

### 2. Marketplace / Network Effects
**What:** Value increases as more users join — both sides of a marketplace, or collaborators in a network.
**Psychology:** "Everyone's there" FOMO + increasing returns + high switching cost.
**Proof:**
- **Shopify App Store**: Developers build apps → merchants find them → more merchants attract more devs.
- **Stripe**: More devs integrate → more payment volume → better fraud detection → more devs.
- **Mercado Livre**: More sellers → more buyers → more sellers. R$ 183B GMV.
**Application:** If your product connects two sides (supply/demand, creator/consumer, service/client), design for network effects from day one.

### 3. Viral Loops / Referral Mechanics
**What:** Built-in mechanisms that make users invite others as a natural part of using the product.
**Psychology:** Social proof + incentive alignment + "I look good sharing this."
**Proof:**
- **Dropbox**: "Invite friend, get 500MB free" — 3,900% growth in 15 months. 35% of signups from referral.
- **Robinhood waitlist**: Referral = move up the queue. 1M+ users before launch.
- **Calendly**: Every meeting invite exposes the brand. 10M+ users from organic embedding.
**Sub-mechanics:**
- **Inherent virality**: Using the product exposes others (Calendly, DocuSign, Loom)
- **Incentivized referral**: Both parties get reward (Dropbox, Uber)
- **Social sharing artifact**: Product generates something shareable (Spotify Wrapped, GitHub Skyline)
- **Waitlist queue jump**: Refer to move up (Robinhood)

### 4. Content-Led Growth
**What:** Content (blog, YouTube, templates, tools) drives organic traffic → conversion to product.
**Psychology:** Reciprocity ("they taught me for free") + authority + SEO compounding.
**Proof:**
- **HubSpot**: Blog → free tools → CRM. 6M monthly blog visitors. Content = #1 acquisition channel.
- **Ahrefs**: SEO tool that ranks #1 for SEO queries. $100M+ ARR, 65% from organic.
- **Notion templates**: User-created templates shared publicly → discovery → signup.
**Application:** Works best when your audience actively searches for solutions. Long payback but compounds.

### 5. Community-Led Growth
**What:** Build a community around the domain (not the product) → community members become users.
**Psychology:** Belonging + identity + peer learning + trust.
**Proof:**
- **dbt (data build tool)**: Community of 50K+ data engineers drove adoption before marketing existed.
- **Figma**: Built designer community → Config conference → 30M users.
- **Indie Hackers**: Community → product discovery → Stripe acquisition.
**Application:** Start the community BEFORE the product. Discord/Slack group around the pain point.

---

## RETENTION MECHANICS (why users stay past month 3)

### 6. Workflow Lock-in
**What:** Product becomes embedded in the user's daily workflow — switching is painful.
**Psychology:** Status quo bias + sunk cost + habit formation.
**Proof:**
- **Slack**: Replaces email → all team communication flows through it. Switching = losing history.
- **Salesforce**: CRM data accumulated over years. Migration is a 6-month project.
- **QuickBooks**: Tax data, integrations, accountant access. Switching cost is immense.
**Application:** Design to become the "system of record" for something important. The more data stored, the stickier.

### 7. Streak / Habit Loops
**What:** Consecutive-use tracking that creates psychological pressure to maintain.
**Psychology:** Loss aversion (2x stronger than equivalent gain) + sunk cost + habit formation.
**Proof:**
- **Duolingo**: Streaks are THE retention mechanic. Users 3x more likely to return daily. 47.7M DAU.
- **GitHub contribution graph**: Green squares create implicit streak pressure.
- **Snapchat**: 71% of daily usage from streak maintenance.
**Sub-mechanics:**
- Streak freezes (paid or earned) → revenue
- Friend streaks (mutual accountability)
- Streak milestones (special rewards at 7, 30, 100 days)
- Streak wagers (bet credits your streak survives)
**Application:** Works for any product with daily use case. Don't force it on products used weekly/monthly.

### 8. Data / AI Moat
**What:** Product improves with usage — more data = better recommendations/automations = more value.
**Psychology:** Personalization + "it knows me" + increasing returns.
**Proof:**
- **Spotify**: More listening → better Discover Weekly → more listening. Users with 10+ playlists churn 70% less.
- **Grammarly**: Learns your writing style → increasingly accurate → hard to switch.
- **Shopify**: Store data → Shopify Capital lending decisions → better rates → more stores.
**Application:** If your product uses AI, design the data flywheel from day one. What gets better with more usage?

### 9. Identity / Status
**What:** Users build a visible identity or status within the product that they don't want to lose.
**Psychology:** Endowment effect + social signaling + identity investment.
**Proof:**
- **LinkedIn**: Profile + connections + endorsements = professional identity. 900M+ users.
- **Stack Overflow reputation**: Points, badges, privileges. Top users moderate content. Status = retention.
- **Git City**: GitHub profile → pixel art building. Users pay for cosmetics. Identity visualization.
**Sub-mechanics:**
- Public profiles with achievements
- Tier/level progression (Bronze → Platinum)
- Cosmetics and customization (paid)
- Social signaling (badges, titles visible to others)
**Application:** Give users something visible they've built that only exists in your product.

### 10. Collaboration / Multiplayer
**What:** Multiple users work together in the product — one user leaving affects others.
**Psychology:** Social obligation + shared context + team switching cost.
**Proof:**
- **Figma**: Real-time collaboration → teams adopt → company subscribes. Average workspace: 8 users.
- **Notion**: Shared wikis → team knowledge base → org-wide adoption.
- **Linear**: Dev team workflow → everyone on the same board → can't switch without team consensus.
**Application:** The "invite team" moment is the highest-value event. Design onboarding to reach it fast.

---

## MONETIZATION MECHANICS

### 11. Seat-Based Pricing
**What:** Price per user/seat, with tiers for different feature access.
**Proof:** Slack, Salesforce, Jira. Simple to understand, scales with org size.
**Best for:** Collaboration tools, team workflow products.
**Risk:** "Seat consolidation" — teams share logins to avoid paying.

### 12. Usage-Based / Credits
**What:** Pay for what you consume — API calls, AI credits, storage, messages sent.
**Proof:** Twilio, OpenAI, Vercel, AWS. Aligns cost with value delivered.
**Best for:** AI-heavy products, APIs, infrastructure, variable-usage tools.
**Risk:** Revenue unpredictable. Users may self-limit usage.

### 13. Hybrid (Base + Usage)
**What:** Fixed subscription for base features + usage-based pricing for consumption.
**Proof:** HubSpot (seat + contacts), Intercom (seat + resolution), Snowflake (commitment + compute).
**Best for:** Products with both workflow (fixed) and AI/compute (variable) components.
**Advantage:** Predictable base revenue + expansion revenue from usage.

### 14. Service-as-Software (AI Agency Model)
**What:** Sell outcomes, not subscriptions. AI does 90% of work, human QA does 10%.
**Psychology:** Outcome-oriented buying, no subscription fatigue, premium perception.
**Proof:**
- **YC Spring 2026 RFS**: "AI-Powered Agencies" = fastest to revenue (1-2 weeks to first client).
- **Jasper pivot**: $50/mo tool → enterprise content service. Revenue 3x'd.
- **Design Pickle**: Flat-rate design service. $50M+ ARR.
**Application:** Perfect for "boring industries" — HVAC proposals, legal docs, construction estimates. Sell the deliverable, not the tool. Launch in weeks, not months.

### 15. Marketplace Commission
**What:** Take a cut of transactions between buyers and sellers on your platform.
**Proof:** Shopify App Store (20%), Stripe (2.9%), Airbnb (3% host + 14% guest).
**Best for:** Products connecting service providers with clients, template marketplaces, integration stores.
**Risk:** Must reach critical mass on both sides. Cold start problem.

---

## VIRALITY MECHANICS

### 16. Shareable Artifacts
**What:** Product generates visual or data artifacts that users naturally want to share.
**Psychology:** Identity expression + social signaling + "look what I made/achieved."
**Proof:**
- **Spotify Wrapped**: 30-40% of annual social mentions in one week. Users share voluntarily.
- **GitHub Skyline**: Contribution graph → 3D cityscape. Users 3D-print them.
- **Canva**: Designs created → shared on social → "Made with Canva" watermark → discovery.
**Application:** Design at least one moment that produces a screenshot-worthy output. Optimize for Instagram Stories (9:16) AND Twitter (2:1).

### 17. Inherent Exposure
**What:** Using the product automatically exposes non-users to it.
**Proof:**
- **Calendly**: Meeting invite = brand exposure. Every meeting = potential new user.
- **DocuSign**: Signing a document = seeing DocuSign. 1B+ envelopes sent.
- **Loom**: Sharing a video = showing the tool. "Recorded with Loom" branding.
**Application:** If your product produces outputs that go TO other people, brand the output.

### 18. Community / UGC Flywheel
**What:** Users create content within the product that attracts new users.
**Proof:**
- **Notion templates**: 100K+ public templates → Google indexes them → new users discover Notion.
- **Canva templates**: Same pattern. Templates as acquisition channel.
- **Stack Overflow**: User questions/answers → Google indexes → 100M monthly visitors.
**Application:** Make user-created content public and indexable by default. Each piece of UGC = a landing page.

---

## EMERGING MECHANICS

### 19. AI-Native (Remove AI = Business Dies)
**What:** The product fundamentally cannot exist without AI — not "old tool + chatbot."
**Proof:**
- **Cursor**: AI code editor. Remove AI = it's just VS Code. $100M+ ARR.
- **Midjourney**: AI image generation. No AI = nothing.
- **Harvey AI**: AI legal research. No AI = hiring 10 junior associates.
**Test:** Can you describe the product without mentioning AI? If yes, it's not AI-native.

### 20. Agent-as-Colleague
**What:** AI agent that acts as a team member — not a tool you use, but a colleague that works alongside you.
**Proof:**
- **Devin (Cognition)**: AI software engineer. Assigned tickets, writes PRs. $2B valuation.
- **Lindy AI**: Personal AI assistants for specific workflows. Each "Lindy" = a specialist.
- **11x.ai**: AI SDR (sales dev rep). Books meetings autonomously. $50M+ ARR.
**Application:** Frame AI not as "feature" but as "team member." Users don't use the tool, they delegate to it.

### 21. Vertical AI (Deep Niche)
**What:** AI trained/optimized for one specific vertical instead of general-purpose.
**Proof:**
- **Harvey AI**: Legal. $700M valuation. Lawyers pay 10x more than general knowledge workers.
- **Viz.ai**: Radiology AI. Detects strokes faster than humans. FDA-cleared.
- **Jasper**: Started as general → pivoted to enterprise content. Revenue 3x'd on focus.
**Application:** Pick one vertical, go deep. "AI for [specific industry]" beats "AI for everyone." Willingness to pay is 5-10x higher in verticals.

---

## ANTI-GRAVITY MECHANICS (accelerate early growth)

### 22. Waitlist with Social Proof
**What:** Pre-launch waitlist that creates urgency and validates demand.
**Proof:** Robinhood (1M+ before launch), Superhuman ($100M+ ARR started from waitlist).
**Tools:** GetWaitlist, QueueForm, Viral Loops. All have referral mechanics built in.
**Application:** Landing page + waitlist before writing code. If 500+ sign up in 30 days with $2K in ads, demand is validated.

### 23. Build in Public
**What:** Share the building process publicly — metrics, decisions, mistakes, wins.
**Psychology:** Authenticity + rooting for underdog + parasocial investment.
**Proof:**
- **Pieter Levels**: Nomad List, Remote OK, Photo AI. $3M+/mo revenue. Built in public on X.
- **Marc Lou**: ShipFast, ByeDispute. $100K+/mo. Tweets daily revenue.
- **Indie Hackers**: Entire platform is build-in-public success stories.
**Application:** Start sharing from day 1 — the build journey IS marketing. First 100 users come from followers invested in your story.

### 24. Multiple Launch Strategy
**What:** Launch the same product multiple times across channels, each with a new angle.
**Proof:**
- **Cursor**: Launched 5 times on Product Hunt in 2025. Product of the Year.
- **Notion**: Multiple PH launches over years, each featuring a different angle.
- **v0 by Vercel**: Two #1 Product of the Day launches.
**Sub-mechanics:**
- PH → HN → Twitter thread → Reddit → each is a separate event
- First launch = MVP. Second = "what users built." Third = major feature.
- HN timing: January and September have highest traffic.

---

## Challenger Generation Rules (critique mode only)

Used by the ideation sub-stage when in critique mode. Challengers are not substitutes — they are **structural adversaries** to the pinned concept, designed to stress-test it via ranking.

### Valid challenger shapes

A challenger must differ from the pinned concept on **at least one** of the following axes. Stronger challengers differ on two or more.

| Axis | What differs | Example shift |
|------|-------------|---------------|
| **Business model** | How money flows | Pinned: one-time fee + monthly sub → Challenger: freemium + usage-based |
| **Primary mechanic** | Growth / retention engine | Pinned: self-hosted deploy → Challenger: hosted marketplace of personas |
| **Audience segment** | Who pays first | Pinned: individual power users → Challenger: teams / small agencies |
| **Acquisition channel** | Where users discover | Pinned: organic dev community → Challenger: creator economy (YouTube/X creators selling their clone) |
| **Value chain position** | Upstream vs downstream | Pinned: generates configs → Challenger: runs the hosted agent itself |

### Invalid challengers (reject and regenerate)

- **Rename only** — same everything, different product name
- **Surface reframing** — same model, same audience, prettier words
- **Feature plus** — pinned + one extra feature, not structurally different
- **Absurd domain jump** — a challenger that serves a completely unrelated JTBD is not a challenger, it's noise

### Required per-challenger fields

Beyond the standard concept fields (Name, Tagline, Scale, Model, Hook, Retain, Refer, Mechanics, Risk, JTBD alignment), each challenger must include:

```
Why this could beat pinned: <1-2 sentence specific, falsifiable claim>
```

This is not flavor text — it is the **adversarial premise** that ranking uses to score honestly. Weak, hedging, or generic "Why this could beat pinned" lines indicate the challenger is not real.

### Quantity

4-7 challengers. Below 4 means the agent did not try hard enough. Above 7 means the agent is padding.

### Quality gate before listing

Before presenting the concept set to the user, check:

1. Pinned is Concept #1, verbatim from the user's framing
2. Each challenger differs from pinned on at least one structural axis (check against the table above)
3. Each challenger's "Why this could beat pinned" is specific and falsifiable
4. No two challengers collapse to the same strategy (if two challengers both say "go marketplace", pick the stronger one)

If any check fails, regenerate the failing challenger before listing.
