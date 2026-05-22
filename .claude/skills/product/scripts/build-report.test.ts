/**
 * Unit + integration tests for build-report.ts (spec 073, product-report-html).
 *
 * Covers the exported pure pieces — `escapeForScriptTag`, `classifyArtifact` —
 * plus `buildReportHtml` against synthetic fixture `docs/` trees: full run,
 * partial run, idempotency, <script>-tag safety, and blocked-step status.
 */

import { afterEach, beforeEach, describe, expect, test } from 'bun:test';
import { mkdtemp, mkdir, rm, writeFile, readFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import {
  buildReportHtml,
  classifyArtifact,
  escapeForScriptTag,
  tabSlugFor,
} from './build-report.js';

const TEMPLATE_PATH = join(import.meta.dir, '..', 'templates', 'report.html.tmpl');
let template = '';
let tmpRoot = '';

beforeEach(async () => {
  template = await readFile(TEMPLATE_PATH, 'utf8');
  tmpRoot = await mkdtemp(join(tmpdir(), 'build-report-test-'));
});

afterEach(async () => {
  await rm(tmpRoot, { recursive: true, force: true });
});

/** Write a set of relative paths under `docsDir`, each with given content. */
async function writeFixture(docsDir: string, files: Record<string, string>): Promise<void> {
  for (const [rel, content] of Object.entries(files)) {
    const abs = join(docsDir, rel);
    await mkdir(dirname(abs), { recursive: true });
    await writeFile(abs, content, 'utf8');
  }
}

/** All artifacts a complete `/product` run produces. */
const FULL_FIXTURE: Record<string, string> = {
  'REPORT.md': '# Run overview\n\nNarrative.',
  'concept-brief.md': '# Concept brief\n\n| a | b |\n|---|---|\n| 1 | 2 |',
  'direction-a.html': '<!doctype html><title>dir-a</title><body>mood</body>',
  'screens/01-home.html': '<!doctype html><title>home</title>',
  'screens/02-detail.html': '<!doctype html><title>detail</title>',
  'functional-spec.md': '# Functional spec',
  'validation-report.md': '# UX validation',
  'prd/v1.md': '# PRD v1',
  'ost.md': '# OST',
  'sitemap.yaml': 'routes:\n  - path: /\n',
  'system-design.md': '# System design\n\n```mermaid\ngraph TD; A-->B;\n```',
  'security.md': '# Security',
  'data-flow.json': '{"flows":[]}',
  'legal-posture.md': '# Legal posture',
  'roadmap.md': '# Roadmap',
  'cost-estimate.md': '# Cost estimate',
  'gtm-launch.md': '# GTM launch',
  'brand-book.md': '# Brand book',
  'design-system/tokens.css': ':root { --c: #fff; }',
  'design-system/components.md': '# Components',
  'design-system/README.md': '# Design system',
  'screen-atlas.md': '# Screen atlas',
  'screens/hifi/01-home.html': '<!doctype html><title>hifi home</title>',
  'fixture-spec.md': '# Fixture spec',
  'specs/001-demo/spec.md': '# 001 umbrella',
  'specs/002-foundation/spec.md': '# 002 foundation',
};

/** Extract + parse the embedded report-data JSON from a generated REPORT.html. */
function extractPayload(html: string): any {
  const m = html.match(/<script type="application\/json" id="report-data">([\s\S]*?)<\/script>/);
  if (!m) throw new Error('report-data script block not found');
  return JSON.parse(m[1]);
}

describe('escapeForScriptTag', () => {
  test('neutralises a </script> sequence', () => {
    const out = escapeForScriptTag('{"x":"a</script>b"}');
    expect(out.includes('</script>')).toBe(false);
    expect(out.includes('\\u003c')).toBe(true);
  });

  test('round-trips through JSON.parse', () => {
    const original = { md: 'before </script> after <script>x</script>' };
    const escaped = escapeForScriptTag(JSON.stringify(original));
    expect(escaped.includes('</script>')).toBe(false);
    expect(JSON.parse(escaped)).toEqual(original);
  });
});

describe('classifyArtifact', () => {
  test('pending when nothing present', () => {
    expect(classifyArtifact(0, 1, false)).toBe('pending');
  });
  test('ok when all parts present', () => {
    expect(classifyArtifact(3, 3, false)).toBe('ok');
  });
  test('partial when some parts present', () => {
    expect(classifyArtifact(1, 3, false)).toBe('partial');
  });
  test('blocked overrides presence', () => {
    expect(classifyArtifact(0, 1, true)).toBe('blocked');
    expect(classifyArtifact(3, 3, true)).toBe('blocked');
  });
});

describe('tabSlugFor', () => {
  test('drops the extension and slugifies the path', () => {
    expect(tabSlugFor({ label: 'x', path: 'screen-atlas.md', kind: 'md' })).toBe('screen-atlas');
    expect(tabSlugFor({ label: 'x', path: 'screens/hifi', kind: 'iframe-dir' })).toBe('screens-hifi');
    expect(tabSlugFor({ label: 'x', path: 'design-system/tokens.css', kind: 'code' }))
      .toBe('design-system-tokens');
  });
  test('a glob segment collapses to a dash, not a literal star', () => {
    expect(tabSlugFor({ label: 'x', path: 'specs/001-*/spec.md', kind: 'md' })).toBe('specs-001-spec');
  });
});

describe('buildReportHtml — full run', () => {
  test('renders all 15 steps as ok with 15/15 coverage', async () => {
    await writeFixture(tmpRoot, FULL_FIXTURE);
    const html = buildReportHtml(tmpRoot, template, { now: 'FIXED', slug: 'demo', stack: 'next' });
    const payload = extractPayload(html);

    const steps = payload.artifacts.filter((a: any) => /^\d\d$/.test(a.id));
    expect(steps.length).toBe(15);
    expect(steps.every((a: any) => a.status === 'ok')).toBe(true);
    expect(payload.coverage_pct).toBe(100);
    expect(html.includes('15/15')).toBe(true);
    // sidebar nav has an entry per step
    expect((html.match(/class="nav-item"/g) || []).length).toBe(17); // overview + 15 + sdd
  });

  test('embeds markdown raw and mood screens as iframe parts', async () => {
    await writeFixture(tmpRoot, FULL_FIXTURE);
    const payload = extractPayload(buildReportHtml(tmpRoot, template, { now: 'FIXED' }));

    const concept = payload.artifacts.find((a: any) => a.id === '01');
    expect(concept.parts[0].kind).toBe('md');
    expect(concept.parts[0].content).toContain('# Concept brief');

    const proto = payload.artifacts.find((a: any) => a.id === '02');
    const frames = proto.parts.filter((p: any) => p.kind === 'iframe');
    // HTML artifacts are inlined as srcdoc (portable), never linked via src
    expect(frames.every((f: any) => f.src === undefined)).toBe(true);
    const srcdocs = frames.map((f: any) => f.srcdoc);
    expect(srcdocs.some((s: string) => s.includes('<title>dir-a</title>'))).toBe(true);
    expect(srcdocs.some((s: string) => s.includes('<title>home</title>'))).toBe(true);

    const sitemap = payload.artifacts.find((a: any) => a.id === '07');
    expect(sitemap.parts[0].kind).toBe('code');
    expect(sitemap.parts[0].lang).toBe('yaml');
  });

  test('HTML artifacts are inlined as iframe srcdoc, never a relative src', async () => {
    await writeFixture(tmpRoot, FULL_FIXTURE);
    const payload = extractPayload(buildReportHtml(tmpRoot, template, { now: 'FIXED' }));
    const iframes = payload.artifacts
      .flatMap((a: any) => a.parts)
      .filter((p: any) => p.kind === 'iframe');
    expect(iframes.length).toBeGreaterThan(0);
    // every iframe carries the verbatim file content; none a bare src path
    expect(iframes.every((p: any) => typeof p.srcdoc === 'string' && p.srcdoc.length > 0)).toBe(true);
    expect(iframes.every((p: any) => p.src === undefined)).toBe(true);
  });

  test('step 15 leads with the hi-fi screens, before screen-atlas.md', async () => {
    await writeFixture(tmpRoot, FULL_FIXTURE);
    const payload = extractPayload(buildReportHtml(tmpRoot, template, { now: 'FIXED' }));

    // Visual-before-prose: the hi-fi iframe parts must precede the long
    // screen-atlas.md so the rendered screens are not buried below ~10k px of
    // markdown (regression guard — fix 2026-05-22).
    const visualContract = payload.artifacts.find((a: any) => a.id === '15');
    const kinds = visualContract.parts.map((p: any) => p.kind);
    const firstIframe = kinds.indexOf('iframe');
    const firstMd = kinds.indexOf('md');
    expect(firstIframe).toBeGreaterThanOrEqual(0);
    expect(firstIframe).toBeLessThan(firstMd);
  });

  test('each artifact carries a tabs list; a multi-part step gets one tab per part', async () => {
    await writeFixture(tmpRoot, FULL_FIXTURE);
    const payload = extractPayload(buildReportHtml(tmpRoot, template, { now: 'FIXED' }));

    // single-part step → exactly one tab (the client renders no tab row)
    const ideation = payload.artifacts.find((a: any) => a.id === '01');
    expect(ideation.tabs.length).toBe(1);

    // Step 15 has three manifest parts → three sub-tabs, in render order
    const visualContract = payload.artifacts.find((a: any) => a.id === '15');
    expect(visualContract.tabs.map((t: any) => t.slug))
      .toEqual(['screens-hifi', 'screen-atlas', 'fixture-spec']);

    // every hi-fi iframe part is filed under the first tab's slug
    const hifi = visualContract.parts.filter((p: any) => p.kind === 'iframe');
    expect(hifi.length).toBeGreaterThan(0);
    expect(hifi.every((p: any) => p.tabSlug === 'screens-hifi')).toBe(true);
  });
});

describe('buildReportHtml — partial run at a gate', () => {
  test('steps 01-04 ok, 05-15 pending, no crash', async () => {
    await writeFixture(tmpRoot, {
      'REPORT.md': '# overview',
      'concept-brief.md': '# brief',
      'direction-a.html': '<title>a</title>',
      'screens/01-x.html': '<title>x</title>',
      'functional-spec.md': '# spec',
      'validation-report.md': '# ux',
    });
    const payload = extractPayload(buildReportHtml(tmpRoot, template, { now: 'FIXED' }));

    const status = (id: string) => payload.artifacts.find((a: any) => a.id === id).status;
    expect(['01', '02', '03', '04'].every((id) => status(id) === 'ok')).toBe(true);
    expect(['05', '08', '12', '15'].every((id) => status(id) === 'pending')).toBe(true);
    expect(payload.coverage_pct).toBe(Math.round((4 / 15) * 100));
  });
});

describe('buildReportHtml — idempotency', () => {
  test('byte-identical output for an unchanged docs/ + fixed now', async () => {
    await writeFixture(tmpRoot, FULL_FIXTURE);
    const a = buildReportHtml(tmpRoot, template, { now: 'FIXED', slug: 'demo' });
    const b = buildReportHtml(tmpRoot, template, { now: 'FIXED', slug: 'demo' });
    expect(a).toBe(b);
  });

  test('only the generated_at value differs across runs', async () => {
    await writeFixture(tmpRoot, FULL_FIXTURE);
    const a = buildReportHtml(tmpRoot, template, { now: '2026-01-01', slug: 'demo' });
    const b = buildReportHtml(tmpRoot, template, { now: '2026-12-31', slug: 'demo' });
    expect(a.replace('2026-01-01', 'X')).toBe(b.replace('2026-12-31', 'X'));
  });
});

describe('buildReportHtml — <script>-tag safety', () => {
  test('an artifact containing </script> cannot break out of the data block', async () => {
    await writeFixture(tmpRoot, {
      'REPORT.md': 'malicious </script><script>alert(1)</script> tail',
      'concept-brief.md': '# brief',
    });
    const html = buildReportHtml(tmpRoot, template, { now: 'FIXED' });
    const m = html.match(/<script type="application\/json" id="report-data">([\s\S]*?)<\/script>/);
    expect(m).not.toBeNull();
    const block = m![1];
    expect(block.includes('</script>')).toBe(false);
    // and the content still round-trips
    const overview = JSON.parse(block).artifacts.find((a: any) => a.id === 'overview');
    expect(overview.parts[0].content).toContain('</script>');
  });

  test('an HTML artifact containing </script> stays inside the data block', async () => {
    await writeFixture(tmpRoot, {
      'REPORT.md': '# overview',
      'concept-brief.md': '# brief',
      'direction-a.html': '<!doctype html><body>x</script><script>alert(1)</script></body>',
    });
    const html = buildReportHtml(tmpRoot, template, { now: 'FIXED' });
    const m = html.match(/<script type="application\/json" id="report-data">([\s\S]*?)<\/script>/);
    expect(m).not.toBeNull();
    expect(m![1].includes('</script>')).toBe(false);
    // the screen HTML round-trips intact into its iframe srcdoc
    const proto = JSON.parse(m![1]).artifacts.find((a: any) => a.id === '02');
    const frame = proto.parts.find((p: any) => p.kind === 'iframe');
    expect(frame.srcdoc).toContain('</script>');
  });
});

describe('buildReportHtml — blocked step', () => {
  test('a step listed in .state.json blocked_steps gets status blocked', async () => {
    await writeFixture(tmpRoot, {
      ...FULL_FIXTURE,
      '.state.json': JSON.stringify({ version: 5, blocked_steps: ['07-sitemap-ia'] }),
    });
    const payload = extractPayload(buildReportHtml(tmpRoot, template, { now: 'FIXED' }));
    expect(payload.artifacts.find((a: any) => a.id === '07').status).toBe('blocked');
    // a blocked step does not count toward coverage
    expect(payload.coverage_pct).toBe(Math.round((14 / 15) * 100));
  });

  test('missing/invalid .state.json degrades — nothing blocked', async () => {
    await writeFixture(tmpRoot, FULL_FIXTURE);
    const payload = extractPayload(buildReportHtml(tmpRoot, template, { now: 'FIXED' }));
    expect(payload.artifacts.some((a: any) => a.status === 'blocked')).toBe(false);
  });
});

describe('buildReportHtml — slug/stack metadata', () => {
  test('falls back to .state.json slug + flags.stack when opts omit them', async () => {
    await writeFixture(tmpRoot, {
      ...FULL_FIXTURE,
      '.state.json': JSON.stringify({ version: 5, slug: 'mei-saas', flags: { stack: 'next' } }),
    });
    const html = buildReportHtml(tmpRoot, template, { now: 'FIXED' });
    expect(html.includes('mei-saas')).toBe(true);
    expect(html.includes('stack next')).toBe(true);
  });

  test('explicit opts win over .state.json', async () => {
    await writeFixture(tmpRoot, {
      ...FULL_FIXTURE,
      '.state.json': JSON.stringify({ version: 5, slug: 'from-state', flags: { stack: 'expo' } }),
    });
    const html = buildReportHtml(tmpRoot, template, { now: 'FIXED', slug: 'from-opts', stack: 'next' });
    expect(html.includes('from-opts')).toBe(true);
    expect(html.includes('from-state')).toBe(false);
  });
});

describe('report template — responsive + hash-nav wiring (QA 073)', () => {
  test('generated HTML carries the hashchange listener (QA #2)', async () => {
    await writeFixture(tmpRoot, FULL_FIXTURE);
    const html = buildReportHtml(tmpRoot, template, { now: 'FIXED' });
    expect(html.includes("addEventListener('hashchange'")).toBe(true);
    expect(html.includes('function openArtifact')).toBe(true);
  });

  test('generated HTML carries the mobile drawer (QA #1)', async () => {
    await writeFixture(tmpRoot, FULL_FIXTURE);
    const html = buildReportHtml(tmpRoot, template, { now: 'FIXED' });
    expect(html.includes('@media (max-width: 720px)')).toBe(true);
    expect(html.includes('id="nav-toggle"')).toBe(true);
    expect(html.includes('id="backdrop"')).toBe(true);
    expect(html.includes('class="navtoggle"')).toBe(true);
  });

  test('generated HTML carries the sub-tab rendering wiring', async () => {
    await writeFixture(tmpRoot, FULL_FIXTURE);
    const html = buildReportHtml(tmpRoot, template, { now: 'FIXED' });
    expect(html.includes('function parseHash')).toBe(true);
    expect(html.includes("tabRow.className = 'tabs'")).toBe(true);
    expect(html.includes('.tab.active')).toBe(true);
  });
});
