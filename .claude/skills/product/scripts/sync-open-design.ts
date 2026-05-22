/**
 * sync-open-design.ts — vendored open-design sync engine
 *
 * Ported from anthill's `scripts/sync-open-design.ts` (spec 027) and re-homed in
 * the /product skill (spec 049). Paths resolve from the skill root via
 * `import.meta.url`, invocation is `bun scripts/sync-open-design.ts` (no tsx shebang).
 *
 * Four subcommands:
 *   --check               Read-only: fetch upstream HEAD SHA, diff vs pinned, write daily report
 *   --bump <sha>          Manifest-only: update pinned_sha + history entry
 *   --apply               Write vendored content from tarball at pinned_sha
 *   --verify              Recompute per-path checksums vs MANIFEST.json; exit non-zero on drift
 *
 * SHA fetch strategy: `git ls-remote` (no GitHub API auth, no rate limit).
 * File diff strategy: `gh api repos/nexu-io/open-design/compare/<a>...<b>` when both SHAs
 *   are known — fallback to listing all vendored_paths as "potentially changed" when pinned_sha
 *   is null or gh is unavailable.
 */

import fs from 'node:fs/promises';
import { existsSync, mkdirSync, createWriteStream, readFileSync } from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { promisify } from 'node:util';
import { pipeline } from 'node:stream';

const streamPipeline = promisify(pipeline);

// ── Paths ────────────────────────────────────────────────────────────────────
// Script lives at <skill-root>/scripts/sync-open-design.ts — `..` resolves to <skill-root>.
const SKILL_ROOT = new URL('..', import.meta.url).pathname.replace(/\/$/, '');
const MANIFEST_PATH = path.join(SKILL_ROOT, 'vendor/open-design/MANIFEST.json');
const RUNTIME_DIR = path.join(SKILL_ROOT, 'runtime/od-sync');
const DS_INDEX_PATH = path.join(SKILL_ROOT, 'vendor/open-design/.cache/ds-index.json');
const DESIGN_SYSTEMS_DIR = path.join(SKILL_ROOT, 'design-systems');
const UPSTREAM_URL = 'https://github.com/nexu-io/open-design';
const UPSTREAM_GIT = `${UPSTREAM_URL}.git`;

// ── Types ────────────────────────────────────────────────────────────────────
interface VendoredPath {
  src: string;
  dst: string;
  kind: string;
  recursive?: boolean;
  checksum: string | null;
}

interface HistoryEntry {
  event: 'bump' | 'apply' | 'check';
  sha: string;
  at: string;
  reason: string;
}

interface Manifest {
  $schema: string;
  upstream_url: string;
  pinned_sha: string | null;
  pinned_at: string | null;
  last_check_sha: string | null;
  last_check_at: string | null;
  vendored_paths: VendoredPath[];
  license_attribution: { path: string; license: string; source: string }[];
  history: HistoryEntry[];
}

// ── Helpers ──────────────────────────────────────────────────────────────────

/**
 * Minimum-viable field-presence check (ajv not available as a dependency;
 * required fields per schemas/od-vendor-manifest.schema.json).
 * Exported for direct unit testing.
 */
export function validateManifestShape(obj: unknown): void {
  const REQUIRED_FIELDS: (keyof Manifest)[] = [
    'pinned_sha',
    'last_check_sha',
    'last_check_at',
    'vendored_paths',
  ];
  for (const field of REQUIRED_FIELDS) {
    if (!(field in (obj as Record<string, unknown>))) {
      throw new Error(`manifest schema violation: missing required field ${field}`);
    }
  }
}

async function readManifest(): Promise<Manifest> {
  const raw = await fs.readFile(MANIFEST_PATH, 'utf-8');
  const parsed = JSON.parse(raw) as Manifest;
  validateManifestShape(parsed);
  return parsed;
}

/**
 * Compute a tree-level checksum from the sorted list of per-file checksums.
 * Deterministic regardless of file-walk order.
 * Exported for direct unit testing.
 */
export function computeTreeChecksum(fileChecksums: string[]): string {
  const sorted = [...fileChecksums].sort();
  return `sha256:${crypto.createHash('sha256').update(sorted.join('')).digest('hex')}`;
}

