# Usage Examples

These are illustrative, not observations about a real repository or executed tests.

## Ticket And Supporting Tests

Inventory:

```json
{
  "ticketId": "123456",
  "changes": ["src/bookmarks.ts", "tests/bookmarks.test.ts"]
}
```

Descriptions:

```json
{
  "ticketId": "123456",
  "changes": [
    {
      "filename": "src/bookmarks.ts",
      "change_description": "Invalidate cached bookmarks after successful saves so later reads reload saved data."
    },
    {
      "filename": "tests/bookmarks.test.ts",
      "change_description": "Add a regression case that expects bookmark cache invalidation after a successful save."
    }
  ]
}
```

Commit review:

```text
Assistant: Proposed commit: fix(bookmarks): #123456 invalidate cache after saving
Approve committing this staged snapshot with this title, or provide a replacement?
User: Use "fix(bookmarks): #123456 refresh cache after saves".
Assistant: Revised commit: fix(bookmarks): #123456 refresh cache after saves
Approve this exact title and staged snapshot?
User: Approved.
```

Only now may the agent commit and verify the tree. Suppose the staged patch establishes an existing save boundary; PR review then presents:

```markdown
# Refresh bookmarks after saving

## Description

Invalidate cached bookmarks after successful saves so later reads reload saved data.

## Major considerations

Keep invalidation at the existing save boundary to cover its callers without changing the read contract.

## Risks

Bookmark readers may perform additional reads after writes; save-dependent consumers are affected.
```

Outside the fence, the assistant presents verified organization/project/repository, remote, source/target and asks approval to push and create the PR. Supporting tests are not listed in Description. After approval, the handoff is:

```json
{
  "title": "Refresh bookmarks after saving",
  "description": "## Description\nInvalidate cached bookmarks after successful saves so later reads reload saved data.\n\n## Major considerations\nKeep invalidation at the existing save boundary to cover its callers without changing the read contract.\n\n## Risks\nBookmark readers may perform additional reads after writes; save-dependent consumers are affected."
}
```

The agent then performs scope checks, checks/approves any existing PR update, pushes, creates/updates via Azure CLI and verifies exact metadata and work item 123456. It cannot claim tests passed merely because a test file was staged.

## No Ticket, Tests Only

```json
{ "ticketId": null, "changes": ["tests/bookmarks.test.ts"] }
```

```json
{
  "ticketId": null,
  "changes": [
    {
      "filename": "tests/bookmarks.test.ts",
      "change_description": "Add coverage asserting cache invalidation does not occur after failed saves."
    }
  ]
}
```

Proposed commit: `test(bookmarks): cover failed saves`. The PR Description must describe this regression coverage because tests are the primary change. No `#null`, inferred ticket or work-item operation is permitted.

## Safe Stops

```text
User: Do not create the PR.
Assistant: Publication stopped. The previously approved local commit exists; nothing was pushed and no PR was created.
```

```text
Assistant: The staged snapshot changed after analysis. The prior title and approvals are invalid; I must reanalyze before committing.
```

```text
Assistant: PR 43 exists, but its stored description still differs from the approved body after one repair. Publication is only partially complete; I cannot confirm success.
```

The last messages are appropriate only when actual/mock tool evidence supports each completed-state claim.
