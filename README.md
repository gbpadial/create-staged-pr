# Create Staged PR

A modular Copilot skill for turning an approved Git index snapshot into an English semantic commit and a verified Azure DevOps pull request.

## Structure

```text
src/
  SKILL.md                         Copilot entry point
  prompt-manifest.json             Pinned active release and resources
  CHANGELOG.md                     Release history and compatibility policy
  prompts/v1.0.0/                  Five modules, policy and JSON contracts
  tests/
    Validate-Outputs.ps1           Offline evaluation and reports
    Test-Validator.ps1             Synthetic validator regression tests
    fixtures/cases.json           Shared staged/mock evidence
    examples/                     Campaign and observation templates
    prompts/v1.0.0/               Run, review and compare prompts
    results/                      Generated local evidence (Git-ignored)
  docs/                           Architecture, usage, Azure and test guides
```

## Requirements

- VS Code with GitHub Copilot agent mode and access to file/Git/terminal tools. Subagents are optional.
- Git in the target repository; only intended changes staged.
- For publication: Azure CLI with the Azure DevOps extension, authenticated Azure DevOps Services access, and permissions to push, create PRs and link work items. Azure DevOps Server CLI publication is not supported by this release.
- For local evaluation only: PowerShell 7.4 or later (`pwsh`), no external packages or model API keys.

## Install As A Skill

Copy the **contents** of this directory into `%USERPROFILE%\.copilot\skills\create-staged-pr\` for personal use, or `.github/skills/create-staged-pr/` in a consumer repository for team use. `SKILL.md` must be directly inside `create-staged-pr`, not inside another `src` directory. Preserve all relative paths, including the manifest, prompts, contracts, docs and test resources. Do not distribute generated `tests/results/`, sandbox data or local campaign files.

Back up an existing installed skill before replacement; this repository does not overwrite it. `src/SKILL.md` is the distribution source, not a standard auto-discovery location. Reload VS Code if the newly installed skill does not appear; check that agent skills are enabled and the location is recognized by your version. Bundled prompts are internal resources, not independently installed slash commands.

## Use

Open the intended Git repository, stage your changes, then invoke `/create-staged-pr` in Copilot Chat, for example:

```text
/create-staged-pr Ticket #123456, target branch develop.
```

The skill inventories staged paths, describes cached diffs, requests approval for the exact commit title, commits, requests approval for PR metadata/destination, then pushes and publishes through Azure CLI. It never stages other files. All generated prose is English. A ticket is optional; a supplied ticket is included in the commit and explicitly linked/verified on the PR.

Approving a commit is not approval to publish. Rejecting publication may leave the already approved local commit. A PR includes source-branch history, so extra unrelated commits block publication rather than silently expanding staged-only scope.

## Test And Report

From the root of this repository:

```powershell
pwsh -NoProfile -File ./src/tests/Test-Validator.ps1
pwsh -NoProfile -File ./src/tests/Validate-Outputs.ps1 -Campaign ./src/tests/examples/campaign.json -OutputDirectory ./src/tests/results/manual-report
```

The first command creates clearly labeled synthetic reports under `tests/results/self-test/`. The second evaluates collected observations; the supplied campaign has placeholder model IDs and no observations, so it initially returns **incomplete**, exit code 2. Replace identifiers and collect runs as described in the [test guide](./docs/testing.md). No model calls, Git writes or Azure calls occur in either command.

Reports: `report.md` for people and `report.json` for tooling. Exit codes: 0 passed, 1 failed/configuration error, 2 incomplete. Simulations do not prove live Azure execution or cross-model quality until actual model responses are collected and reviewed.

## Documentation

- [Architecture and execution diagram](./docs/architecture.md)
- [Prompt catalog and contracts](./docs/prompt-catalog.md)
- [Evaluation protocol and report format](./docs/testing.md)
- [Azure execution and recovery](./docs/azure-devops.md)
- [Examples and approval conversations](./docs/examples.md)
- [Versioning](./CHANGELOG.md)
