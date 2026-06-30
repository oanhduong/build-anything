---
id: dotenv-module-scope
tags: [python, testing, environment]
when: pre-write
---

## What happened
`load_dotenv()` placed only in `main.py`. When pytest imports a module directly, the entrypoint never runs, so env vars from .env are never loaded — causing `anthropic.AuthenticationError` in tests.

## Why
`VAR=val` at the entrypoint only loads env vars when that script runs. Modules that create clients at import time (e.g. `client = anthropic.Anthropic()` at module scope) need `load_dotenv()` called before that line executes.

## How to avoid
Call `load_dotenv()` at module level in every module that reads env vars at import time — not just in `main.py`. Put it in the module where the env var is first used.
