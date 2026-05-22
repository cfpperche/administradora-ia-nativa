#!/usr/bin/env node
// Adapted from agent-core (Apache-2.0): https://github.com/cfpperche/agent-core
//
// Presence statusline — emits 2 lines for CC's statusLine.command.
// Bound to: settings.json .statusLine.command (CC platform reads on every status update).
//
// Input: JSON via stdin (CC payload — model, session_id, workspace, cost, context_window, rate_limits).
// Output: 2 lines to stdout, ANSI-colored. Always exits 0 (statusline failure must never break CC's status bar).
//
// Layout:
//   line1: <model> · <effort?> · <agent?> · <wt?> · <project> · <branch> · <bar> <%> <eta?> · <5h?> · <7d?> · <warning?>
//   line2: $<cost> · ↑↓<turn-tokens> · $<cost-per-min?> · <duration?> · +<add>/-<rem>? · <lines/$?> · <cache-hit?>
//
// State written under <projectDir>/.claude/.runtime/statusline/:
//   - branch.json — git branch cache (5s TTL)
//   - tokens/<sessionId>.json — input/output tokens snapshot for per-turn delta
//   - context-markers/<sessionId>-current — current ctx usage marker
//
// Vendor-agnostic: no anthill-specific paths (unleash/delegation/pipeline excluded by design).
// Performance budget: <50ms steady state (no network, branch cached, jq-free).

import { execSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";

// ── Parse stdin ─────────────────────────────────────────────────────────────
const input = readFileSync(0, "utf8");

let data;
try {
	data = JSON.parse(input);
} catch {
	process.stdout.write("ctx: ---%");
	process.exit(0);
}

// ── Extract payload fields ─────────────────────────────────────────────────
const remaining = data.context_window?.remaining_percentage;
const usedRaw = data.context_window?.used_percentage ?? 0;
const used = Math.round(usedRaw);
const modelRaw = data.model?.display_name ?? data.model?.id ?? data.model ?? "?";
const modelId = data.model?.id ?? "";

// Compact "Family Version Context" — e.g. "Opus 4.7 1M", "Sonnet 4.6 200K"
const model = (() => {
	if (typeof modelRaw !== "string") return "?";
	const m = modelRaw.match(/(Opus|Sonnet|Haiku)\s*(\d+(?:\.\d+)?)/i);
	if (!m) return modelRaw;
	const family = m[1][0].toUpperCase() + m[1].slice(1).toLowerCase();
	const ver = m[2];
	const ctx = /\[1m\]|1M/i.test(modelId) || /1M/i.test(modelRaw) ? "1M" : "200K";
	return `${family} ${ver} ${ctx}`;
})();

// Thinking / effort badges from env or user settings
let userSettings = {};
try {
	userSettings = JSON.parse(readFileSync(`${process.env.HOME}/.claude/settings.json`, "utf8"));
} catch {}
const thinkDisabled =
	process.env.CLAUDE_CODE_DISABLE_THINKING === "1" ||
	process.env.CLAUDE_CODE_DISABLE_THINKING === "true" ||
	userSettings.disableThinking === true;
const thinkTokensRaw = process.env.MAX_THINKING_TOKENS ?? userSettings.maxThinkingTokens;
const thinkTokens = thinkTokensRaw ? Number(thinkTokensRaw) : null;
const fmtThinkBudget = (n) => (n >= 1000 ? `${Math.round(n / 1000)}k` : `${n}`);
const effortLevel = process.env.CLAUDE_CODE_EFFORT_LEVEL ?? userSettings.effortLevel;
const thinkBadge = thinkDisabled
	? "think:off"
	: thinkTokens
		? `think:${fmtThinkBudget(thinkTokens)}`
		: null;
const effortBadge = effortLevel ? effortLevel : null;

const cost = data.cost?.total_cost_usd;
const projectDir = data.workspace?.project_dir ?? data.workspace?.current_dir ?? data.cwd ?? "";
const project = projectDir.split("/").filter(Boolean).pop() || "?";
const sessionId = data.session_id ?? "unknown";
const linesAdded = data.cost?.total_lines_added;
const linesRemoved = data.cost?.total_lines_removed;
const durationMs = data.cost?.total_duration_ms;
const worktree = data.worktree?.name;
const agent = data.agent?.name;
const fiveHourUsed = data.rate_limits?.five_hour?.used_percentage;
const fiveHourResets = data.rate_limits?.five_hour?.resets_at;
const sevenDayUsed = data.rate_limits?.seven_day?.used_percentage;
const sevenDayResets = data.rate_limits?.seven_day?.resets_at;

// ── Git branch (cached for 5s to avoid spawning git on every update) ─────
const STATE_DIR = projectDir ? `${projectDir}/.claude/.runtime/statusline` : null;
const BRANCH_CACHE = STATE_DIR ? `${STATE_DIR}/branch.json` : null;
try {
	if (STATE_DIR && !existsSync(STATE_DIR)) mkdirSync(STATE_DIR, { recursive: true });
} catch {}
const BRANCH_TTL = 5000;
let branch = "?";
try {
	let useCache = false;
	if (BRANCH_CACHE && existsSync(BRANCH_CACHE)) {
		const cached = JSON.parse(readFileSync(BRANCH_CACHE, "utf8"));
		if (cached.dir === projectDir && Date.now() - cached.ts < BRANCH_TTL) {
			branch = cached.branch;
			useCache = true;
		}
	}
	if (!useCache) {
		branch = execSync("git rev-parse --abbrev-ref HEAD", {
			cwd: projectDir || undefined,
			encoding: "utf8",
			timeout: 1000,
			stdio: ["pipe", "pipe", "pipe"],
		}).trim();
		if (BRANCH_CACHE) {
			writeFileSync(BRANCH_CACHE, JSON.stringify({ dir: projectDir, branch, ts: Date.now() }));
		}
	}
} catch {}

// ── Helpers ────────────────────────────────────────────────────────────────
const formatDuration = (ms) => {
	if (ms == null) return null;
	const s = Math.floor(ms / 1000);
	if (s < 60) return `${s}s`;
	const m = Math.floor(s / 60);
	if (m < 60) return `${m}m${s % 60}s`;
	const h = Math.floor(m / 60);
	return `${h}h${m % 60}m`;
};

const formatResetIn = (epochSec) => {
	if (epochSec == null) return null;
	const ms = epochSec * 1000 - Date.now();
	if (ms <= 0) return "now";
	return formatDuration(ms);
};

// ── Derived metrics ────────────────────────────────────────────────────────
const durationMin = durationMs != null && durationMs > 0 ? durationMs / 60000 : null;
const costPerMin =
	cost != null && durationMin != null && durationMin > 0.5 ? cost / durationMin : null;
const totalLines = (linesAdded ?? 0) + (linesRemoved ?? 0);
const linesPerDollar = cost > 0 && totalLines > 0 ? totalLines / cost : null;
const inputTokens = data.context_window?.total_input_tokens ?? 0;
const outputTokens = data.context_window?.total_output_tokens ?? 0;

// Per-turn token delta (last message in/out, includes subagents since totals are session-wide)
const TOK_DIR = STATE_DIR ? `${STATE_DIR}/tokens` : null;
let turnIn = 0;
let turnOut = 0;
try {
	if (TOK_DIR) {
		if (!existsSync(TOK_DIR)) mkdirSync(TOK_DIR, { recursive: true });
		const tokFile = `${TOK_DIR}/${sessionId}.json`;
		let prev = { in: 0, out: 0 };
		if (existsSync(tokFile)) {
			try {
				prev = JSON.parse(readFileSync(tokFile, "utf8"));
			} catch {}
		}
		turnIn = Math.max(0, inputTokens - (prev.in ?? 0));
		turnOut = Math.max(0, outputTokens - (prev.out ?? 0));
		writeFileSync(tokFile, JSON.stringify({ in: inputTokens, out: outputTokens }));
	}
} catch {}
const fmtTok = (n) => (n >= 1000 ? `${(n / 1000).toFixed(1)}k` : `${n}`);

// Cache hit ratio: high = saving money, low = recreating cache each turn
const cacheRead = data.context_window?.current_usage?.cache_read_input_tokens ?? 0;
const cacheCreation = data.context_window?.current_usage?.cache_creation_input_tokens ?? 0;
const cacheTotal = cacheRead + cacheCreation;
const cacheHitRatio = cacheTotal > 0 ? cacheRead / cacheTotal : null;

// Context ETA: weighted estimate — recent burn rate matters more than overall average
const burnRate = used > 0 && durationMin != null && durationMin > 0.5 ? used / durationMin : null;
const ctxEta =
	burnRate != null && remaining > 0 ? remaining / (used > 50 ? burnRate * 1.5 : burnRate) : null;

// ── ANSI / progress bar ────────────────────────────────────────────────────
const barWidth = 20;
const filled = Math.round((usedRaw / 100) * barWidth);
const empty = barWidth - filled;
const ctxColor = remaining > 50 ? "\x1b[32m" : remaining > 25 ? "\x1b[33m" : "\x1b[31m";
const green = "\x1b[32m";
const red = "\x1b[31m";
const cyan = "\x1b[36m";
const magenta = "\x1b[35m";
const yellow = "\x1b[33m";
const dim = "\x1b[2m";
const bold = "\x1b[1m";
const reset = "\x1b[0m";
const bar = `${ctxColor}${"█".repeat(filled)}${dim}${"░".repeat(empty)}${reset}`;
const sep = `${dim} │ ${reset}`;

// ── Render ─────────────────────────────────────────────────────────────────
const line1 = [
	`${bold}${model}${reset}`,
	thinkBadge ? `${cyan}${thinkBadge}${reset}` : null,
	effortBadge ? `${cyan}${effortBadge}${reset}` : null,
	agent ? `${magenta}${agent}${reset}` : null,
	worktree ? `${cyan}wt:${worktree}${reset}` : null,
	`${dim}${project}${reset}`,
	`${dim}${branch}${reset}`,
	`${bar} ${ctxColor}${used}%${reset}`,
	ctxEta != null ? `${ctxColor}~${formatDuration(ctxEta * 60000)} left${reset}` : null,
	fiveHourUsed != null
		? (() => {
				const c = fiveHourUsed >= 80 ? red : fiveHourUsed >= 50 ? yellow : green;
				const r = fiveHourUsed > 70 ? ` ~${formatResetIn(fiveHourResets)}` : "";
				return `${c}5h:${Math.round(fiveHourUsed)}%${r}${reset}`;
			})()
		: null,
	sevenDayUsed != null
		? (() => {
				const c = sevenDayUsed >= 80 ? red : sevenDayUsed >= 50 ? yellow : green;
				const r = sevenDayUsed > 70 ? ` ~${formatResetIn(sevenDayResets)}` : "";
				return `${c}7d:${Math.round(sevenDayUsed)}%${r}${reset}`;
			})()
		: null,
	remaining != null && remaining <= 25 ? `${red}${bold} COMPACT SOON${reset}` : null,
	remaining != null && remaining <= 10 ? `${red}${bold} CRITICAL${reset}` : null,
].filter(Boolean);

const line2 = [
	cost != null ? `${dim}$${cost.toFixed(2)}${reset}` : null,
	turnIn > 0 || turnOut > 0 ? `${cyan}↑${fmtTok(turnIn)} ↓${fmtTok(turnOut)}${reset}` : null,
	costPerMin != null ? `${yellow}$${costPerMin.toFixed(2)}/min${reset}` : null,
	durationMs != null ? `${dim}${formatDuration(durationMs)}${reset}` : null,
	linesAdded != null || linesRemoved != null
		? `${green}+${linesAdded ?? 0}${reset} ${red}-${linesRemoved ?? 0}${reset}`
		: null,
	linesPerDollar != null ? `${cyan}${Math.round(linesPerDollar)} lines/$${reset}` : null,
	cacheHitRatio != null
		? `${cacheHitRatio > 0.5 ? green : yellow}cache ${Math.round(cacheHitRatio * 100)}%${reset}`
		: null,
].filter(Boolean);

process.stdout.write(line1.join(sep));
if (line2.length > 0) process.stdout.write("\n" + line2.join(sep));

// ── Write current context usage marker (readable by skills/agents) ───────
try {
	if (STATE_DIR) {
		const markerDir = `${STATE_DIR}/context-markers`;
		if (!existsSync(markerDir)) mkdirSync(markerDir, { recursive: true });
		writeFileSync(
			`${markerDir}/${sessionId}-current`,
			JSON.stringify({ used, remaining, ts: Date.now() }),
		);
	}
} catch {}
