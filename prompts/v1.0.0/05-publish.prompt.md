---
name: publish-azure-pr-v1
description: 'Push the approved commit, create an Azure DevOps PR with CLI, and verify exact metadata and work item links.'
agent: agent
---

# Publish And Verify - 1.0.0

Read [shared policy](./policy.md) and [Azure execution reference](../../docs/azure-devops.md). This module needs approved metadata AND separate coordinator approval/context; metadata JSON alone never authorizes a push.

## Prerequisites And Scope

1. Confirm Git/Azure CLI with Azure DevOps extension and authenticated repository access. Do not assume the original author's tools or credentials. Missing prerequisites require user setup; never collect a secret in chat, silently install tools or alter global defaults. On auth/TLS failure, stop with setup guidance, not an insecure workaround.
2. Require explicit organization URL, project, repository ID/name, remote, source and target. Confirm current branch and HEAD match the verified approved commit and that the remote maps to that Azure repository. Stop on new index changes, HEAD drift or destination changes.
3. Read/fetch only the confirmed target ref and inspect source-only commits and source-to-target diff using Git objects. Fetch must be a normal non-force ref update with explicit remote/ref; do not fetch unrelated branches. Verify the approved commit is the only source-only commit and net diff is the approved change. If extra history, conflict/merge-base ambiguity, or target changes affect scope, stop; ask for a clean source branch or separately reviewed scope. Never silently include earlier commits or fix history. Unborn analysis can commit, but publication needs a valid reviewed target relationship.
4. Look for an active PR for this exact repository/source/target with `az repos pr list`. If one exists, show its ID/title and obtain explicit authorization to update it BEFORE pushing (push can update its content). Otherwise stop without writes. Multiple matches require clarification. An existing PR's broader contents require fresh review.

## Ordered Writes

Execute short single-purpose commands, checking each exit code. Pass title/body as data, never as shell code.

1. Run `git push -u <remote> HEAD:refs/heads/<source>` without force. Verify the remote source SHA equals the approved commit (`git ls-remote` for that ref). A rejected/divergent push stops; never pull/rebase automatically.
2. If no authorized existing PR, invoke `az repos pr create` with explicit `--organization`, `--project`, `--repository`, `--source-branch`, `--target-branch`, `--title`, full `--description`, `--draft false`, `--auto-complete false`, `--transition-work-items false`, `--output json`. Include `--work-items <ticketId>` only when not null. Use the PowerShell argument-array pattern in the reference to preserve description lines.
3. If an existing PR update was authorized, use `az repos pr update --id <id>` with approved title/body and explicit organization. Do not change its status, policies or completion settings.
4. A create race (`TF401179`) requires rediscovery and user approval to reuse/update the active PR, never blind retries. A timeout/unknown create result requires discovery before another create. Preserve the successful push in the failure report.
5. Query `az repos pr show --id <id> --organization <org> --output json`. Compare title case-sensitively, full description after CRLF-to-LF normalization only, repository ID, organization/project, source/target refs, active status, and source commit SHA with approved state. Do not accept a minimum length or prefix as proof of exact content.
6. If title/body mismatch only, update once with the complete approved metadata and requery. If still mismatched, stop with PR ID and mismatch; do not claim success. No REST/token workaround or relaxed comparison is authorized by this release.
7. If ticket exists, query `az repos pr work-item list`; if absent, run `az repos pr work-item add --id <id> --work-items <ticketId>` and requery. Ticket in a commit can create a Commit link, which is NOT proof of a PR link. Failed linking is partial completion, not full success.

## Final Output

Only after all checks, tell the user in English: PR ID, verified web URL, source to target, and confirmed ticket link if applicable. Never use the API resource URL as though it were the human web URL. Prefer `_links.web.href`; otherwise construct the Azure Repos browser PR URL from verified repository context.

On failure, state which operations completed, the existing commit/PR ID, what remains unverified, and the next safe retry. On resume, verify saved state rather than committing again. Never merge/complete the PR.
