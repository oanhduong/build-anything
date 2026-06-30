---
id: openpyxl-engine
tags: [python, pandas, testing]
when: on-error
error-match: xlrd
---

## What happened
`pd.read_excel(path)` without `engine='openpyxl'` fails on .xlsx files in pandas 1.2+. xlrd dropped .xlsx support but the model generates the older pattern from pre-1.2 training data.

## How to avoid
Always use `pd.read_excel(path, engine='openpyxl')` for .xlsx files. For legacy .xls files use `engine='xlrd'`.
