// Runs one task with the Claude Agent SDK inside the `agent` workflow
// (.github/workflows/agent.yml). The workflow, not the agent, pushes the
// branch and opens the pull request; this script only drives the session and
// records its outcome. Option names follow the SDK's own type definitions
// (sdk.d.ts of @anthropic-ai/claude-agent-sdk, the version pinned in the
// workflow).
import { appendFileSync, writeFileSync } from 'node:fs';
import { query } from '@anthropic-ai/claude-agent-sdk';

const MAX_BUDGET_USD = 50;
const MAX_TURNS = 400;
const REPORT_LIMIT = 50000;

const env = process.env;
const task = (env.AGENT_TASK ?? '').trim();
const branch = env.AGENT_BRANCH ?? '';
const base = env.AGENT_BASE || 'main';
const agent = env.AGENT_NAME && env.AGENT_NAME !== 'none' ? env.AGENT_NAME : undefined;
const model = env.AGENT_MODEL;
const effort = env.AGENT_EFFORT;
const budget = Number(env.AGENT_BUDGET_USD);
const outcomeFile = env.AGENT_OUTCOME_FILE;

function fail(message) {
  console.error(`agent: ${message}`);
  if (outcomeFile) {
    writeFileSync(outcomeFile, JSON.stringify({ subtype: 'not_started', is_error: true, errors: [message] }));
  }
  process.exit(1);
}

if (!task) fail('the task is empty');
if (!env.ANTHROPIC_API_KEY) fail('the API key secret for the chosen slot is not set');
if (!Number.isFinite(budget) || budget <= 0 || budget > MAX_BUDGET_USD) {
  fail(`budget_usd must be a number above 0 and at most ${MAX_BUDGET_USD}`);
}

// Rules for an unattended run. They sit in the prompt rather than in the
// system prompt so that they reach the model whether or not a project agent
// replaces the main thread's system prompt.
const rules = `You are running unattended in GitHub Actions, as the lead for one task of this repository.
The checkout is on the branch \`${branch}\`, which starts from \`${base}\`; the pull request will go to \`${base}\`. CLAUDE.md, the project agents in .claude/agents and the skills in .claude/skills are loaded; follow CLAUDE.md and docs/WORKFLOW.md in full, with these differences for this run:

1. Nobody can answer you during the run. A decision that CLAUDE.md gives to the owner (scope, content, sources, identity gaps, anything irreversible) is not guessed: leave that part undone and write the question in your final report, in Arabic, recommended option first, marked «(موصى به)».
2. Edit only the files the task allows. Do not edit docs/PROJECT_STATUS.md or docs/DECISIONS.md unless the task says so: other tasks run at the same time on other branches. Put what those files should record in your final report instead.
3. Commit your work on the current branch with Conventional Commits in English that name the requirement ID or milestone. Do not push, open pull requests, change remotes or call the GitHub API: the workflow pushes your commits and opens the pull request when you finish.
4. Before your last commit, run \`dart format .\`, \`flutter analyze\` and \`flutter test --exclude-tags golden test tools/gen/test\` (add \`spike\` when that folder exists), fix what fails, and run them again. Never weaken or skip a test. Never create or commit .png files: golden images are made only by the CI \`goldens\` task (D-056); a new golden test without its image is expected.
5. Never print, write or commit secrets or environment variables, and do not run \`env\`, \`printenv\` or \`set\`.
6. You may delegate to the agents in .claude/agents with the Task tool; they work in this same checkout.
7. End with a final report in English: what was done, files changed, the checks you ran with their exact results, what is unfinished and why, questions for the owner (in Arabic), and what docs/PROJECT_STATUS.md and docs/DECISIONS.md should record.`;

const prompt = `${rules}\n\n## The task\n\n${task}`;

const options = {
  cwd: env.GITHUB_WORKSPACE ?? process.cwd(),
  settingSources: ['project'],
  systemPrompt: { type: 'preset', preset: 'claude_code' },
  ...(agent ? { agent } : {}),
  ...(model ? { model } : {}),
  ...(effort ? { effort } : {}),
  maxBudgetUsd: budget,
  maxTurns: MAX_TURNS,
  permissionMode: 'bypassPermissions',
  allowDangerouslySkipPermissions: true,
  // The project's .mcp.json names the Dart and Flutter MCP server; it is
  // passed here explicitly so that it starts without an approval prompt.
  strictMcpConfig: true,
  mcpServers: { dart: { type: 'stdio', command: 'dart', args: ['mcp-server'] } },
  env: { ...env, CLAUDE_AGENT_SDK_CLIENT_APP: 'holy-quran-agent-workflow/1' },
  stderr: (data) => process.stderr.write(data),
};

function shorten(text, limit) {
  const flat = String(text ?? '').replace(/\s+/g, ' ').trim();
  return flat.length > limit ? `${flat.slice(0, limit)}…` : flat;
}

function describeToolUse(block) {
  const input = block.input ?? {};
  const detail = input.command ?? input.file_path ?? input.pattern ?? input.description ?? input.url ?? '';
  return `→ ${block.name} ${shorten(detail, 200)}`;
}

let result;
try {
  for await (const message of query({ prompt, options })) {
    if (message.type === 'system' && message.subtype === 'init') {
      console.log(`session: model ${message.model}, permission mode ${message.permissionMode}, key source ${message.apiKeySource}`);
    } else if (message.type === 'assistant') {
      for (const block of message.message?.content ?? []) {
        if (block.type === 'text' && block.text.trim()) console.log(shorten(block.text, 2000));
        if (block.type === 'tool_use') console.log(describeToolUse(block));
      }
      if (message.error) console.log(`assistant error: ${message.error}`);
    } else if (message.type === 'result') {
      result = message;
    }
  }
} catch (error) {
  console.error(`agent: the session stopped with an exception: ${error?.message ?? error}`);
}

const outcome = result
  ? {
      subtype: result.subtype,
      is_error: result.is_error,
      total_cost_usd: result.total_cost_usd,
      num_turns: result.num_turns,
      duration_ms: result.duration_ms,
      errors: result.errors ?? [],
      model_usage: result.modelUsage,
      report: String(result.result ?? '').slice(0, REPORT_LIMIT),
    }
  : { subtype: 'no_result', is_error: true, errors: ['the session ended without a result message'] };

if (outcomeFile) writeFileSync(outcomeFile, JSON.stringify(outcome));

const cost = typeof outcome.total_cost_usd === 'number' ? `$${outcome.total_cost_usd.toFixed(2)}` : 'unknown';
console.log(`result: ${outcome.subtype}, estimated cost ${cost}, turns ${outcome.num_turns ?? 'unknown'}`);
if (env.GITHUB_STEP_SUMMARY) {
  appendFileSync(
    env.GITHUB_STEP_SUMMARY,
    [
      '## Agent run',
      '',
      '| | |',
      '| --- | --- |',
      `| Result | \`${outcome.subtype}\` |`,
      `| Estimated cost | ${cost} of a $${budget} cap |`,
      `| Turns | ${outcome.num_turns ?? 'unknown'} |`,
      `| Model | ${model ?? 'default'}, effort ${effort ?? 'default'} |`,
      `| Agent | ${agent ?? 'none (lead)'} |`,
      `| Key slot | ${env.AGENT_KEY_SLOT ?? 'unknown'} |`,
      '',
    ].join('\n'),
  );
}

process.exit(outcome.subtype === 'success' && !outcome.is_error ? 0 : 1);
