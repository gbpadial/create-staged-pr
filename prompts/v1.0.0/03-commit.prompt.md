---
name: approved-semantic-commit-v1
description: 'Draft an English semantic commit and commit the exact staged snapshot only after approval.'
agent: agent
---

# Approve And Commit - 1.0.0

Read [shared policy](./policy.md). This is the only module authorized to create a commit, and only after approval.

## Inputs

Inventory, descriptions and matching coordinator snapshot. Commit execution requires a named branch. Stop if evidence is incomplete or unrelated concerns require the user to split staged changes; never split/stage automatically.

## Draft

Choose the dominant intent: `feat` new capability; `fix` correctness; `refactor` internal restructuring without behavior change; `perf` optimization; `docs` docs-only; `test` tests-only; `build` tooling/dependencies; `ci` automation; `chore` other maintenance. Supporting docs/tests do not override production intent.

Use `<type>(<scope>): #<ticket> <imperative summary>`. Omit meaningless scope, and omit the ticket token entirely when null. Keep the whole title within 72 characters. Example: `fix(bookmarks): #123456 invalidate cache after saving`.

Present the exact title in English and ask: "Approve committing this staged snapshot with this title, or provide a replacement?" A suggestion is not approval: validate it, present the revised title and ask again. On rejection, stop without writes. Do not fabricate facts to satisfy a user-provided title.

## Execute After Explicit Approval

1. Confirm repository, named branch, HEAD and `git write-tree` equal the captured values. Reject drift and restart analysis; do not merely ask approval for a stale summary.
2. Invoke `git commit -m <approvedTitle>` using an argument array and the normal index. No path arguments, `-a`, `--no-verify` or implicit staging. Preserve unstaged/untracked files.
3. On failure, stop and retain the result; inspect HEAD before proposing a retry because hooks may have side effects. Never bypass hooks or amend automatically.
4. On success, capture the resulting commit ID and verify its subject equals the approved title and its tree equals the approved index tree. Verify its parent is initial HEAD (or it is a root commit for the unborn case). If hooks changed committed content, report the mismatch and block push, without undoing the commit.
5. Record the verified commit ID privately for the next module. Do not emit PR metadata or push yet. If the user stops later, report honestly that the local commit already exists.

## Handoff

Return an English confirmation containing the local commit ID. The coordinator retains inventory, summaries, approval and commit evidence separately; this step does not alter either public JSON contract.
