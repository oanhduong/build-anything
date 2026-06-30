---
id: mock-import-boundary
tags: [python, testing, mocking]
when: pre-write
---

## What happened
`@patch('anthropic.Anthropic')` did not intercept a module that had already imported and bound the name at import time. The mock was patching the SDK namespace, but the module had its own reference.

## Why
Python's `unittest.mock` patches the name binding in a specific namespace. If `recommend.py` does `import anthropic` then `client = anthropic.Anthropic()`, the reference lives in `recommend`'s namespace, not the global `anthropic` namespace.

## How to avoid
Patch at the import location: `@patch('modules.recommend.anthropic.Anthropic')`. The patch target must be where the name is *looked up*, not where it is *defined*.