async function writeManifest(m: Manifest): Promise<void> {
  const tmp = MANIFEST_PATH + '.tmp';
  await fs.writeFile(tmp, JSON.stringify(m, null, 2) + '\n', 'utf-8');
  await fs.rename(tmp, MANIFEST_PATH);
}

function nowISO(): string {
  return new Date().toISOString();
}

function todayDateStr(): string {
  return new Date().toISOString().slice(0, 10);
}

function ensureRuntimeDir(): void {
  mkdirSync(RUNTIME_DIR, { recursive: true });
}

/** Fetch upstream HEAD SHA via git ls-remote (no auth, no rate limit). */
export function fetchUpstreamHead(gitUrl = UPSTREAM_GIT): string {
  const result = spawnSync('git', ['ls-remote', gitUrl, 'HEAD'], {
    encoding: 'utf-8',
    timeout: 30_000,
  });
  if (result.status !== 0) {
    throw new Error(`git ls-remote failed: ${result.stderr?.trim() || 'unknown error'}`);
  }
  const line = result.stdout?.trim().split('\n')[0] ?? '';
  const sha = line.split('\t')[0];
  if (!sha || !/^[0-9a-f]{40}$/.test(sha)) {
    throw new Error(`Unexpected git ls-remote output: ${result.stdout}`);
  }
  return sha;
}

/** Validate a SHA exists at upstream. Tries `git ls-remote` first (named refs only),
 * falls back to `gh api repos/.../commits/<sha>` for arbitrary commit SHAs. */
export function shaExistsUpstream(sha: string, gitUrl = UPSTREAM_GIT): boolean {
  const result = spawnSync('git', ['ls-remote', gitUrl, sha], {
    encoding: 'utf-8',
    timeout: 30_000,
  });
  if (result.status === 0 && result.stdout.trim().length > 0) return true;

  const ghResult = spawnSync(
    'gh',
    ['api', `repos/nexu-io/open-design/commits/${sha}`, '--jq', '.sha'],
    { encoding: 'utf-8', timeout: 20_000 },
  );
  return ghResult.status === 0 && ghResult.stdout.trim() === sha;
}

/** SHA-256 hex of a Buffer. */
function sha256hex(buf: Buffer): string {
  return crypto.createHash('sha256').update(buf).digest('hex');
}

/** Provenance comment prefix for a given file extension. */
function provenanceHeader(sha: string, srcPath: string, ext: string): string | null {
  const comment = `vendored from open-design@${sha}:${srcPath} · do not edit`;
  if (['.md', '.html'].includes(ext)) return `<!-- ${comment} -->\n`;
  if (['.ts', '.tsx'].includes(ext)) return `// ${comment}\n`;
  return null; // .json, binaries — checksum-only
}

/**
 * Required H2 section substrings for a DESIGN.md file (case-insensitive).
 *
 * Substring checks cover both the numbered upstream section names
 * (`## 1. Visual Theme & Atmosphere`) and the unnumbered starter-file variants.
 * Original section keywords were too narrow and matched 0/72 files — relaxed to
 * match the real section names emitted by open-design@454e8373.
 */
const REQUIRED_H2_SUBSTRINGS = [
  'color palette',
  'typography',
  'component',
  'layout',
  'visual theme',
];

/** Validate DESIGN.md has the required H2 headings. Returns list of missing sections. */
export function validateDesignMd(content: string): string[] {
  const lower = content.toLowerCase();
  return REQUIRED_H2_SUBSTRINGS.filter((section) => {
    return !lower.split('\n').some(
      (line) => line.startsWith('## ') && line.toLowerCase().includes(section),
    );
  });
}

/** Recursively list all files under `dir`, excluding `.gitkeep` scaffold markers
 * (anthill adds `.gitkeep` to vendor subdirs; they are never part of the upstream
 * tarball and never enter a manifest tree checksum). */
function walkFiles(dir: string): string[] {
  const result = spawnSync('find', [dir, '-type', 'f'], { encoding: 'utf-8', timeout: 30_000 });
  if (result.status !== 0) return [];
  return result.stdout
    .trim()
    .split('\n')
    .filter(Boolean)
    .filter((f) => path.basename(f) !== '.gitkeep');
}

