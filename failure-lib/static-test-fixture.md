---
id: static-test-fixture
tags: [testing, fixtures, reproducibility]
when: pre-write
---

## What happened
Test fixture files (e.g. sample.xlsx) were generated at test-time inside a conftest.py fixture function. Tests failed due to file creation order and teardown races.

## Why
Test-time generation depends on write access, execution order, and teardown — all of which vary. It creates implicit dependencies between tests.

## How to avoid
Commit static fixture files to the repository. Never generate them in test code. A committed fixture is always present, always identical, and requires no teardown.
