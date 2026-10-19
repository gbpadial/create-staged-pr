# Azure DevOps Execution Reference

## Prerequisites And Destination

Use Azure DevOps **Services**, Azure CLI and its `azure-devops` extension. Configure authentication directly in the user's terminal using supported Azure tooling; never send passwords/PATs/tokens through chat. Azure DevOps Server is not supported by this CLI workflow. Do not assume an installed CLI, Azure subscription login or access to the target project proves all required repository permissions.

Infer candidates from `git remote get-url <remote>` and Git branch context. Azure URLs may be HTTPS (`https://dev.azure.com/<org>/<project>/_git/<repo>`), legacy `<org>.visualstudio.com` URLs, or SSH (`git@ssh.dev.azure.com:v3/<org>/<project>/<repo>`). Parse URLs with an appropriate URL parser, decode project/repository names, and ask about ambiguous mappings. Never embed a remote credential in output.

Confirm organization, project, repository, remote, source and target explicitly before publication. Never assume `main` or use Azure's implicit default target. Use per-command organization/project/repository arguments instead of modifying global defaults. A detached HEAD blocks publication.

Inspect target/source history before push. A PR compares branches, not just staged paths: extra source-only commits or a net diff beyond the approved change require a stop and new scope review. Existing PR lookup and update approval happen **before push**, because pushing alone changes an existing PR's contents.

## Safe CLI Arguments

The following is a pattern for an authorized agent, not an automatic script to run while reviewing docs. Values must come from validated coordinator state. Invoke one operation at a time and check `$LASTEXITCODE` immediately. Generated title/description are data, never executable PowerShell text.

```powershell
$metadata = Get-Content -LiteralPath $approvedMetadataPath -Raw | ConvertFrom-Json
$descriptionLines = [regex]::Split($metadata.description.Replace("`r`n", "`n"), "`n")
$arguments = @(
    'repos', 'pr', 'create',
    '--organization', $organization,
    '--project', $project,
    '--repository', $repository,
    '--source-branch', $source,
    '--target-branch', $target,
    '--title', $metadata.title,
    '--draft', 'false',
    '--auto-complete', 'false',
    '--transition-work-items', 'false',
    '--output', 'json'
)
if ($null -ne $ticketId) { $arguments += @('--work-items', $ticketId) }
$arguments += @('--description') + $descriptionLines
$response = & az @arguments
if ($LASTEXITCODE -ne 0) { throw 'PR creation failed; discover remote state before retrying.' }
$created = ($response -join "`n") | ConvertFrom-Json
```

Azure CLI documents one description argument per line. Native argument handling can differ, especially through `az.cmd` on Windows; a successful invocation is **not** proof that blank lines/quotes survived. The agent must query the stored PR and compare full metadata, not only CLI exit status. Do not interpolate long multiline strings into a shell command.

For authorized updates, use the same line-array approach with `az repos pr update --id <id> --organization <org> --title <title> --description <lines> --output json`. A pre-existing PR requires separate update authorization; a bounded repair of the newly created PR may reuse approval for its exact intended metadata.

## Verification And Ticket Links

After push, verify the remote source ref equals the approved commit SHA. After creation/update, query `az repos pr show --id <id> --organization <org> --output json` and compare:

- Exact case-sensitive `title` and `description`, normalizing CRLF to LF only.
- Organization/project and `repository.id`.
- Exact `sourceRefName` and `targetRefName` (`refs/heads/...`).
- Active PR status and source commit SHA (`lastMergeSourceCommit.commitId`).

If a server value is not yet available, report it as unverified; do not silently accept it. A title/body mismatch permits one complete CLI update and requery; persistent truncation is partial failure. No minimum character count can substitute for equality.

`#123` in a pushed commit may create a **Commit** link. The PR relationship is separate. Include `--work-items 123` on create; inspect `az repos pr work-item list --id <id> --organization <org> --output json`. If missing, use `az repos pr work-item add --id <id> --work-items 123 --organization <org> --output json` and inspect again. Null ticket means omit work-item operations. Never transition the work item's state.

## Recovery

| Failure                                    | Required behavior                                                      |
| ------------------------------------------ | ---------------------------------------------------------------------- |
| Hook failure or changed committed tree     | Preserve actual state and stop; no bypass, amend or push.              |
| Divergent/rejected push                    | Stop; no force, automatic pull/rebase or branch repair.                |
| Existing PR                                | Ask update permission before push; never create a duplicate.           |
| `TF401179` race or unknown create response | Discover exact active PR before retrying; ask reuse/update permission. |
| Truncated metadata after bounded repair    | Report PR ID and mismatch; no full success or relaxed comparison.      |
| Work item linking denied                   | Report PR exists but association remains incomplete.                   |
| Authentication or certificate error        | Ask for environment repair; never disable TLS or expose tokens.        |

Save commit/PR IDs for resumption. Requery actual state; do not replay commit/create blindly. Do not merge the PR, bypass policies, or enable auto-complete. Use verified `_links.web.href` or construct a browser URL from verified context, not the API `url`.

## Official References

- [Create PRs and CLI parameters](https://learn.microsoft.com/en-us/azure/devops/repos/git/pull-requests?view=azure-devops)
- [Azure CLI PR commands](https://learn.microsoft.com/en-us/cli/azure/repos/pr?view=azure-cli-latest)
- [Work item links and commit references](https://learn.microsoft.com/en-us/azure/devops/boards/backlogs/add-link?view=azure-devops)
