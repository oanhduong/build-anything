---
id: home-scope
tags: [bash, shell]
when: pre-write
---

## What happened
`HOME=tmp echo ... | hook` only sets HOME for the `echo` process, not for the hook on the right side of the pipeline. The hook sees the original HOME, not the overridden value.

## Why
Environment variable prefix (`VAR=val cmd`) only applies to the directly-prefixed command. In a pipeline, each side is a separate process — the prefix never reaches the right side.

## How to avoid
Use `HOME=tmp bash -c '... | hook'` to scope HOME to both sides of the pipeline inside a single bash -c subshell invocation.
