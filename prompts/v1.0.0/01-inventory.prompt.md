---
name: staged-inventory-v1
description: 'Inventory only staged Git paths and preserve an optional ticket as strict JSON.'
agent: agent
---

# Inventory Staged Changes - 1.0.0

Read [shared policy](./policy.md). This is a read-only analysis step except for Git object creation by `write-tree`. Do not stage or commit.

## Inputs

Repository working directory and optional explicit user ticket. Tools must execute in the confirmed repository, not the skill installation directory. No previous analysis is assumed.

## Procedure

1. Resolve `git rev-parse --show-toplevel`. Stop outside a Git worktree. Capture HEAD with `git rev-parse --verify HEAD`; distinguish a genuinely unborn branch from other failures. Capture branch via `git symbolic-ref --quiet --short HEAD`; detached HEAD permits analysis but blocks commit/publication.
2. Use `git ls-files --unmerged -z` to reject conflicts. Capture the index tree with `git write-tree` (writes only Git objects), retaining its ID privately. Read `git diff --cached --name-status -z --find-renames` and `git diff --cached --name-only -z --find-renames` against HEAD, or Git's default empty-tree comparison for an unborn branch. Decode NUL-delimited UTF-8 output without splitting on whitespace, newlines or quoted display paths. Use a process/tool API that preserves NUL bytes; if unavailable, stop rather than guess names.
3. Preserve name-only order. For renames/copies, inventory the destination once; retain the old path and status in private state for analysis. For deletion, retain the deleted path even though it does not exist on disk. Keep extensionless files and submodule entries.
4. Verify HEAD and `git write-tree` still match the captured values. On drift, discard results and restart. No working-tree file reads or unstaged diff reads are authorized.
5. Normalize only the explicitly supplied ticket. Emit JSON matching the [inventory schema](./contracts/inventory.schema.json).

## Output

```json
{
  "ticketId": "123456",
  "changes": ["src/bookmarks.ts", "tests/bookmarks.test.ts"]
}
```

No staged changes: emit `{"ticketId":null,"changes":[]}` (preserve a supplied ticket instead of null), then the coordinator stops before describing/committing. Do not invent a file to continue.
