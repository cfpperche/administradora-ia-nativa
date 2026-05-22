# Question bank — feature discovery

Used by `/sdd refine` (see `../SKILL.md` § Subcommand: refine). 56 questions in 7 categories. Each discovery round picks 2-3 — the ones most relevant to what is still unknown. Do not run the bank as a checklist; it is a menu.

Before asking any question, grep/read the repo first — config files, `.claude/rules/`, `.claude/memory/`, existing `docs/specs/`, schemas, modules. Asking is the fallback, not the default. State the file you read so the user sees the grounding.

## Problem validation (is this worth building?)

1. Who hits this problem today? Can you name a specific user or caller?
2. How do they work around it right now? (A workaround is validated demand.)
3. What happens if we never build this? What is the actual cost?
4. Is this a daily pain, a weekly annoyance, or a rare edge case?
5. Has anyone explicitly asked for this, or is it assumed?
6. Is this load-bearing for something else, or standalone?
7. Is this a painkiller (must-have) or a vitamin (nice-to-have)?
8. How would you measure success? What changes once it ships?

## Scope and boundaries (what is v1 vs future?)

9. What is the absolute smallest version that is still useful?
10. What is explicitly OUT of scope? (Name 3 things this is NOT.)
11. Does v1 need to handle edge cases, or just the happy path?
12. Should this be a full feature, a config toggle, or a smarter default?
13. What is the done criteria? When do we stop iterating on v1?
14. If you had to ship this in a day, what would you cut?
15. Are there anti-goals — things this must NOT become?
16. Does this need to be reversible, or is it one-way (migrations, infra, destructive ops)?
17. Who else depends on the surface this touches?

## Architecture and data (how does it fit the system?)

18. This seems related to an existing module/spec — extend it or create new?
19. Where does new state live? New file, new field, or computed on the fly?
20. Does this need its own entrypoint/command, or can it piggyback on an existing one?
21. Synchronous or does it need background/deferred processing?
22. Any caching or persistence implications?
23. Does this touch authentication, authorization, or trust boundaries?
24. Schema or format migration needed? Is there existing data to migrate?
25. Does this conflict with an existing decision in `docs/specs/` or a rule in `.claude/rules/`?
26. Monorepo/multi-package impact — does this cross package boundaries?
27. Does this change a public API, schema, or wire contract another component depends on?

## External integrations (does it depend on outside systems?)

28. Does this require a new external API or tool? Which one? Rate limits? Cost?
29. Is the dependency reliable? What is the fallback if it is unavailable?
30. What credentials does it need, and where do they live?
31. Event-driven or polling? What events actually matter?
32. Is there a sandbox or test mode for it?
33. Any terms-of-service or licensing restrictions to know about?

## User experience (what does the user see and feel?)

34. Where does this surface — new command, flag, output block, file?
35. Who is the primary user — the human operator, the agent, or a downstream consumer?
36. What does the user SEE that tells them this exists?
37. What does success look like from the user's perspective?
38. Does this need explanation/onboarding, or should it be self-evident?
39. What happens when there is no data yet? (Empty state.)
40. What error states are possible? How should they read?
41. Does this need a progress or loading signal?
42. Does the output need to be machine-parseable as well as human-readable?

## Tradeoffs and risks (what could go wrong?)

43. This adds complexity to some area — is the value worth the maintenance cost?
44. What breaks if this is down or buggy? Is it on a critical path?
45. Performance impact — does this slow down an existing path?
46. Security implications — does this open new attack surface?
47. What is the worst case if this has a bug? Data loss? Silent corruption? Annoyance?
48. Build custom or adopt an existing tool? (Make vs buy.)
49. Does this create technical debt we will need to pay later?
50. If this is deferred a quarter, does it matter? (Urgency check.)

## Impact and opportunity cost (does it move the needle?)

51. Does this unblock other planned work, or is it a leaf?
52. Does this reduce friction, prevent a class of error, or enable something new?
53. Does this serve a new persona or use case the project does not handle today?
54. Is this a differentiator or table stakes?
55. Is this worth announcing — does it change how the project is described?
56. What is the opportunity cost? What do we NOT build if we build this?
