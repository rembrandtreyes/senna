---
name: pr-story
description: Tells the story of a pull request so a human can review it with full context - the problem, the one change everything hinges on, the decisions and what they ruled out, and evidence for every claim. Use whenever writing a PR description (including /ship's PR step and any `gh pr create`), and when asked to explain, summarize, or walk someone through a PR or branch, or to check a PR description against the code before a human reviews it. Two modes - author (writes the description) and reviewer (retells the PR from the code and verifies the author's claims). Optional flavours - security, newcomer, risky-bits, performance, api. For hunting bugs in a diff, use the reviewer agent; this skill is about what a human needs in order to review well.
---

# PR story

A diff shows what changed, not why, what was ruled out, or what proves it works. Author and
reviewer share one contract: the checklist questions that apply to this change. The author
answers each with evidence; the reviewer checks each answer against the code.

Pick the mode from the ask: writing or opening a PR is **author**; explaining, summarizing, or
checking someone's PR is **reviewer**. A flavour applies only when asked for
(`references/flavours.md`).

## 1. Gather the facts
From the project root, run `bash ${CLAUDE_PLUGIN_ROOT}/skills/pr-story/scripts/pr-facts.sh
[base-ref] [head-ref]` (it's `scripts/pr-facts.sh` in this skill's directory; don't cd there,
since it describes whatever repo it's run in). It prints the base, commits, size against the
400-line limit, each file with change tags, the checklists those tags select, ticket refs, fix
commits that touched the same files, and the task, spec, ADRs, and lessons that exist. Use its
output instead of recomputing any of that. Then read:
- the diff (`git diff <merge-base> <head>`), hunk by hunk, in the order the story will tell it
- the task file's acceptance criteria and `Requirements:`, plus the spec sections and ADRs it names
- **in the author's own session, the conversation:** what was decided, what was tried and
  dropped, and why. Some of the why exists nowhere else, so capture it before the session ends.
- callers of changed functions, types, endpoints, and config keys outside the diff
  (`git grep -n -w <symbol>`), for the blast radius
- the fix commits pr-facts lists for touched files (`git show --stat <sha>`). A past bug in the
  same spot is a question worth asking.

For a GitHub PR that isn't checked out: `gh pr view <n> --json title,baseRefName,headRefName,commits`
(not `body` yet, see 3b), then `git fetch origin pull/<n>/head` and pass
`origin/<baseRefName> $(git rev-parse FETCH_HEAD)` to pr-facts and to `git diff`. Check the PR
out only to run tests, and ask first if that would disturb the working tree.

## 2. Pick the questions
Read `references/checklists/core.md`, plus the file for each other checklist pr-facts names
(`http.md`, `data.md`, `concurrency.md`, `security.md`, `ui.md`, `config.md`). Skip the rest.
Tags come from paths and changed lines, so they miss things: if you can see the change calls a
network service or writes data and the tag is missing, read that checklist too.
Add each `[review]` line in `.harness/learnings.md` that touches these files or areas: they are
this repo's own checklist items.

Turn each applicable item into a question about this PR ("What does the user see when
`POST /invites` returns 409?"), not a generic box. Keep the three to seven a careful reviewer
would actually ask about this change, and drop the rest instead of answering "N/A".

## 3a. Author mode
Write the description from the author template in `references/templates.md`.
- **Evidence for every claim:** a test (`path::test name`), a line range (`path:40-88`), or the
  result of a command run in this session, quoted with the command. /ship's checks and the
  reviewer agent's verdict count. A claim you can't back says "not verified" or "not handled".
  A visible gap beats a confident guess.
- **Story order:** the problem, then the one change everything hinges on, then the rest in the
  order a reviewer should read it (not file order), each marked careful or skim, with
  mechanical changes grouped last.
- **Risk:** high if it touches data, auth, money, or a public contract, or a revert won't undo
  it; medium if it changes behaviour users see; low otherwise.
- **Decisions:** each choice with the alternative it beat and why, from the task, the spec's
  ADRs, and the conversation. Link the ADR when there is one. No real decisions? Omit the section.
- **Proof of behaviour:** when the change is visible (UI, API, CLI output), show it: a request
  and response, before/after output, or a screenshot path. If you can't produce it, say what
  the reviewer should run.
- **Over the size limit:** propose a split along the story's seams (for example, refactor
  first, then behaviour), with the files in each part. Don't just warn.
- In /ship, this is the PR body. Interactive mode still shows it to the user before opening.

## 3b. Reviewer mode
Use the reviewer template in `references/templates.md`.
1. Retell the story from the code **before** reading the author's description, so their framing
   doesn't steer you. Then read it (`gh pr view <n> --json body`) and compare the two. Where
   they differ is the first finding.
2. Mark every claim in the description: **confirmed** (cite your own evidence), **unsupported**
   (no evidence given or found), or **contradicted** (the code says otherwise, at file:line).
3. Ask the applicable questions the author skipped.
4. Trace the blast radius yourself; don't copy the author's.
5. End with at most five pointed questions for the author, most important first.

No author story (an external PR, a bare branch): build it from scratch, with every claim drawn
from the code. Don't post anything to GitHub unless asked.

## 4. Brevity
- The TL;DR is three lines at most. Put the summary first and the detail in `<details>` blocks.
- Never restate the diff ("changed X in Y"): the story explains, the diff shows.
- Skip sections that don't apply. A 20-line fix gets a six-line description.

## 5. Lessons
When a review (yours or a human's) catches something notable, or a bug escapes past a story,
propose one line for `.harness/learnings.md`:
`- YYYY-MM-DD [review] <path or area>: <the question to ask next time>`. Append it once the user
agrees. /retro promotes lines that recur.
