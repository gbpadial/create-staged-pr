# Changelog

## 1.0.0 - Initial Release

- Five modular prompts: staged inventory, indexed change descriptions, approved semantic commit, approved PR metadata, and Azure CLI publication.
- Shared safety/evidence policy, three strict JSON contracts and Copilot orchestration skill.
- Offline fixtures, manual cross-model evaluation prompts, PowerShell validator, synthetic self-tests, Markdown and JSON reports.
- Installation, architecture, examples and Azure recovery documentation.

## Versioning Policy

Release directories under `prompts/v<version>/` and `tests/prompts/v<version>/` are immutable after publication. Before publication they may be corrected as a candidate; a release is not evidence that its quality gates passed.

For every subsequent prompt/policy/schema/evaluation change, create a new release directory and retain the prior release. Use PATCH for compatible wording corrections, MINOR for compatible capability additions and MAJOR for changed payload shapes or approval semantics. Record rationale, changed modules, migration and observed evaluation evidence here. Do not invent evaluation results.

Update `prompt-manifest.json` and the skill's direct resource links together. Pin one release for each workflow and evaluation campaign; never switch it midway. Schemas and rubric travel with their release. The validator resolves schemas from the campaign version. Shared fixtures/harness may evolve, but a changed case gets a new snapshot ID; retain old input evidence when comparing releases. If the harness requires a new envelope, document its migration before comparing results.

The initial inventory contract intentionally uses relative-path strings, reflecting the agreed revision to the original absolute-path object proposal. Description filenames are those same full relative paths, not basenames.
