# Spec examples — good vs bad

Concrete contrasts for the load-bearing shapes in `functional-spec.md`. Synthesised from `anthill-spec`'s examples. The pattern in every pair: vague loses, concrete wins.

## Components table

**Good — every element, typed, described:**

```markdown
| Component | Type | Description |
|-----------|------|-------------|
| Sidebar | navigation | App nav with links to Dashboard, Projects, Settings |
| MetricCards | data-display | Row of 4 cards: open tasks, due today, overdue, done this week |
| TimeFilter | input | Dropdown — 7d / 30d / 90d / custom range |
| ExportButton | action | Downloads the current view as a PDF report |
| EmptyChart | feedback | Shown when the selected range has no data |
```

**Bad — vague, untyped, half the elements missing:**

```markdown
| Component | Description |
|-----------|-------------|
| Dashboard | Shows metrics |
| Sidebar | Navigation |
| Button | Does stuff |
```

## Interactions table

**Good — trigger, action, and result all concrete:**

```markdown
| Component | Trigger | Action | Result |
|-----------|---------|--------|--------|
| TimeFilter | select "30d" | reloads chart data | chart animates to last 30 days, cards update |
| ExportButton | click | generates PDF | download starts, toast "Report downloaded" appears |
| MetricCard | click | navigates | opens the detail page for that metric |
```

**Bad — missing actions or results, unverifiable:**

```markdown
| Component | Trigger | Result |
|-----------|---------|--------|
| Filter | click | Updates |
| Button | click | Opens page |
```

## States table

**Good — every state has a user-visible description:**

```markdown
| State | Condition | What the user sees |
|-------|-----------|-------------------|
| Empty | new account, no data yet | illustration + "Connect your first data source" button |
| Loading | fetching from server | 4 skeleton cards + chart placeholder with shimmer |
| Error | server unreachable | red banner "Unable to load — check your connection" + retry button |
| Populated | data available | cards with numbers, chart with trend line, filters active |
| Filtered-empty | filter matches nothing | "No results for this range" + clear-filter link |
```

**Bad — states missing, conditions hand-waved:**

```markdown
| State | What the user sees |
|-------|-------------------|
| Normal | The data |
| Other | An error maybe |
```

## Feature block

**Good — decomposed, edge cases specific, success criterion observable:**

```markdown
### Create project

- **What it does:** lets a signed-in user create a new project from the Dashboard.
- **Happy path:**
  1. User clicks CreateButton → new-project modal opens with name field focused
  2. User types a name, clicks "Create" → modal closes, project appears at the top of ProjectList
  3. Toast "Project created" appears for 3s
- **Edge cases:**
  - Empty name → "Create" disabled, helper text "Name is required"
  - Duplicate name → inline error "A project with this name already exists"
  - Network failure on submit → modal stays open, error banner + "Try again"
- **Success criterion:** the new project is visible in ProjectList within 1s of a
  successful submit, and survives a page reload.
```

**Bad — restates the feature, no edges, unverifiable success:**

```markdown
### Create project

- The user can create projects.
- It should work well.
- Success: projects are created.
```

## Acceptance scenario

**Good — assertion-shaped Then:**

```markdown
### Scenario: create project with a duplicate name

- **Given** a project named "Apollo" already exists
- **When** the user submits the new-project modal with the name "Apollo"
- **Then** the modal stays open and shows the inline error "A project with this name already exists", and no new project appears in ProjectList
```

**Bad — vague Then, nothing to verify:**

```markdown
### Scenario: duplicate name

- **Given** a project exists
- **When** the user makes another one
- **Then** it is handled correctly
```

## Decisions Pending table

**Good — plain-language question, named impact, concrete default:**

```markdown
| # | Question | Impact | Default if unresolved |
|---|----------|--------|----------------------|
| 1 | Project detail: slide-over drawer vs. full page? | Projects IA + navigation map | drawer |
| 2 | Multi-select on the project list: v1 or defer? | bulk-action scope | defer to v2 |
```

**Bad — technical, impact missing, no default:**

```markdown
| # | Question |
|---|----------|
| 1 | Drawer or page? |
| 2 | Bulk stuff? |
```

## Navigation map

**Good — every page, every transition has a trigger:**

```
Landing
   | (sign up / log in)
Dashboard <───────> Settings
   | (click project)        ^
   v                        | (click "Account")
Project Detail <──> Project Settings
```

**Bad — orphan pages, no triggers:**

```
Dashboard
Settings
Project page
```