// ── --check ──────────────────────────────────────────────────────────────────

async function cmdCheck(): Promise<void> {
  const manifest = await readManifest();
  ensureRuntimeDir();

  const upstreamHead = fetchUpstreamHead();
  const reportLines: string[] = [
    `# OD Sync Check — ${todayDateStr()}`,
    '',
    `**upstream HEAD:** \`${upstreamHead}\``,
    `**pinned_sha:**    \`${manifest.pinned_sha ?? 'null'}\``,
    '',
  ];

  if (!manifest.pinned_sha) {
    reportLines.push('> No pin yet — run `--bump <sha> --reason "..."` first.');
    reportLines.push('');
    reportLines.push('## Vendored paths');
    reportLines.push('_(none — MANIFEST.vendored_paths is empty)_');
  } else if (manifest.pinned_sha === upstreamHead) {
    reportLines.push('> Pinned SHA matches upstream HEAD — **in sync**.');
  } else {
    reportLines.push(`> Pinned SHA differs from upstream HEAD.`);
    reportLines.push('');

    // Attempt gh compare to list changed files; fall back gracefully when gh is
    // absent or rate-limited (consumers running --check won't reliably have gh).
    let changedFiles: string[] = [];
    const ghResult = spawnSync(
      'gh',
      [
        'api',
        `repos/nexu-io/open-design/compare/${manifest.pinned_sha}...${upstreamHead}`,
        '--jq',
        '.files[].filename',
      ],
      { encoding: 'utf-8', timeout: 20_000 },
    );

    if (ghResult.status === 0 && ghResult.stdout.trim()) {
      changedFiles = ghResult.stdout.trim().split('\n').filter(Boolean);
    } else {
      reportLines.push(
        '> `gh` compare unavailable or rate-limited — listing all vendored paths as potentially changed.',
      );
    }

    const vendoredSrcs = manifest.vendored_paths.map((vp) => vp.src);
    const relevant =
      changedFiles.length > 0
        ? changedFiles.filter((f) => vendoredSrcs.some((src) => f.startsWith(src)))
        : vendoredSrcs;

    reportLines.push('## Files changed in vendored scope');
    if (relevant.length === 0) {
      reportLines.push('_(no changes in vendored paths)_');
    } else {
      relevant.forEach((f) => reportLines.push(`- \`${f}\``));
    }
  }

  reportLines.push('');
  reportLines.push('## Vendored paths');
  if (manifest.vendored_paths.length === 0) {
    reportLines.push('_(none)_');
  } else {
    manifest.vendored_paths.forEach((vp) => {
      reportLines.push(
        `- \`${vp.src}\` → \`${vp.dst}\` (kind: ${vp.kind}, checksum: ${vp.checksum ?? 'not yet applied'})`,
      );
    });
  }

  const reportPath = path.join(RUNTIME_DIR, `${todayDateStr()}.md`);
  await fs.writeFile(reportPath, reportLines.join('\n') + '\n', 'utf-8');
  console.log(`Report written → ${reportPath}`);

  // Mutate manifest: update last_check_sha + last_check_at only
  manifest.last_check_sha = upstreamHead;
  manifest.last_check_at = nowISO();
  await writeManifest(manifest);

  console.log(`last_check_sha updated to ${upstreamHead}`);
}

// ── --bump ───────────────────────────────────────────────────────────────────

async function cmdBump(sha: string, reason: string): Promise<void> {
  if (!/^[0-9a-f]{40}$/.test(sha)) {
    throw new Error(`Invalid SHA format: "${sha}". Must be 40-character lowercase hex.`);
  }
  if (!reason) {
    throw new Error('--reason is required for --bump. Provide a human-readable explanation.');
  }

  console.log(`Validating SHA ${sha} exists upstream…`);
  if (!shaExistsUpstream(sha)) {
    throw new Error(`SHA ${sha} not found upstream at ${UPSTREAM_GIT}`);
  }

  const manifest = await readManifest();
  const at = nowISO();

  manifest.pinned_sha = sha;
  manifest.pinned_at = at;
  manifest.history.push({ event: 'bump', sha, at, reason });

  await writeManifest(manifest);

  console.log(`Bumped pinned_sha → ${sha}`);
  console.log(`Reason: ${reason}`);
  console.log(`Recorded in MANIFEST history.`);
}

