# ADR-003: Agents that read the web get no shell and can't write

Status: accepted   ·   Date: 2026-10-25
Applies to: plugins/*/agents/**
Check: an agent whose tools include WebSearch or WebFetch and also Bash, Write, Edit, or NotebookEdit

## Context
A web page can carry text written to steer the model that reads it. An agent that reads pages
and also has a shell or write access could be talked into running a command or changing files,
and in auto mode some commands run without asking.

## Decision
We will give an agent that reads the web only read tools (Read, Grep, Glob) besides its web
tools. Whatever it needs from git or a shell, its caller prepares as a file, as `/vet` does
with the diff for the best-practices agent.

## Alternatives
- **A shell limited by the agent's instructions:** instructions are what an injected page
  attacks.
- **No web access, answering from the model's training:** misses what changed after its
  cutoff, which is the point of checking current practice.

## Consequences
Callers do the git work for the agent. An agent that needs both, such as one that researches
then edits, has to be split in two.
