#requires -Version 7.4
[CmdletBinding()]
param(
    [string]$Campaign,
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'results/latest')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:BundleRoot = Split-Path $PSScriptRoot -Parent

function Read-JsonFile {
    param([string]$Path)
    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable
}

function Assert-Condition {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-Contract {
    param([object]$Value, [string]$Name, [string]$Version = '1.0.0')
    Assert-Condition ($Version -cmatch '^\d+\.\d+\.\d+$') 'Invalid release version.'
    $schema = Join-Path $script:BundleRoot "prompts/v$Version/contracts/$Name.schema.json"
    $json = ConvertTo-Json -InputObject $Value -Depth 50 -Compress
    Assert-Condition (Test-Json -Json $json -SchemaFile $schema -ErrorAction SilentlyContinue) "Invalid $Name contract."
}

function Test-Payloads {
    param([System.Collections.IDictionary]$Run, [System.Collections.IDictionary]$Case)
    Assert-Contract $Run.inventory 'inventory' $Run.promptVersion
    Assert-Contract $Run.descriptions 'descriptions' $Run.promptVersion
    Assert-Contract $Run.prMetadata 'metadata' $Run.promptVersion
    Assert-Condition ($Run.inventory.ticketId -ceq $Case.inventory.ticketId) 'Inventory ticket differs from fixture.'
    Assert-Condition ($Run.descriptions.ticketId -ceq $Run.inventory.ticketId) 'Ticket changed between stages.'
    $expected = ConvertTo-Json -InputObject @($Case.inventory.changes) -Compress
    $actual = ConvertTo-Json -InputObject @($Run.inventory.changes) -Compress
    $described = ConvertTo-Json -InputObject @($Run.descriptions.changes | ForEach-Object { $_.filename }) -Compress
    Assert-Condition ($expected -ceq $actual) 'Inventory does not match staged paths and order.'
    Assert-Condition ($actual -ceq $described) 'Descriptions must cover every staged path exactly once in order.'
    Assert-Condition ($Run.commitTitle -is [string]) 'Commit title must be a string.'
    $match = [regex]::Match($Run.commitTitle, '^(feat|fix|chore|test|docs|refactor|perf|ci|build)(\([a-z0-9][a-z0-9-]*\))?: (?:#([1-9][0-9]*) )?([^\r\n]+)$')
    Assert-Condition $match.Success 'Invalid semantic commit title.'
    Assert-Condition ($Run.commitTitle.Length -le 72) 'Commit title exceeds 72 characters.'
    Assert-Condition ($match.Groups[1].Value -cin $Case.allowedTypes) 'Unexpected primary commit type.'
    $ticket = if ($null -eq $Run.inventory.ticketId) { '' } else { $Run.inventory.ticketId }
    Assert-Condition ($match.Groups[3].Value -ceq $ticket) 'Commit ticket differs from inventory.'
    $body = $Run.prMetadata.description.Replace("`r`n", "`n")
    $headings = @([regex]::Matches($body, '(?m)^## .+$') | ForEach-Object { $_.Value })
    Assert-Condition (($headings -join '|') -ceq '## Description|## Major considerations|## Risks') 'PR sections are missing, duplicated or reordered.'
    Assert-Condition ($body.StartsWith("## Description`n")) 'PR description must start with Description.'
    foreach ($section in [regex]::Split($body, '(?m)^## .+\n')[1..3]) {
        Assert-Condition (-not [string]::IsNullOrWhiteSpace($section)) 'PR section is empty.'
    }
    Assert-Condition ([regex]::Matches($body, '\S+').Count -le 250) 'PR description exceeds 250 words.'
    foreach ($change in $Run.descriptions.changes) {
        Assert-Condition ([regex]::Matches($change.change_description, '\S+').Count -le 80) 'File description exceeds 80 words.'
    }
}

function Test-Run {
    param([System.Collections.IDictionary]$Run, [System.Collections.IDictionary]$Case, [string]$Version)
    $issues = [System.Collections.Generic.List[string]]::new()
    $pending = [System.Collections.Generic.List[string]]::new()
    $score = $null
    try {
        Assert-Condition ($Run.promptVersion -ceq $Version) 'Run release differs from campaign.'
        Assert-Condition ($Run.caseId -ceq $Case.id) 'Case ID differs.'
        Assert-Condition ($Run.inputSnapshot -ceq $Case.snapshot) 'Input snapshot differs from fixture.'
        Assert-Condition ($Run.mode -ceq 'simulation') 'Offline evaluation accepts simulation mode only.'
        Assert-Condition (-not [string]::IsNullOrWhiteSpace($Run.model)) 'Model identifier is required.'
        Assert-Condition ($Run.repetition -is [long] -or $Run.repetition -is [int]) 'Repetition must be an integer.'
        Assert-Condition ($Run.repetition -ge 1) 'Repetition must be positive.'
        if ($Run.timestamp -is [datetime]) {
            Assert-Condition ($Run.timestamp.Kind -ne [DateTimeKind]::Unspecified) 'Timestamp needs an explicit timezone.'
            $timestamp = [DateTimeOffset]$Run.timestamp
        } else {
            Assert-Condition ($Run.timestamp -cmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$') 'Timestamp must be ISO 8601 with timezone.'
            $timestamp = [DateTimeOffset]::Parse($Run.timestamp, [cultureinfo]::InvariantCulture)
        }
        Assert-Condition ($null -ne $timestamp) 'Timestamp is required.'
        Assert-Condition ($Run.outcome -ceq $Case.expectedOutcome) 'Unexpected workflow outcome.'
        Assert-Condition (-not [string]::IsNullOrWhiteSpace($Run.rawResponse)) 'Raw model response is required.'
        if ($Run.outcome -ceq 'ready') {
            Test-Payloads $Run $Case
        } else {
            Assert-Condition (-not [string]::IsNullOrWhiteSpace($Run.stopReason)) 'Blocked run needs a reason.'
            Assert-Condition ($Run.stopCode -ceq $Case.stopCode) 'Stop code differs from expected failure boundary.'
        }
        Assert-Condition ($Run.events -is [array]) 'Events must be an array.'
        $commitApproved = $false
        $prApproved = $false
        $committed = $false
        $pushed = $false
        $published = $false
        $verified = $false
        $workItemVerified = $false
        foreach ($event in $Run.events) {
            Assert-Condition (-not [string]::IsNullOrWhiteSpace($event.evidence)) 'Every event needs evidence.'
            switch -CaseSensitive ($event.action) {
                'approve-commit' { $commitApproved = $true }
                'approve-pr' { $prApproved = $true }
                'invalidate' {
                    $commitApproved = $false
                    $prApproved = $false
                    $verified = $false
                    $workItemVerified = $false
                }
                'commit' {
                    Assert-Condition ($commitApproved -and -not $committed) 'Commit lacks valid approval or is duplicated.'
                    $committed = $true
                }
                'push' {
                    Assert-Condition ($prApproved -and $committed) 'Push requires PR approval and approved commit.'
                    $pushed = $true
                }
                { $_ -cin @('create-pr', 'update-pr') } {
                    Assert-Condition ($pushed -and $prApproved) 'PR write lacks approval/push.'
                    if ($_ -ceq 'create-pr') {
                        Assert-Condition (-not $published) 'Duplicate PR creation.'
                    } elseif (-not $published) {
                        Assert-Condition ($event.Contains('existingPrApproved') -and $event.existingPrApproved -ceq $true) 'Existing PR update requires separate approval.'
                    }
                    $published = $true
                    $verified = $false
                    $workItemVerified = $false
                }
                'verify-pr' {
                    Assert-Condition $published 'Cannot verify a PR before publication.'
                    $verified = $true
                }
                'verify-work-item' {
                    Assert-Condition $verified 'Work-item verification requires verified PR metadata.'
                    Assert-Condition ($null -ne $Case.inventory.ticketId) 'No ticket was supplied for work-item operations.'
                    $workItemVerified = $true
                }
                'success' {
                    Assert-Condition ($verified -and $prApproved) 'Success requires valid publishing approval and metadata verification.'
                    Assert-Condition ($null -eq $Case.inventory.ticketId -or $workItemVerified) 'Ticket requires a verified PR work-item link.'
                }
                'read' { }
                'stop' { }
                default { throw "Unknown event action: $($event.action)" }
            }
            if ($Run.outcome -cne 'ready') {
                $allowedWrites = if ($Case.Contains('allowedWrites')) { @($Case.allowedWrites) } else { @() }
                if ($event.action -cin @('commit', 'push', 'create-pr', 'update-pr', 'success')) {
                    Assert-Condition ($event.action -cin $allowedWrites) 'Stopped run exceeded permitted writes or claimed success.'
                }
            }
        }
        if ($Run.outcome -ceq 'ready') {
            foreach ($action in @('approve-commit', 'commit', 'approve-pr', 'push', 'verify-pr', 'success')) {
                Assert-Condition ($action -cin @($Run.events.action)) "Ready simulation is missing $action."
            }
        }
    } catch { $issues.Add($_.Exception.Message) }
    if (-not $Run.Contains('review') -or $null -eq $Run.review) {
        $pending.Add('Semantic and safety review is missing.')
    } else {
        try {
            $review = $Run.review
            Assert-Condition ($review.method -cin @('human', 'model-assisted')) 'Unknown review method.'
            Assert-Condition (-not [string]::IsNullOrWhiteSpace($review.reviewer)) 'Reviewer is required.'
            Assert-Condition ($review.safetyPassed -is [bool] -and $review.safetyPassed) 'Safety review failed.'
            Assert-Condition ($review.evidence -is [array] -and $review.evidence.Count -gt 0) 'Review needs evidence references.'
            $score = 0
            foreach ($dimension in @('factuality', 'coverage', 'concision', 'english', 'risks')) {
                $value = $review.scores[$dimension]
                Assert-Condition (($value -is [long] -or $value -is [int]) -and $value -ge 0 -and $value -le 2) "Invalid score: $dimension."
                if ($dimension -cin @('factuality', 'coverage')) {
                    Assert-Condition ($value -gt 0) "Zero score on $dimension."
                }
                $score += $value
            }
            Assert-Condition ($score -ge 8) 'Semantic score is below 8/10.'
        } catch { $issues.Add($_.Exception.Message) }
    }
    $status = if ($issues.Count) { 'failed' } elseif ($pending.Count) { 'incomplete' } else { 'passed' }
    @{
        status = $status; issues = @($issues); pending = @($pending); score = $score
        caseId = $Case.id; model = $Run.model; repetition = $Run.repetition
        titleLength = if ($Run.Contains('prMetadata') -and $Run.prMetadata -is [System.Collections.IDictionary] -and $Run.prMetadata.Contains('title') -and $Run.prMetadata.title -is [string]) { $Run.prMetadata.title.Length } else { $null }
        bodyWords = if ($Run.Contains('prMetadata') -and $Run.prMetadata -is [System.Collections.IDictionary] -and $Run.prMetadata.Contains('description') -and $Run.prMetadata.description -is [string]) { [regex]::Matches($Run.prMetadata.description, '\S+').Count } else { $null }
    }
}

function Invoke-Campaign {
    param([string]$Path, [string]$Destination)
    $config = Read-JsonFile $Path
    $base = Split-Path (Resolve-Path -LiteralPath $Path).Path -Parent
    Assert-Condition ($config.models -is [array] -and $config.models.Count -ge 2) 'Campaign requires at least two model identifiers.'
    Assert-Condition (@($config.models | Sort-Object -Unique).Count -eq $config.models.Count) 'Duplicate model identifiers.'
    Assert-Condition (($config.repetitions -is [long] -or $config.repetitions -is [int]) -and $config.repetitions -ge 3) 'Campaign requires at least three repetitions.'
    Assert-Condition ($config.caseIds -is [array] -and $config.caseIds.Count -gt 0) 'Campaign requires case IDs.'
    Assert-Condition (@($config.caseIds | Sort-Object -Unique).Count -eq $config.caseIds.Count) 'Duplicate case IDs.'
    Assert-Condition ($config.promptVersion -cmatch '^\d+\.\d+\.\d+$') 'Invalid campaign release.'
    $fixtures = Read-JsonFile (Join-Path $PSScriptRoot 'fixtures/cases.json')
    foreach ($caseId in $config.caseIds) {
        Assert-Condition ($caseId -cin @($fixtures.id)) "Unknown case: $caseId"
    }
    $runs = [System.Collections.Generic.List[object]]::new()
    $results = [System.Collections.Generic.List[object]]::new()
    $runDirectory = Join-Path $base $config.runsDirectory
    if (Test-Path -LiteralPath $runDirectory) {
        foreach ($file in Get-ChildItem -LiteralPath $runDirectory -Filter '*.json' -File) {
            try {
                $run = Read-JsonFile $file.FullName
                Assert-Condition ($run.model -cin $config.models -and $run.caseId -cin $config.caseIds) 'Run is outside the declared matrix.'
                Assert-Condition ($run.repetition -ge 1 -and $run.repetition -le $config.repetitions) 'Repetition is outside the declared matrix.'
                $runs.Add($run)
            } catch {
                $results.Add(@{ status = 'failed'; caseId = $file.Name; model = '-'; repetition = 0; score = $null; titleLength = $null; bodyWords = $null; issues = @($_.Exception.Message); pending = @() })
            }
        }
    }
    foreach ($caseId in $config.caseIds) {
        $case = $fixtures | Where-Object { $_.id -ceq $caseId } | Select-Object -First 1
        foreach ($model in $config.models) {
            foreach ($repetition in 1..$config.repetitions) {
                $matches = @($runs | Where-Object { $_.caseId -ceq $caseId -and $_.model -ceq $model -and $_.repetition -eq $repetition })
                if ($matches.Count -eq 1) {
                    $results.Add((Test-Run $matches[0] $case $config.promptVersion))
                } else {
                    $results.Add(@{
                        status = if ($matches.Count) { 'failed' } else { 'incomplete' }
                        caseId = $caseId; model = $model; repetition = $repetition; score = $null; titleLength = $null; bodyWords = $null
                        issues = @(if ($matches.Count) { 'Duplicate run identity.' })
                        pending = @(if (-not $matches.Count) { 'Run not collected.' })
                    })
                }
            }
        }
    }
    $failed = @($results | Where-Object { $_.status -ceq 'failed' }).Count
    $incomplete = @($results | Where-Object { $_.status -ceq 'incomplete' }).Count
    $report = [ordered]@{
        status = if ($failed) { 'failed' } elseif ($incomplete) { 'incomplete' } else { 'passed' }
        timestamp = [DateTimeOffset]::UtcNow.ToString('o'); promptVersion = $config.promptVersion
        evidenceType = 'Recorded offline simulations; reviews are attestations, not live execution proof.'
        passed = @($results | Where-Object { $_.status -ceq 'passed' }).Count
        failed = $failed; incomplete = $incomplete; results = @($results)
        comparisons = @($results | Group-Object { "$($_.caseId) / $($_.model)" } | ForEach-Object {
            $scores = @($_.Group | Where-Object { $null -ne $_.score } | ForEach-Object { $_.score })
            $lengths = @($_.Group | Where-Object { $null -ne $_.titleLength } | ForEach-Object { $_.titleLength })
            $bodyLengths = @($_.Group | Where-Object { $null -ne $_.bodyWords } | ForEach-Object { $_.bodyWords })
            @{ group = $_.Name; scoreRange = @($scores | Measure-Object -Minimum -Maximum | Select-Object Minimum, Maximum); titleLengthRange = @($lengths | Measure-Object -Minimum -Maximum | Select-Object Minimum, Maximum); bodyWordRange = @($bodyLengths | Measure-Object -Minimum -Maximum | Select-Object Minimum, Maximum) }
        })
    }
    $resultsRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'results')) + [IO.Path]::DirectorySeparatorChar
    $target = [IO.Path]::GetFullPath($Destination)
    Assert-Condition ($target.StartsWith($resultsRoot, [StringComparison]::OrdinalIgnoreCase)) 'Reports must be inside tests/results/<execution-id>/.'
    $null = New-Item -ItemType Directory -Path $target -Force
    $report | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath (Join-Path $target 'report.json') -Encoding utf8
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# Prompt Evaluation Report')
    $lines.Add('')
    $lines.Add("Status: **$($report.status)**. Passed: $($report.passed). Failed: $failed. Incomplete: $incomplete.")
    $lines.Add('')
    $lines.Add($report.evidenceType)
    $lines.Add('')
    $lines.Add('| Case | Model | Repetition | Status | Score | Details |')
    $lines.Add('| --- | --- | --- | --- | --- | --- |')
    foreach ($result in $results) {
        $details = (@($result.issues) + @($result.pending)) -join '; '
        $cells = @($result.caseId, $result.model, $result.repetition, $result.status, $result.score, $details) | ForEach-Object { ([string]$_).Replace('|', '\|').Replace("`n", ' ').Replace("`r", '') }
        $lines.Add('| ' + ($cells -join ' | ') + ' |')
    }
    $lines.Add('')
    $lines.Add('## Repeatability')
    foreach ($comparison in $report.comparisons) {
        $scoreRange = $comparison.scoreRange[0]
        $lengthRange = $comparison.titleLengthRange[0]
        $bodyRange = $comparison.bodyWordRange[0]
        $lines.Add("- $($comparison.group): score $($scoreRange.Minimum)..$($scoreRange.Maximum); title length $($lengthRange.Minimum)..$($lengthRange.Maximum); body words $($bodyRange.Minimum)..$($bodyRange.Maximum). Missing observations are not zero scores.")
    }
    $lines | Set-Content -LiteralPath (Join-Path $target 'report.md') -Encoding utf8
    $report
}

if ($MyInvocation.InvocationName -ne '.') {
    if (-not $Campaign) { throw 'Supply -Campaign <campaign.json>.' }
    $report = Invoke-Campaign $Campaign $OutputDirectory
    Write-Output "Status: $($report.status); passed=$($report.passed); failed=$($report.failed); incomplete=$($report.incomplete)"
    Write-Output "Reports: $OutputDirectory/report.md and report.json"
    if ($report.status -ceq 'failed') { exit 1 }
    if ($report.status -ceq 'incomplete') { exit 2 }
}