// ── --apply ──────────────────────────────────────────────────────────────────

/**
 * Two-phase atomic apply:
 *
 * Phase A: Build all output content in memory + validate ALL DESIGN.md files.
 *          Write to a staging dir. On any schema failure → leave staging, throw,
 *          do not touch live vendor.
 *
 * Phase B: Only reached when Phase A passes with zero failures. Move each staged
 *          file to its final dst via rename. Update manifest checksums.
 *
 * Invariant: live vendor files are never touched until ALL validation passes.
 */
async function cmdApply(): Promise<void> {
  const manifest = await readManifest();

  if (!manifest.pinned_sha) {
    throw new Error('pinned_sha is null — run `--bump <sha> --reason "..."` first.');
  }

  const sha = manifest.pinned_sha;
  ensureRuntimeDir();

  const tarballPath = path.join(RUNTIME_DIR, `tarball-${sha}.tar.gz`);
  const extractDir = path.join(RUNTIME_DIR, `extracted-${sha}`);
  const stagingDir = path.join(RUNTIME_DIR, `staging-${sha}`);
  const archiveRoot = `open-design-${sha}`;

  // ── Idempotence check ────────────────────────────────────────────────────
  let alreadyInSync = manifest.vendored_paths.length > 0;
  for (const vp of manifest.vendored_paths) {
    if (!vp.checksum) { alreadyInSync = false; break; }
    const dstFull = path.join(SKILL_ROOT, vp.dst);
    if (!existsSync(dstFull)) { alreadyInSync = false; break; }
    if (vp.recursive) {
      continue;
    }
    const existing = await fs.readFile(dstFull);
    const existingHash = `sha256:${sha256hex(existing)}`;
    if (existingHash !== vp.checksum) { alreadyInSync = false; break; }
  }

  if (alreadyInSync && manifest.vendored_paths.length > 0) {
    console.log('no-op (already in sync)');
    return;
  }

  // ── Download tarball ─────────────────────────────────────────────────────
  if (!existsSync(tarballPath)) {
    const tarUrl = `${UPSTREAM_URL}/archive/${sha}.tar.gz`;
    console.log(`Downloading ${tarUrl} …`);
    const response = await fetch(tarUrl);
    if (!response.ok) {
      throw new Error(`Failed to download tarball: ${response.status} ${response.statusText}`);
    }
    const writer = createWriteStream(tarballPath);
    await streamPipeline(response.body as unknown as NodeJS.ReadableStream, writer);
    console.log(`Tarball saved → ${tarballPath}`);
  } else {
    console.log(`Reusing cached tarball at ${tarballPath}`);
  }

  // ── Extract tarball ──────────────────────────────────────────────────────
  mkdirSync(extractDir, { recursive: true });
  const tarResult = spawnSync('tar', ['-xzf', tarballPath, '-C', extractDir], {
    encoding: 'utf-8',
    timeout: 60_000,
  });
  if (tarResult.status !== 0) {
    throw new Error(`tar extraction failed: ${tarResult.stderr?.trim()}`);
  }
  console.log(`Extracted to ${extractDir}`);

  // ── Phase A: stage + validate ALL files (no live dst writes yet) ─────────
  const at = nowISO();
  const report: {
    added: string[];
    updated: string[];
    removed: string[];
    schemaFailures: string[];
  } = { added: [], updated: [], removed: [], schemaFailures: [] };

  const staged: Array<{ dstFull: string; stagedPath: string; checksum: string; vp: VendoredPath }> = [];
  const updatedPaths: VendoredPath[] = [];

  mkdirSync(stagingDir, { recursive: true });
  console.log(`Staging to ${stagingDir} …`);

  for (const vp of manifest.vendored_paths) {
    const srcFull = path.join(extractDir, archiveRoot, vp.src);
    const dstFull = path.join(SKILL_ROOT, vp.dst);

    if (vp.recursive) {
      const walkResult = spawnSync('find', [srcFull, '-type', 'f'], {
        encoding: 'utf-8',
        timeout: 10_000,
      });
      if (walkResult.status !== 0 || !existsSync(srcFull)) {
        report.removed.push(vp.src);
        updatedPaths.push(vp);
        continue;
      }

      const files = walkResult.stdout.trim().split('\n').filter(Boolean);
      for (const fileSrc of files) {
        const relPath = path.relative(path.join(extractDir, archiveRoot), fileSrc);
        const fileDst = path.join(SKILL_ROOT, vp.dst, path.relative(vp.src, relPath));

        const entry = await stageFile({
          fileSrc,
          fileDst,
          sha,
          srcPath: relPath,
          stagingDir,
          report,
          vp,
        });
        if (entry) staged.push(entry);
      }
      updatedPaths.push({ ...vp });
    } else {
      if (!existsSync(srcFull)) {
        report.removed.push(vp.src);
        updatedPaths.push(vp);
        continue;
      }
      const entry = await stageFile({
        fileSrc: srcFull,
        fileDst: dstFull,
        sha,
        srcPath: vp.src,
        stagingDir,
        report,
        vp,
      });
      if (entry) staged.push(entry);
    }
  }

  if (report.schemaFailures.length > 0) {
    const failures = report.schemaFailures.join(', ');
    throw new Error(
      `DESIGN.md schema validation failed for: ${failures}.\n` +
      `Staging preserved at ${stagingDir} for inspection. Manifest not updated.`,
    );
  }

  // ── Phase B: atomic move staging → final dst ─────────────────────────────
  console.log(`Validation passed (${staged.length} files). Moving staging → dst …`);
  for (const { dstFull, stagedPath, checksum, vp } of staged) {
    const existed = existsSync(dstFull);
    if (existed) {
      report.updated.push(dstFull);
    } else {
      report.added.push(dstFull);
    }

    mkdirSync(path.dirname(dstFull), { recursive: true });
    await fs.rename(stagedPath, dstFull);

    vp.checksum = checksum;
  }

  // For tree (recursive) entries, replace the last-file checksum with a
  // deterministic tree digest over all per-file checksums.
  const treeVps = new Set(staged.filter((e) => e.vp.recursive).map((e) => e.vp));
  for (const treeVp of treeVps) {
    const fileChecksums = staged.filter((e) => e.vp === treeVp).map((e) => e.checksum);
    treeVp.checksum = computeTreeChecksum(fileChecksums);
  }

  await fs.rm(stagingDir, { recursive: true, force: true });

  // ── Atomic manifest update ───────────────────────────────────────────────
  manifest.history.push({ event: 'apply', sha, at, reason: 'auto-apply' });
  for (const up of updatedPaths) {
    const vp = manifest.vendored_paths.find((v) => v.src === up.src);
    if (vp && vp.checksum) up.checksum = vp.checksum;
  }

  await writeManifest(manifest);

  // ── Regenerate the DS index (part of the consumed vendor surface) ────────
  await generateDsIndex(sha);

  // ── Write apply report ───────────────────────────────────────────────────
  const reportPath = path.join(RUNTIME_DIR, `apply-${sha.slice(0, 12)}.md`);
  const reportLines = [
    `# OD Sync Apply — ${sha.slice(0, 12)}`,
    '',
    `**sha:** \`${sha}\``,
    `**at:** ${at}`,
    '',
    `## Added (${report.added.length})`,
    ...report.added.map((f) => `- \`${f}\``),
    '',
    `## Updated (${report.updated.length})`,
    ...report.updated.map((f) => `- \`${f}\``),
    '',
    `## Removed from tarball (${report.removed.length})`,
    ...report.removed.map((f) => `- \`${f}\``),
    '',
  ];
  await fs.writeFile(reportPath, reportLines.join('\n') + '\n', 'utf-8');
  console.log(`Apply report → ${reportPath}`);
  console.log(
    `Done: ${report.added.length} added, ${report.updated.length} updated, ${report.removed.length} removed.`,
  );
}

