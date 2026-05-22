/**
 * build-report.ts — /product navigable HTML report generator (spec 073)
 *
 * Deterministic, zero-npm-dependency (Node/Bun stdlib only). Reads the raw
 * `/product` artifacts under `<out>/docs/`, packs them into one script-safe
 * JSON blob, injects that + a pre-rendered nav into `templates/report.html.tmpl`,
 * and writes `<out>/docs/REPORT.html`. Markdown is NOT parsed here — rendering
 * happens client-side in the browser via marked (see the template).
 *
 * Invocation (same convention as sync-open-design.ts — bun, no shebang):
 *   bun scripts/build-report.ts --out=<project-root> [--slug=<s>] [--stack=<s>]
 *
 * Idempotent: re-running against an unchanged `docs/` yields byte-identical
 * output except the single `generated_at` field. Invoked by SKILL.md at the
 * 3 phase gates + the terminal Phase 5 step.
 */

import { readFileSync, existsSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const SKILL_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const TEMPLATE_PATH = path.join(SKILL_ROOT, 'templates', 'report.html.tmpl');

export type Status = 'ok' | 'partial' | 'pending' | 'blocked';
export type PartKind = 'md' | 'code' | 'iframe-file' | 'iframe-dir';

export interface ManifestPart {
  label: string;
  /** path relative to docsDir; may contain a single `*` segment for glob */
  path: string;
  kind: PartKind;
  lang?: string;
}

export interface ManifestEntry {
  id: string;
  step: string;
  phase: number;
  phaseName: string;
  title: string;
  parts: ManifestPart[];
}

/**
 * ARTIFACT_MANIFEST is the single source of truth for the report's rendering
 * order. The 15-step pipeline is fixed; `references/pipeline-coverage.md`
 * points here. Adding/removing a pipeline step means editing this array.
 */
export const ARTIFACT_MANIFEST: ManifestEntry[] = [
  { id: 'overview', step: '—', phase: 0, phaseName: 'Overview', title: 'Run overview',
    parts: [{ label: 'REPORT.md', path: 'REPORT.md', kind: 'md' }] },

  { id: '01', step: '01', phase: 1, phaseName: 'Phase 1 · Discovery', title: 'Ideation / Concept brief',
    parts: [{ label: 'concept-brief.md', path: 'concept-brief.md', kind: 'md' }] },
  { id: '02', step: '02', phase: 1, phaseName: 'Phase 1 · Discovery', title: 'Prototype v1 (lo-fi mood)',
    parts: [
      { label: 'direction-a.html', path: 'direction-a.html', kind: 'iframe-file' },
      { label: 'Lo-fi screens', path: 'screens', kind: 'iframe-dir' },
    ] },
  { id: '03', step: '03', phase: 1, phaseName: 'Phase 1 · Discovery', title: 'Functional spec',
    parts: [{ label: 'functional-spec.md', path: 'functional-spec.md', kind: 'md' }] },
  { id: '04', step: '04', phase: 1, phaseName: 'Phase 1 · Discovery', title: 'UX testing',
    parts: [{ label: 'validation-report.md', path: 'validation-report.md', kind: 'md' }] },

  { id: '05', step: '05', phase: 2, phaseName: 'Phase 2 · Specification', title: 'PRD (1-pager)',
    parts: [{ label: 'prd/v1.md', path: 'prd/v1.md', kind: 'md' }] },
  { id: '06', step: '06', phase: 2, phaseName: 'Phase 2 · Specification', title: 'OST',
    parts: [{ label: 'ost.md', path: 'ost.md', kind: 'md' }] },
  { id: '07', step: '07', phase: 2, phaseName: 'Phase 2 · Specification', title: 'Sitemap-IA',
    parts: [{ label: 'sitemap.yaml', path: 'sitemap.yaml', kind: 'code', lang: 'yaml' }] },
  { id: '08', step: '08', phase: 2, phaseName: 'Phase 2 · Specification', title: 'System design',
    parts: [
      { label: 'system-design.md', path: 'system-design.md', kind: 'md' },
      { label: 'security.md', path: 'security.md', kind: 'md' },
      { label: 'data-flow.json', path: 'data-flow.json', kind: 'code', lang: 'json' },
    ] },
  { id: '09', step: '09', phase: 2, phaseName: 'Phase 2 · Specification', title: 'Legal posture',
    parts: [{ label: 'legal-posture.md', path: 'legal-posture.md', kind: 'md' }] },
  { id: '10', step: '10', phase: 2, phaseName: 'Phase 2 · Specification', title: 'Roadmap',
    parts: [{ label: 'roadmap.md', path: 'roadmap.md', kind: 'md' }] },
  { id: '11', step: '11', phase: 2, phaseName: 'Phase 2 · Specification', title: 'Cost estimate',
    parts: [{ label: 'cost-estimate.md', path: 'cost-estimate.md', kind: 'md' }] },
  { id: '12', step: '12', phase: 2, phaseName: 'Phase 2 · Specification', title: 'GTM launch',
    parts: [{ label: 'gtm-launch.md', path: 'gtm-launch.md', kind: 'md' }] },

  { id: '13', step: '13', phase: 3, phaseName: 'Phase 3 · Identity', title: 'Brand book',
    parts: [{ label: 'brand-book.md', path: 'brand-book.md', kind: 'md' }] },
  { id: '14', step: '14', phase: 3, phaseName: 'Phase 3 · Identity', title: 'Design system',
    parts: [
      { label: 'design-system/tokens.css', path: 'design-system/tokens.css', kind: 'code', lang: 'css' },
      { label: 'design-system/components.md', path: 'design-system/components.md', kind: 'md' },
      { label: 'design-system/README.md', path: 'design-system/README.md', kind: 'md' },
    ] },

  // Visual artifacts lead: the hi-fi screens render *before* screen-atlas.md so
  // they are not buried below ~10k px of rendered markdown. Within a step,
  // iframe parts precede long prose — mirrors Step 02 (fix 2026-05-22).
  { id: '15', step: '15', phase: 4, phaseName: 'Phase 4 · Visual contract', title: 'Visual contract',
    parts: [
      { label: 'Hi-fi screens', path: 'screens/hifi', kind: 'iframe-dir' },
      { label: 'screen-atlas.md', path: 'screen-atlas.md', kind: 'md' },
      { label: 'fixture-spec.md', path: 'fixture-spec.md', kind: 'md' },
    ] },

  { id: 'sdd', step: '—', phase: 5, phaseName: 'Phase 5 · SDD handoff', title: 'SDD handoff specs',
    parts: [
      { label: 'specs/001-* (umbrella)', path: 'specs/001-*/spec.md', kind: 'md' },
      { label: 'specs/002-foundation', path: 'specs/002-foundation/spec.md', kind: 'md' },
    ] },
];

/** The 15 numbered pipeline steps — used for the `N/15` coverage figure. */
const PIPELINE_STEP_IDS = ['01', '02', '03', '04', '05', '06', '07', '08',
  '09', '10', '11', '12', '13', '14', '15'];

/**
 * escapeForScriptTag — make a JSON string safe to embed inside a
 * `<script type="application/json">` element. Replacing every `<` with its
 * `<` escape means no `</script>`, `<!--`, or `<script` sequence can
 * break out of the tag; JSON.parse decodes `<` back to `<` on read.
 */
export function escapeForScriptTag(json: string): string {
  return json.replace(/</g, '\\u003c');
}

/**
 * tabSlugFor — derive a stable, URL-safe slug for a manifest part. Each
 * manifest part becomes one sub-tab in the report; the slug is the deep-link
 * fragment after the step id (`#15/screens-hifi`). Deterministic, so a deep
 * link survives report regeneration as long as the manifest path is stable.
 */
export function tabSlugFor(part: ManifestPart): string {
  return part.path
    .replace(/\.[a-z0-9]+$/i, '')   // drop file extension
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')    // any run of non-alphanumerics → one dash
    .replace(/^-+|-+$/g, '');       // trim leading/trailing dashes
}

/** classifyArtifact — pure status derivation from on-disk presence + blocked flag. */
export function classifyArtifact(present: number, total: number, blocked: boolean): Status {
  if (blocked) return 'blocked';
  if (present === 0) return 'pending';
  if (present >= total) return 'ok';
  return 'partial';
}

const STATUS_ICON: Record<Status, string> = { ok: '✓', partial: '◐', blocked: '✗', pending: '·' };

/** Resolve a path that may contain a single `*` segment into concrete paths. */
function globRelative(docsDir: string, relPattern: string): string[] {
  const segments = relPattern.split('/');
  let bases = [docsDir];
  for (const seg of segments) {
    const next: string[] = [];
    for (const base of bases) {
      if (seg.includes('*')) {
        const re = new RegExp('^' + seg.replace(/[.+?^${}()|[\]\\]/g, '\\$&').replace(/\*/g, '.*') + '$');
        if (!existsSync(base)) continue;
        for (const entry of readdirSync(base)) {
          if (re.test(entry)) next.push(path.join(base, entry));
        }
      } else {
        next.push(path.join(base, seg));
      }
    }
    bases = next;
  }
  return bases.filter((p) => existsSync(p));
}

/** List `*.html` files directly inside a directory (non-recursive), sorted. */
function listHtmlFiles(dir: string): string[] {
  if (!existsSync(dir) || !statSync(dir).isDirectory()) return [];
  return readdirSync(dir)
    .filter((f) => f.toLowerCase().endsWith('.html'))
    .filter((f) => statSync(path.join(dir, f)).isFile())
    .sort();
}

/** Read a file's text, or '' on any error — used to inline an artifact verbatim. */
function readArtifact(abs: string): string {
  try { return readFileSync(abs, 'utf8'); } catch { return ''; }
}

interface ResolvedPart {
  label: string;
  kind: 'md' | 'code' | 'iframe' | 'missing';
  /** url slug of the sub-tab this part belongs to — see tabSlugFor */
  tabSlug: string;
  content?: string;
  lang?: string;
  /** verbatim HTML of an iframe artifact, inlined so REPORT.html stays portable */
  srcdoc?: string;
}

interface ResolvedEntry {
  id: string;
  step: string;
  phase: number;
  phaseName: string;
  title: string;
  status: Status;
  /** distinct sub-tabs in render order — one per manifest part */
  tabs: { label: string; slug: string }[];
  parts: ResolvedPart[];
}

function isStepBlocked(stepId: string, blocked: unknown[]): boolean {
  if (stepId === '—') return false;
  return blocked.some((b) => {
    const s = typeof b === 'string' ? b : JSON.stringify(b);
    return s.includes(stepId);
  });
}

/** Resolve one manifest entry against the on-disk docs/ tree. */
export function resolveEntry(entry: ManifestEntry, docsDir: string, blocked: unknown[]): ResolvedEntry {
  const parts: ResolvedPart[] = [];
  const tabs: { label: string; slug: string }[] = [];
  let present = 0;
  let total = 0;

  for (const part of entry.parts) {
    total++;
    // Each manifest part is one sub-tab. Every resolved part it produces (an
    // iframe-dir fans out to several) carries that tab's slug, so the client
    // can render one tab's parts at a time.
    const tabSlug = tabSlugFor(part);
    tabs.push({ label: part.label, slug: tabSlug });

    // HTML artifacts are inlined verbatim as `srcdoc` (not linked by relative
    // path) — REPORT.html then survives a move away from its sibling files.
    if (part.kind === 'iframe-dir') {
      const dir = path.join(docsDir, part.path);
      const files = listHtmlFiles(dir);
      if (files.length > 0) {
        present++;
        for (const f of files) {
          parts.push({ label: `${part.path}/${f}`, kind: 'iframe',
            srcdoc: readArtifact(path.join(dir, f)), tabSlug });
        }
      } else {
        parts.push({ label: part.label, kind: 'missing', tabSlug });
      }
      continue;
    }
    if (part.kind === 'iframe-file') {
      const abs = path.join(docsDir, part.path);
      if (existsSync(abs)) {
        present++;
        parts.push({ label: part.label, kind: 'iframe', srcdoc: readArtifact(abs), tabSlug });
      } else {
        parts.push({ label: part.label, kind: 'missing', tabSlug });
      }
      continue;
    }
    // md / code — may carry a glob
    const matches = part.path.includes('*')
      ? globRelative(docsDir, part.path)
      : (existsSync(path.join(docsDir, part.path)) ? [path.join(docsDir, part.path)] : []);
    if (matches.length > 0) {
      present++;
      for (const abs of matches) {
        const rel = path.relative(docsDir, abs);
        const content = readArtifact(abs);
        parts.push({
          label: matches.length > 1 ? rel : part.label,
          kind: part.kind === 'code' ? 'code' : 'md',
          content,
          lang: part.lang,
          tabSlug,
        });
      }
    } else {
      parts.push({ label: part.label, kind: 'missing', tabSlug });
    }
  }

  const status = classifyArtifact(present, total, isStepBlocked(entry.step, blocked));
  return { id: entry.id, step: entry.step, phase: entry.phase, phaseName: entry.phaseName,
    title: entry.title, status, tabs, parts };
}

/** Build the pre-rendered sidebar nav HTML from resolved entries. */
function buildNav(entries: ResolvedEntry[]): string {
  const out: string[] = [];
  let phase = -1;
  for (const e of entries) {
    if (e.phase !== phase) {
      if (phase !== -1) out.push('</div>');
      out.push(`<div class="phase"><div class="phase-h">${escHtml(e.phaseName)}</div>`);
      phase = e.phase;
    }
    const label = e.id === 'overview' || e.id === 'sdd'
      ? e.title
      : `${e.step} · ${e.title}`;
    out.push(
      `<button class="nav-item" data-id="${escHtml(e.id)}" data-status="${e.status}">` +
      `<span class="ico">${STATUS_ICON[e.status]}</span> ${escHtml(label)}</button>`,
    );
  }
  if (phase !== -1) out.push('</div>');
  return out.join('\n');
}

function escHtml(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

interface BuildOptions {
  slug?: string;
  stack?: string;
  now?: string;
}

/**
 * buildReportHtml — pure(ish) core: reads artifacts from docsDir, renders the
 * full REPORT.html string. `now` is injectable so tests can assert idempotency.
 */
export function buildReportHtml(docsDir: string, template: string, opts: BuildOptions = {}): string {
  let blocked: unknown[] = [];
  let stateSlug: string | undefined;
  let stateStack: string | undefined;
  try {
    const state = JSON.parse(readFileSync(path.join(docsDir, '.state.json'), 'utf8'));
    if (Array.isArray(state.blocked_steps)) blocked = state.blocked_steps;
    if (typeof state.slug === 'string') stateSlug = state.slug;
    if (state.flags && typeof state.flags.stack === 'string') stateStack = state.flags.stack;
  } catch { /* no/invalid state — treat nothing as blocked, fall back on metadata */ }

  const entries = ARTIFACT_MANIFEST.map((e) => resolveEntry(e, docsDir, blocked));
  const okSteps = entries.filter((e) => PIPELINE_STEP_IDS.includes(e.id) && e.status === 'ok').length;
  const coverage = `${okSteps}/15`;
  const coveragePct = Math.round((okSteps / 15) * 100);

  const payload = {
    coverage_pct: coveragePct,
    artifacts: entries.map((e) => ({
      id: e.id, step: e.step, phase: e.phase, phaseName: e.phaseName,
      title: e.title, status: e.status, tabs: e.tabs,
      parts: e.parts.map((p) => ({
        label: p.label, kind: p.kind, tabSlug: p.tabSlug,
        ...(p.content !== undefined ? { content: p.content } : {}),
        ...(p.lang ? { lang: p.lang } : {}),
        ...(p.srcdoc !== undefined ? { srcdoc: p.srcdoc } : {}),
      })),
    })),
  };

  const subs: Record<string, string> = {
    GENERATED_AT: opts.now ?? new Date().toISOString(),
    SLUG: escHtml(opts.slug ?? stateSlug ?? path.basename(path.dirname(docsDir))),
    STACK: escHtml(opts.stack ?? stateStack ?? '—'),
    COVERAGE: coverage,
    NAV: buildNav(entries),
    REPORT_DATA: escapeForScriptTag(JSON.stringify(payload)),
  };

  return template.replace(/\{\{([A-Z_]+)\}\}/g, (m, key) => (key in subs ? subs[key] : m));
}

function parseArgs(argv: string[]): Record<string, string> {
  const args: Record<string, string> = {};
  for (const a of argv) {
    const m = a.match(/^--([a-z-]+)=(.*)$/);
    if (m) args[m[1]] = m[2];
  }
  return args;
}

function main(): void {
  const args = parseArgs(process.argv.slice(2));
  if (!args.out) {
    console.error('usage: bun scripts/build-report.ts --out=<project-root> [--slug=<s>] [--stack=<s>]');
    process.exit(1);
  }
  const docsDir = path.join(path.resolve(args.out), 'docs');
  if (!existsSync(docsDir)) {
    console.error(`build-report: no docs/ directory at ${docsDir}`);
    process.exit(1);
  }
  const template = readFileSync(TEMPLATE_PATH, 'utf8');
  const html = buildReportHtml(docsDir, template, { slug: args.slug, stack: args.stack });
  const outPath = path.join(docsDir, 'REPORT.html');
  writeFileSync(outPath, html, 'utf8');
  console.error(`build-report: wrote ${outPath}`);
}

if (import.meta.main) main();
