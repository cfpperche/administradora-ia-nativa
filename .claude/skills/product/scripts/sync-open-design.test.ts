/**
 * Unit tests for the OD vendor sync engine (spec 027, scripts/sync-open-design.ts).
 *
 * Covers the pure, exported pieces — `computeTreeChecksum`, `validateManifestShape`,
 * `validateDesignMd` — plus `verifyManifest` drift detection against a fixture tree.
 * The network-bound subcommands (`--check`/`--bump`/`--apply`) are not exercised
 * here; `--verify` is the prepublishOnly gate and is the one that must be airtight.
 */

import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { mkdtemp, mkdir, rm, writeFile, appendFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createHash } from "node:crypto";
import {
  computeTreeChecksum,
  validateManifestShape,
  validateDesignMd,
  verifyManifest,
} from "./sync-open-design.js";

let tmpRoot: string;

beforeEach(async () => {
  tmpRoot = await mkdtemp(join(tmpdir(), "od-sync-test-"));
});

afterEach(async () => {
  await rm(tmpRoot, { recursive: true, force: true });
});

function sha256(buf: Buffer | string): string {
  return `sha256:${createHash("sha256").update(buf).digest("hex")}`;
}

describe("computeTreeChecksum", () => {
  test("is order-independent (sorts before hashing)", () => {
    const a = computeTreeChecksum(["sha256:ccc", "sha256:aaa", "sha256:bbb"]);
    const b = computeTreeChecksum(["sha256:aaa", "sha256:bbb", "sha256:ccc"]);
    expect(a).toBe(b);
  });

  test("changes when any per-file checksum changes", () => {
    const base = computeTreeChecksum(["sha256:aaa", "sha256:bbb"]);
    const drifted = computeTreeChecksum(["sha256:aaa", "sha256:bbX"]);
    expect(drifted).not.toBe(base);
  });

  test("returns a sha256:-prefixed digest", () => {
    expect(computeTreeChecksum(["sha256:aaa"])).toMatch(/^sha256:[0-9a-f]{64}$/);
  });
});

describe("validateManifestShape", () => {
  test("accepts a manifest carrying the required fields", () => {
    expect(() =>
      validateManifestShape({
        pinned_sha: null,
        last_check_sha: null,
        last_check_at: null,
        vendored_paths: [],
      }),
    ).not.toThrow();
  });

  test("throws naming the first missing required field", () => {
    expect(() => validateManifestShape({ pinned_sha: "x" })).toThrow(
      /missing required field/,
    );
  });
});

describe("validateDesignMd", () => {
  const good = [
    "## 1. Visual Theme & Atmosphere",
    "## 2. Color Palette & Roles",
    "## 3. Typography Rules",
    "## 4. Component Stylings",
    "## 5. Layout Principles",
  ].join("\n");

  test("returns an empty array when all required H2 substrings are present", () => {
    expect(validateDesignMd(good)).toEqual([]);
  });

  test("reports the missing sections", () => {
    const bad = "## Visual Theme\n## Typography Rules";
    const missing = validateDesignMd(bad);
    expect(missing).toContain("color palette");
    expect(missing).toContain("component");
    expect(missing).toContain("layout");
    expect(missing).not.toContain("typography");
  });

  test("matches case-insensitively and only on ## headings", () => {
    // 'color palette' appears in body prose but not as an H2 — still missing.
    const bodyOnly = good.replace("## 2. Color Palette & Roles", "Some color palette prose.");
    expect(validateDesignMd(bodyOnly)).toContain("color palette");
  });
});

describe("verifyManifest — drift detection", () => {
  /** Stage a fixture vendor tree: one single-file entry + one recursive tree. */
  async function stageFixture() {
    const singleRel = "vendor/open-design/prompts/system.ts";
    const singlePath = join(tmpRoot, singleRel);
    await mkdir(join(tmpRoot, "vendor/open-design/prompts"), { recursive: true });
    const singleContent = "// vendored\nexport const x = 1;\n";
    await writeFile(singlePath, singleContent);

    const treeDir = join(tmpRoot, "design-systems");
    await mkdir(join(treeDir, "foo"), { recursive: true });
    await mkdir(join(treeDir, "bar"), { recursive: true });
    const fooContent = "# foo DESIGN\n";
    const barContent = "# bar DESIGN\n";
    await writeFile(join(treeDir, "foo", "DESIGN.md"), fooContent);
    await writeFile(join(treeDir, "bar", "DESIGN.md"), barContent);
    // a .gitkeep must be ignored by the walk
    await writeFile(join(treeDir, ".gitkeep"), "");

    const treeChecksum = computeTreeChecksum([sha256(fooContent), sha256(barContent)]);

    const manifest = {
      $schema: "x",
      upstream_url: "https://example.com",
      pinned_sha: null,
      pinned_at: null,
      last_check_sha: null,
      last_check_at: null,
      license_attribution: [],
      history: [],
      vendored_paths: [
        { src: "x", dst: singleRel, kind: "prompt-source", checksum: sha256(singleContent) },
        { src: "y", dst: "design-systems/", kind: "design-system-tree", recursive: true, checksum: treeChecksum },
      ],
    };
    return { manifest, singlePath, treeDir };
  }

  test("reports ok for every path of an untouched tree", async () => {
    const { manifest } = await stageFixture();
    const results = verifyManifest(manifest as never, tmpRoot);
    expect(results).toHaveLength(2);
    expect(results.every((r) => r.ok)).toBe(true);
  });

  test("detects a hand-edit to a single-file entry", async () => {
    const { manifest, singlePath } = await stageFixture();
    await appendFile(singlePath, "// tampered\n");
    const results = verifyManifest(manifest as never, tmpRoot);
    const single = results.find((r) => r.dst.endsWith("system.ts"))!;
    expect(single.ok).toBe(false);
    expect(single.actual).not.toBe(single.expected);
  });

  test("detects a hand-edit inside a recursive tree", async () => {
    const { manifest, treeDir } = await stageFixture();
    await appendFile(join(treeDir, "foo", "DESIGN.md"), "tampered");
    const results = verifyManifest(manifest as never, tmpRoot);
    const tree = results.find((r) => r.dst === "design-systems/")!;
    expect(tree.ok).toBe(false);
  });

  test("flags a vendored path that is missing on disk", async () => {
    const { manifest } = await stageFixture();
    await rm(join(tmpRoot, "vendor/open-design/prompts/system.ts"));
    const results = verifyManifest(manifest as never, tmpRoot);
    const single = results.find((r) => r.dst.endsWith("system.ts"))!;
    expect(single.ok).toBe(false);
    expect(single.note).toMatch(/missing/);
  });
});