interface StageFileArgs {
  fileSrc: string;
  fileDst: string;
  sha: string;
  srcPath: string;
  stagingDir: string;
  report: { added: string[]; updated: string[]; removed: string[]; schemaFailures: string[] };
  vp: VendoredPath;
}

interface StageFileResult {
  dstFull: string;
  stagedPath: string;
  checksum: string;
  vp: VendoredPath;
}

/**
 * Phase A worker: validate + build output bytes + write to stagingDir.
 * Does NOT touch the final dst. Returns a StageFileResult for Phase B,
 * or null if schema validation failed (failure recorded in report.schemaFailures).
 */
async function stageFile({
  fileSrc,
  fileDst,
  sha,
  srcPath,
  stagingDir,
  report,
  vp,
}: StageFileArgs): Promise<StageFileResult | null> {
  const ext = path.extname(fileSrc).toLowerCase();
  const rawBytes = await fs.readFile(fileSrc);

  const isDesignMd =
    (vp.kind === 'design-system-tree' || srcPath.endsWith('DESIGN.md')) &&
    path.basename(fileSrc) === 'DESIGN.md';

  if (isDesignMd) {
    const content = rawBytes.toString('utf-8');
    const missing = validateDesignMd(content);
    if (missing.length > 0) {
      report.schemaFailures.push(`${srcPath} (missing H2: ${missing.join(', ')})`);
      return null;
    }
  }

  const header = provenanceHeader(sha, srcPath, ext);
  const outBytes = header ? Buffer.concat([Buffer.from(header, 'utf-8'), rawBytes]) : rawBytes;

  const checksum = `sha256:${sha256hex(outBytes)}`;

  const relToDst = path.relative(SKILL_ROOT, fileDst);
  const stagedPath = path.join(stagingDir, relToDst);
  mkdirSync(path.dirname(stagedPath), { recursive: true });
  await fs.writeFile(stagedPath, outBytes);

  return { dstFull: fileDst, stagedPath, checksum, vp };
}

