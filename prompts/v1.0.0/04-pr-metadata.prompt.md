---
name: approved-pr-metadata-v1
description: 'Draft and obtain approval for concise English PR metadata grounded in staged summaries.'
agent: agent
---

# Review Pull Request Metadata - 1.0.0

Read [shared policy](./policy.md). This module has no Git/Azure write authority.

## Inputs

Validated inventory/descriptions, verified local commit ID and approved title, plus publishing context. Before publishing approval, resolve organization/project/repository, remote, source and target branch. Infer candidates from configured remote URLs, including HTTPS/SSH Azure forms; ask about ambiguity, missing values and unsupported hosts. Never silently assume a target branch. Confirm these values with the user.

## Compose

PR title: meaningful, objective, entirely English, at most 72 characters; it need not repeat semantic syntax or ticket. A short outcome-oriented title is preferred.

PR description: at most 250 words, with exactly these second-level headings in this order:

```markdown
## Description

Invalidate cached bookmarks after successful saves so subsequent reads reload saved data.

## Major considerations

Keep invalidation at the existing save boundary to cover all callers without changing the read contract.

## Risks

Bookmark consumers may perform additional reads after writes; stale-cache behavior is the affected area.
```

The example assumes supporting staged evidence; never copy unsupported assertions. Description summarizes production changes and omits supporting test files unless tests are the primary intent. Tests-only changes must be described rather than omitted. Major considerations explains evidenced sensitive choices; if motivation is unknown, state the observable boundary and ask the user when necessary. Risks names affected components/callers and concrete failure modes; distinguish unknown risk from no risk. Do not invent test results or rollback guarantees.

## Approval Loop

1. Present both title and complete body together inside one `markdown` code fence (title as `# <title>`), and show the proposed publishing destination outside the fence.
2. Ask whether the user approves this exact metadata and destination for push and PR creation. Explain that the local commit exists, and a PR will include the branch's source-to-target history, not just an index selection.
3. Apply requested edits, validate again and present the complete revised proposal. Any metadata/destination change cancels prior publishing approval.
4. Rejection stops without push or Azure writes. After explicit approval, emit only the [metadata contract](./contracts/metadata.schema.json):

```json
{
  "title": "Invalidate bookmarks after saving",
  "description": "## Description\nInvalidate cached bookmarks after successful saves.\n\n## Major considerations\nUse the existing save boundary.\n\n## Risks\nBookmark readers may issue additional reads after writes."
}
```

Retain approval, destination, ticket and commit ID privately. Do not add them to this output object.
