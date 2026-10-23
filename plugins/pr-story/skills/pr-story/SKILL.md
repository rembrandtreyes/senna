---
name: pr-story
description: Tells the story of a pull request so a human can review it with context - the problem, the change it hinges on, the decisions and what they beat, and evidence for every claim. Use when writing or opening a PR (including /ship's PR step), or when asked to explain, summarize, or check a PR or branch before a human reviews it. Modes - author, reviewer. Flavours - security, newcomer, risky-bits, performance, api. Not a bug hunt; use the reviewer agent for that.
argument-hint: "[author | reviewer] [PR number | base-ref] [flavour]"
---

# PR story

A diff shows what changed, not why, what was ruled out, or what proves it works. Author and
reviewer share one contract: the checklist questions that apply to this change. The author
answers each with evidence; the reviewer checks each answer against the code.

Pick the mode from the ask: writing or opening a PR is **author**; explaining, summarizing, or
checking someone's PR is **reviewer**. A flavour applies only when asked for
(`references/flavours.md`). Neither mode hunts bugs: when the user wants that too, also run the
reviewer agent (core plugin).

## 1. Gather the facts
From the project root, run `bash ${CLAUDE_PLUGIN_ROOT}/skills/pr-story/scripts/pr-facts.sh
[base-ref] [head-ref] [head-branch]` (it's `scripts/pr-facts.sh` in this skill's directory;
don't cd there, since it describes whatever repo it's run in). It prints the base, commits,
size by kind against the 400-line limit, each file with change tags, the checklists those tags
select, ticket refs, recent fix commits on the touched files, and the task, spec, ADRs, lessons,
and decision log that exist. Use its output instead of recomputing any of that. Then read:
- the diff (`git diff <merge-base> <head>`), hunk by hunk, in the order the story will tell it
- the task file: acceptance criteria, `Requirements:`, and its Context and Log, plus the spec
  sections and ADRs it names
- each `#<n>` ref's issue (`gh issue view <n>`), for the problem as the reporter saw it
- **the why.** First the branch's decision log and the `Decision:` trailers pr-facts counts
  (`git log --format='%(trailers:key=Decision,valueonly,unfold)' <merge-base>..<head>`): each
  records a choice when it was made. Then, in the author's own session, the conversation: what was
  decided, what was tried and dropped. Otherwise, commit bodies, the task's Log, the dead ends
  in `.harness/handoff*.md`, the ADRs, and PR comments. A decision you can see in the code
  with no recorded reason is listed as "reason not recorded". Never infer one.
- callers of changed functions, types, endpoints, and config keys outside the diff
  (`git grep -n -w <symbol>`), for the blast radius
- the fix commits pr-facts lists (`git show --stat <sha>`). A past bug in the same spot is a
  question worth asking.

For a GitHub PR that isn't checked out: `gh pr view <n> --json baseRefName,headRefName,headRefOid`
(not the title, body, or commits yet; see 3b), then `git fetch origin <baseRefName> pull/<n>/head`
(this refreshes the base too and leaves the working tree alone). Pass
`origin/<baseRefName> <headRefOid> <headRefName>` to pr-facts, and the first two to `git diff`.
Don't run a PR's code or tests when its author can't push to the repo, unless the user says so,
and then only in a scratch worktree.

## 2. Pick the questions
Read `references/checklists/core.md`, plus the file for each other checklist pr-facts names.
Tags are regex hints over paths and changed lines:
- A tag whose matching lines are patterns, strings, or comments is a false positive (a script
  full of regexes gets every tag). Skip that checklist.
- A checklist the change plainly needs that wasn't tagged: read it anyway.
- `[prompt]` files (skills, commands, agents, CLAUDE.md) are behaviour, not docs.

Add each line in `.harness/learnings.md` tagged `[review]` or naming these files or areas:
they are this repo's own checklist items.

Turn each applicable item into a question about this PR ("What does the user see when
`POST /invites` returns 409?"), not a generic box. Keep the three to seven a careful reviewer
would actually ask about this change, and drop the rest instead of answering "N/A". A flavour
that asks for every item overrides the cap.

## 3a. Author mode
Write the description from the author template in `references/templates.md`.
- **Evidence for every claim:** a test (`path::test name`), a line range (`path:40-88`), or a
  command run in this session with its result. A reviewer's finding counts when cited at
  file:line; an overall verdict ("reviewer: PASS") doesn't. A claim you can't back says "not
  verified" or "not handled". A visible gap beats a confident guess.
- **Story order:** the problem, then the one change everything hinges on, then the rest in the
  order a reviewer should read it (not file order), each marked careful or skim, with
  mechanical changes grouped last.
- **Risk:** judge it from the diff, not the tags. High if it touches data, auth, money, or a
  public contract, or a revert won't undo it; medium if it changes behaviour users see; low
  otherwise.
- **Decisions:** each choice with the alternative it beat and why, from the sources in step 1.
  A log entry that a later one reverses is dropped. Link the ADR when there is one. No
  decisions in the code or the record? Omit the section.
- **Proof of behaviour:** when the change is visible (UI, API, CLI output), show it: a request
  and response, before/after output, or a screenshot path. If you can't produce it, say what
  the reviewer should run.
- **Size:** over the limit with mostly code, propose a split along the story's seams (for
  example, refactor first, then behaviour), with the files in each part, to the user **before**
  writing the body, and wait. If they keep it whole, or in auto mode, the Size line gives the
  split you'd suggest. When most of the size is docs, copies, or assets, the Size line says so
  and nothing is split.
- **In /ship:** this is the PR body, written before the review. The Verified line carries the
  run's checks with their results. The reviewer then checks every claim against the code, so
  write only what it can confirm, and /ship adds should-fix items the user declines as "not
  handled". Interactive mode still shows the body to the user before opening.

## 3b. Reviewer mode
Use the reviewer template in `references/templates.md`.
1. Retell the story from the code **before** reading the author's description, so their framing
   doesn't steer you. Commit subjects in pr-facts' output are the author's claims too. Then read
   the PR (`gh pr view <n> --json title,body,commits`) and compare. Where the two differ is the
   first finding.
2. Mark each claim a reviewer would act on: **confirmed** (cite your own evidence),
   **unsupported** (no evidence given or found), or **contradicted** (the code says otherwise,
   at file:line). Fold trivial confirmed claims into one line.
3. Ask the applicable questions the author skipped.
4. Trace the blast radius yourself; don't copy the author's.
5. Size: one line on how much of it is mechanical, and whether it should have been split.
6. End with at most five pointed questions for the author, most important first.

No description (a bare branch or commit): commit bodies are the only claims. With none, drop
the Differs and Claims sections. Don't post anything to GitHub unless asked.

## 4. Brevity
- The TL;DR is three lines at most. Put the summary first and the detail in `<details>` blocks.
- Never restate the diff ("changed X in Y"): the story explains, the diff shows.
- Skip sections that don't apply. A 20-line fix gets a six-line description.

## 5. Lessons
When a review (yours or a human's) catches something notable, or a bug escapes past a story,
propose one line for `.harness/learnings.md`:
`- YYYY-MM-DD [review] <path or area>: <the question to ask next time>`. Append it once the user
agrees; in auto mode, put it in the final report instead. /retro proposes promoting lines that
recur.