// ── --verify ─────────────────────────────────────────────────────────────────

export interface VerifyResult {
  dst: string;
  ok: boolean;
  expected: string | null;
  actual: string | null;
  note?: string;
}

/**
 * Recompute the on-disk checksum for every `vendored_paths[]` entry and compare
 * it to the value recorded in the manifest. Pure (no process.exit) so tests can
 * drive it against a fixture tree. Exported for direct unit testing.
 *
 * Tree entries are hashed exactly the way `--apply` produced them: walk the dst
 * dir (excluding `.gitkeep`), sha256 each file *including* its provenance header,
 * then `computeTreeChecksum` over the sorted per-file digests.
 */
export function verifyManifest(manifest: Manifest, root: string): VerifyResult[] {
  return manifest.vendored_paths.map((vp) => {
    const dstFull = path.join(root, vp.dst);
    if (!existsSync(dstFull)) {
      return { dst: vp.dst, ok: false, expected: vp.checksum, actual: null, note: 'missing on disk' };
    }
    let actual: string;
    if (vp.recursive) {
      const checksums = walkFiles(dstFull).map((f) => `sha256:${sha256hex(readFileSync(f))}`);
      actual = computeTreeChecksum(checksums);
    } else {
      actual = `sha256:${sha256hex(readFileSync(dstFull))}`;
    }
    return { dst: vp.dst, ok: actual === vp.checksum, expected: vp.checksum, actual };
  });
}

async function cmdVerify(): Promise<void> {
  const manifest = await readManifest();
  const results = verifyManifest(manifest, SKILL_ROOT);
  const mismatches = results.filter((r) => !r.ok);

  if (mismatches.length > 0) {
    console.error(`OD vendor verify FAILED — ${mismatches.length}/${results.length} path(s) drifted:`);
    for (const m of mismatches) {
      console.error(`  - ${m.dst}`);
      console.error(`      expected: ${m.expected ?? '(none)'}`);
      console.error(`      actual:   ${m.actual ?? '(missing)'}${m.note ? ` (${m.note})` : ''}`);
    }
    console.error('');
    console.error('Vendored content drifted from MANIFEST.json. Re-run');
    console.error('  bun scripts/sync-open-design.ts --apply');
    console.error('from the pinned SHA to restore, or revert the hand-edit.');
    process.exit(1);
  }

  console.log(`OD vendor verify OK — ${results.length} path(s) match MANIFEST.json`);
}

