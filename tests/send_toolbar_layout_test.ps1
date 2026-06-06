$ErrorActionPreference = "Stop"

$qmlPath = Join-Path $PSScriptRoot "..\Main.qml"
$qml = Get-Content -LiteralPath $qmlPath -Raw -Encoding UTF8

$requiredPatterns = [ordered]@{
    "send card width visibility source" = "readonly property bool showChecksumControl: sendCard.width >= "
    "auto control follows checksum" = "readonly property bool showAutoControl: sendCard.width >= "
    "time control follows auto" = "readonly property bool showTimeControl: sendCard.width >= "
    "tx control follows time" = "readonly property bool showTxModeControl: sendCard.width >= "
    "rx control is last" = "readonly property bool showRxModeControl: sendCard.width >= "
    "center column clipping" = "id: centerColumn"
    "center column may shrink" = "Layout.minimumWidth: 0"
    "send card clipping" = "id: sendCard"
    "checksum wrapper" = "id: checksumControl"
    "auto wrapper" = "id: autoControl"
    "time wrapper" = "id: timeControl"
    "tx wrapper" = "id: txModeControl"
    "rx wrapper" = "id: rxModeControl"
    "animated wrapper width" = "Behavior on Layout.preferredWidth"
    "animated wrapper opacity" = "Behavior on opacity"
    "fixed send button width" = "id: sendBtn"
}

$missing = @()
foreach ($entry in $requiredPatterns.GetEnumerator()) {
    if (-not $qml.Contains($entry.Value)) {
        $missing += "$($entry.Key): $($entry.Value)"
    }
}

$orderNames = @(
    "showChecksumControl",
    "showAutoControl",
    "showTimeControl",
    "showTxModeControl",
    "showRxModeControl"
)
$positions = $orderNames | ForEach-Object { $qml.IndexOf("readonly property bool $_") }
for ($i = 0; $i -lt $positions.Count; $i++) {
    if ($positions[$i] -lt 0) {
        continue
    }
    if ($i -gt 0 -and $positions[$i] -le $positions[$i - 1]) {
        $missing += "visibility properties are not declared in the required hide order"
        break
    }
}

if ($qml -notmatch "id:\s*sendBtn[\s\S]{0,160}Layout\.preferredWidth:\s*60") {
    $missing += "sendBtn must keep Layout.preferredWidth: 60"
}

if ($qml -notmatch "id:\s*sendCard[\s\S]{0,500}clip:\s*true") {
    $missing += "sendCard must clip its contents"
}

if ($qml -notmatch "id:\s*centerColumn[\s\S]{0,220}clip:\s*true") {
    $missing += "centerColumn must clip its contents"
}

if ($missing.Count -gt 0) {
    Write-Error ("FAIL: responsive send toolbar requirements missing:`n - " + ($missing -join "`n - "))
}

Write-Output "PASS: send toolbar responsive layout checks"
