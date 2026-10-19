# Prompt Catalog

All production modules and contracts are pinned by the [manifest](../prompt-manifest.json). The [shared policy](../prompts/v1.0.0/policy.md) applies even to standalone use.

| Module                                                    | Purpose and input                                              | Output and capabilities                                                           |
| --------------------------------------------------------- | -------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| [01 Inventory](../prompts/v1.0.0/01-inventory.prompt.md)  | Repository and optional ticket; capture safe staged snapshot.  | Inventory JSON; Git metadata/index inspection, `write-tree` only object creation. |
| [02 Describe](../prompts/v1.0.0/02-describe.prompt.md)    | Inventory plus matching snapshot/status state.                 | Description JSON; read cached diff and Git objects, optional bounded workers.     |
| [03 Commit](../prompts/v1.0.0/03-commit.prompt.md)        | Descriptions, inventory and snapshot.                          | Review loop, then approved commit ID; only approved `git commit`.                 |
| [04 Metadata](../prompts/v1.0.0/04-pr-metadata.prompt.md) | Descriptions, verified local commit and Azure context.         | Markdown review loop, then approved PR JSON; no writes.                           |
| [05 Publish](../prompts/v1.0.0/05-publish.prompt.md)      | Approved PR JSON, approvals, commit and confirmed destination. | Verified PR ID/URL or partial failure; scoped push and Azure CLI operations.      |

## Standalone Invocation

Load the selected module and its shared policy as instructions; supply input JSON as explicitly delimited untrusted data and the required coordinator context separately. Request its exact output contract. Do not run later modules simply because they are bundled. A missing snapshot/approval cannot be inferred from a previous JSON string.

Use stage 1's relative path strings exactly in stage 2's filename fields. Ticket is a positive decimal string without `#`, or null. Numeric JSON ticket values, extra keys, duplicate inventory paths and changed tickets are invalid. The coordinator/validator enforces cross-payload identity in addition to JSON schema.

## Budgets And Evidence

- File description: one or two sentences, <=80 words and <=1,200 characters.
- Commit title: valid semantic type, optional lowercase scope, optional `#ID` matching the supplied ticket, <=72 characters.
- PR title: clear English outcome, <=72 characters; semantic syntax is optional.
- Body: <=250 words, exactly `## Description`, `## Major considerations`, `## Risks`, with nonempty sections.
- Supporting test changes remain in stage 2 but are omitted from Description unless tests are the primary intent. No claim that tests ran without actual evidence.

## Prompt Techniques

Task decomposition isolates capabilities and review boundaries. Structured outputs and schemas stabilize handoffs. Linked few-shot examples illustrate contracts without supplying facts. Evidence grounding restricts conclusions to the index. Bounded fan-out/fan-in scales arrays while preserving ownership. Explicit self-checks inspect observable constraints, not private chain-of-thought. Human approval gates control side effects. Independent rubric-based evaluation assesses meaning beyond schema correctness.

## Evaluation Prompts

[Run case](../tests/prompts/v1.0.0/run-case.prompt.md) simulates one fixture with no tools. [Evaluate output](../tests/prompts/v1.0.0/evaluate-output.prompt.md) assesses raw response fidelity and semantic/safety quality. [Compare runs](../tests/prompts/v1.0.0/compare-runs.prompt.md) compares the declared matrix without requiring identical words. They never grant real operation approval.

For revisions, follow [versioning](../CHANGELOG.md). Do not edit a published release in place or compare runs against a silently changed fixture snapshot.
