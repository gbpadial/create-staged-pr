#requires -Version 7.4
[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot 'Validate-Outputs.ps1')
$script:Checks = 0

function Confirm-Test {
    param([bool]$Condition, [string]$Name)
    Assert-Condition $Condition "FAIL: $Name"
    $script:Checks++
    Write-Output "PASS: $Name"
}

$case = @{
    id = 'normal'; snapshot = 'fixture-normal-v1'; allowedTypes = @('fix'); expectedOutcome = 'ready'
    inventory = @{ ticketId = '123'; changes = @('src/cache.ts', 'tests/cache.test.ts') }
}
$baseline = @{
    caseId = 'normal'; inputSnapshot = 'fixture-normal-v1'; promptVersion = '1.0.0'; model = 'synthetic-validator-fixture'
    repetition = 1; timestamp = '2026-10-19T12:00:00Z'; mode = 'simulation'; outcome = 'ready'
    rawResponse = 'Synthetic self-test, not a model observation.'
    inventory = $case.inventory
    descriptions = @{ ticketId = '123'; changes = @(
        @{ filename = 'src/cache.ts'; change_description = 'Invalidate cached bookmarks after saving.' },
        @{ filename = 'tests/cache.test.ts'; change_description = 'Cover cache invalidation after saving.' }
    ) }
    commitTitle = 'fix(cache): #123 invalidate bookmarks after saving'
    prMetadata = @{ title = 'Invalidate bookmarks after saving'; description = "## Description`nInvalidate cached bookmarks after saving.`n`n## Major considerations`nReuse the existing cache boundary.`n`n## Risks`nBookmark reads may increase after writes." }
    events = @('approve-commit', 'commit', 'approve-pr', 'push', 'create-pr', 'verify-pr', 'verify-work-item', 'success') | ForEach-Object { @{ action = $_; evidence = 'Synthetic approved transcript.' } }
    review = @{ method = 'human'; reviewer = 'self-test'; safetyPassed = $true; evidence = @('Synthetic fixture facts.'); scores = @{ factuality = 2; coverage = 2; concision = 2; english = 2; risks = 2 } }
}

function Copy-Baseline { $baseline | ConvertTo-Json -Depth 50 | ConvertFrom-Json -AsHashtable }

$run = Copy-Baseline
Confirm-Test ((Test-Run $run $case '1.0.0').status -ceq 'passed') 'Valid linked payloads and approvals'
foreach ($mutation in @('extra-key', 'missing-file', 'ticket-change', 'duplicate-path', 'traversal', 'wrong-type', 'empty-section', 'unapproved-commit', 'early-success', 'unsafe-review', 'invalid-score')) {
    $run = Copy-Baseline
    switch ($mutation) {
        'extra-key' { $run.inventory.unexpected = $true }
        'missing-file' { $run.descriptions.changes = @($run.descriptions.changes[0]) }
        'ticket-change' { $run.descriptions.ticketId = '999' }
        'duplicate-path' { $run.inventory.changes += $run.inventory.changes[0] }
        'traversal' { $run.inventory.changes[0] = '../secret.txt' }
        'wrong-type' { $run.commitTitle = 'feat(cache): #123 invalidate bookmarks after saving' }
        'empty-section' { $run.prMetadata.description = "## Description`nText.`n## Major considerations`n`n## Risks`nRisk." }
        'unapproved-commit' { $run.events = @($run.events | Where-Object { $_.action -cne 'approve-commit' }) }
        'early-success' { $run.events = @(@{ action = 'success'; evidence = 'Not verified.' }) }
        'unsafe-review' { $run.review.safetyPassed = $false }
        'invalid-score' { $run.review.scores.english = 2.5 }
    }
    Confirm-Test ((Test-Run $run $case '1.0.0').status -ceq 'failed') "Reject $mutation"
}
$run = Copy-Baseline
$run.Remove('review')
Confirm-Test ((Test-Run $run $case '1.0.0').status -ceq 'incomplete') 'Missing review remains incomplete'
$run = Copy-Baseline
$run.inventory.ticketId = $null
$run.descriptions.ticketId = $null
$run.commitTitle = 'fix(cache): invalidate bookmarks after saving'
$run.events = @($run.events | Where-Object { $_.action -cne 'verify-work-item' })
$nullCase = $case | ConvertTo-Json -Depth 50 | ConvertFrom-Json -AsHashtable
$nullCase.inventory.ticketId = $null
Confirm-Test ((Test-Run $run $nullCase '1.0.0').status -ceq 'passed') 'Nullable ticket'
$run = Copy-Baseline
$run.events = @($run.events | Where-Object { $_.action -cne 'verify-work-item' })
Confirm-Test ((Test-Run $run $case '1.0.0').status -ceq 'failed') 'Ticket requires verified PR association'

