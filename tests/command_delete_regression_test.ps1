$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$qmlPath = Join-Path $root "Main.qml"
$qml = Get-Content -Raw -Encoding UTF8 $qmlPath

$deleteTypeAssignments = [regex]::Matches($qml, 'deleteType\s*=\s*"([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
$deleteTypeChecks = [regex]::Matches($qml, 'deleteType\s*===\s*"([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique

foreach ($assignment in $deleteTypeAssignments) {
    if ($deleteTypeChecks -notcontains $assignment) {
        throw "deleteType value '$assignment' is assigned but never handled by the delete confirmation action."
    }
}

if ($qml -notmatch 'deleteType\s*=\s*"command"[\s\S]*?targetGroupIdx\s*=\s*groupIdx[\s\S]*?targetCmdIdx\s*=\s*cmdIdx') {
    throw "Command delete button must capture the current group and command indexes."
}

if ($qml -notmatch 'deleteType\s*===\s*"command"[\s\S]*?commandStore\.deleteCommand\(targetGroupIdx,\s*targetCmdIdx\)') {
    throw "Delete confirmation must call commandStore.deleteCommand() for command deletes."
}

Write-Host "Command delete regression checks passed."