// ── DS index generation ──────────────────────────────────────────────────────

interface DsIndexEntry {
  name: string;
  mood: string;
  palette_summary: string[];
}

/**
 * Generate `vendor/open-design/.cache/ds-index.json` — a one-line-per-system
 * digest the MCP `product_design_systems_index` tool returns without walking the
 * filesystem per call. Called at the end of `--apply`; also runnable standalone
 * via `--gen-ds-index` for the spec-027 bootstrap.
 *
 * Per system: `name` (dir name), `mood` (the non-Category `>` blockquote line
 * under the title, or the `#` title as fallback), `palette_summary` (first 6
 * unique 6-hex colors found in the file).
 */
export async function generateDsIndex(pinnedSha: string | null): Promise<number> {
  const entries: DsIndexEntry[] = [];
  const dirents = await fs.readdir(DESIGN_SYSTEMS_DIR, { withFileTypes: true });

  for (const d of dirents.sort((a, b) => a.name.localeCompare(b.name))) {
    if (!d.isDirectory()) continue;
    const designMd = path.join(DESIGN_SYSTEMS_DIR, d.name, 'DESIGN.md');
    if (!existsSync(designMd)) continue;

    const content = await fs.readFile(designMd, 'utf-8');
    const lines = content.split('\n');

    let mood = '';
    for (const line of lines) {
      const t = line.trim();
      if (t.startsWith('>') && !/^>\s*category:/i.test(t)) {
        mood = t.replace(/^>\s*/, '').trim();
        break;
      }
    }
    if (!mood) {
      const title = lines.find((l) => l.trim().startsWith('# '));
      mood = title ? title.replace(/^#\s*/, '').trim() : d.name;
    }

    const hexes = content.match(/#[0-9a-fA-F]{6}\b/g) ?? [];
    const palette_summary = [...new Set(hexes.map((h) => h.toLowerCase()))].slice(0, 6);

    entries.push({ name: d.name, mood, palette_summary });
  }

  const index = {
    generated_at: nowISO(),
    pinned_sha: pinnedSha,
    count: entries.length,
    systems: entries,
  };

  mkdirSync(path.dirname(DS_INDEX_PATH), { recursive: true });
  await fs.writeFile(DS_INDEX_PATH, JSON.stringify(index, null, 2) + '\n', 'utf-8');
  console.log(`DS index written → ${DS_INDEX_PATH} (${entries.length} systems)`);
  return entries.length;
}

// ── CLI entry point ──────────────────────────────────────────────────────────

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const cmd = args[0];

  try {
    if (cmd === '--check') {
      await cmdCheck();
    } else if (cmd === '--bump') {
      const sha = args[1];
      if (!sha) throw new Error('Usage: --bump <sha> --reason "..."');
      const reasonIdx = args.indexOf('--reason');
      const reason = reasonIdx !== -1 ? args[reasonIdx + 1] : '';
      await cmdBump(sha, reason);
    } else if (cmd === '--apply') {
      await cmdApply();
    } else if (cmd === '--verify') {
      await cmdVerify();
    } else if (cmd === '--gen-ds-index') {
      const manifest = await readManifest();
      await generateDsIndex(manifest.pinned_sha);
    } else {
      console.error(`Usage:
  bun scripts/sync-open-design.ts --check
  bun scripts/sync-open-design.ts --bump <sha> --reason "..."
  bun scripts/sync-open-design.ts --apply
  bun scripts/sync-open-design.ts --verify
  bun scripts/sync-open-design.ts --gen-ds-index`);
      process.exit(1);
    }
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error(`Error: ${msg}`);
    process.exit(1);
  }
}

// Only run as CLI entrypoint — skip when imported by the test runner.
const isMain =
  process.argv[1] &&
  (process.argv[1].endsWith('sync-open-design.ts') ||
    process.argv[1].endsWith('sync-open-design.js'));

if (isMain) {
  main();
}