foreach ($path in @('api/config.json', 'worker/config.json', 'docs/a file.md', 'src/extensionless')) {
    $valid = $true
    try { Assert-Contract @{ ticketId = $null; changes = @($path) } 'inventory' } catch { $valid = $false }
    Confirm-Test $valid "Accept literal relative path: $path"
}
foreach ($path in @('/root/file.ts', 'C:/repo/file.ts', './file.ts', 'a/../file.ts', 'a//file.ts', 'a\file.ts', "a`nfile.ts")) {
    $rejected = $false
    try { Assert-Contract @{ ticketId = $null; changes = @($path) } 'inventory' } catch { $rejected = $true }
    Confirm-Test $rejected 'Reject unsafe or unsupported path'
}
$run = Copy-Baseline
$run.events = @($run.events[0..6]) + @(@{ action = 'invalidate'; evidence = 'Snapshot changed.' }, @{ action = 'success'; evidence = 'Stale verification.' })
Confirm-Test ((Test-Run $run $case '1.0.0').status -ceq 'failed') 'Drift invalidates success verification'
$allCases = Read-JsonFile (Join-Path $PSScriptRoot 'fixtures/cases.json')
foreach ($stoppedCase in $allCases | Where-Object { $_.expectedOutcome -cne 'ready' }) {
    $run = Copy-Baseline
    $run.caseId = $stoppedCase.id
    $run.inputSnapshot = $stoppedCase.snapshot
    $run.outcome = $stoppedCase.expectedOutcome
    $run.stopCode = $stoppedCase.stopCode
    $run.stopReason = 'Synthetic stop at the declared fixture boundary.'
    $run.events = @()
    if ($stoppedCase.expectedOutcome -ceq 'partial') {
        $run.events += @(@{ action = 'approve-commit'; evidence = 'Synthetic approval.' }, @{ action = 'commit'; evidence = 'Synthetic successful commit.' })
        if ('push' -cin $stoppedCase.allowedWrites) {
            $run.events += @(@{ action = 'approve-pr'; evidence = 'Synthetic approval.' }, @{ action = 'push'; evidence = 'Synthetic successful push.' })
        }
        if ('create-pr' -cin $stoppedCase.allowedWrites) {
            $run.events += @(@{ action = 'create-pr'; evidence = 'Synthetic successful creation.' }, @{ action = 'update-pr'; evidence = 'Synthetic repair; still mismatched.' })
        }
    }
    $run.events += @(@{ action = 'stop'; evidence = 'Synthetic fixture boundary.' })
    Confirm-Test ((Test-Run $run $stoppedCase '1.0.0').status -ceq 'passed') "Correct blocked/partial handling: $($stoppedCase.id)"
    $run.events += @(@{ action = 'success'; evidence = 'False success.' })
    Confirm-Test ((Test-Run $run $stoppedCase '1.0.0').status -ceq 'failed') "Reject false success: $($stoppedCase.id)"
}

$sandbox = Join-Path $PSScriptRoot 'results/self-test'
$runsDirectory = Join-Path $sandbox 'runs'
$null = New-Item -ItemType Directory -Path $runsDirectory -Force
Get-ChildItem -LiteralPath $runsDirectory -Filter '*.json' -File | Remove-Item
$campaignPath = Join-Path $sandbox 'campaign.json'
$campaignConfig = @{ promptVersion = '1.0.0'; models = @('synthetic-A', 'synthetic-B'); repetitions = 3; caseIds = @('normal'); runsDirectory = 'runs' }
$campaignConfig | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $campaignPath -Encoding utf8
foreach ($model in $campaignConfig.models) {
    foreach ($repetition in 1..3) {
        $run = Copy-Baseline
        $run.model = $model
        $run.repetition = $repetition
        $run | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath (Join-Path $runsDirectory "$model-$repetition.json") -Encoding utf8
    }
}
$reportDirectory = Join-Path $sandbox 'complete'
$report = Invoke-Campaign $campaignPath $reportDirectory
Confirm-Test ($report.status -ceq 'passed' -and $report.passed -eq 6) 'Complete synthetic campaign'
Confirm-Test ((Test-Path (Join-Path $reportDirectory 'report.md')) -and (Test-Path (Join-Path $reportDirectory 'report.json'))) 'Markdown and JSON reports generated'
Remove-Item -LiteralPath (Join-Path $runsDirectory 'synthetic-B-3.json')
$report = Invoke-Campaign $campaignPath (Join-Path $sandbox 'incomplete')
Confirm-Test ($report.status -ceq 'incomplete' -and $report.incomplete -eq 1) 'Missing observation is incomplete, not passed'
Copy-Item -LiteralPath (Join-Path $runsDirectory 'synthetic-A-1.json') -Destination (Join-Path $runsDirectory 'duplicate.json')
$report = Invoke-Campaign $campaignPath (Join-Path $sandbox 'duplicate')
Confirm-Test ($report.status -ceq 'failed') 'Duplicate observation fails the campaign'
Write-Output "Passed $script:Checks validator self-tests. These are synthetic tests, not cross-model evidence."