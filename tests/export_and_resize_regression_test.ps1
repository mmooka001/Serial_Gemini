$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$qmlPath = Join-Path $root "Main.qml"
$qml = Get-Content -Raw -Encoding UTF8 $qmlPath

function Assert-Contains {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$Message
    )

    if ($Text -notmatch $Pattern) {
        throw $Message
    }
}

Assert-Contains $qml 'import\s+QtCore' "Main.qml must import QtCore so FileDialog defaults can use StandardPaths."
Assert-Contains $qml 'Qt\.formatDateTime\(new Date\(\),\s*"yyyyMMddhhmmss"\)' "Export filenames must include a yyyyMMddhhmmss timestamp."

$commandPrefix = "$([char]0x6307)$([char]0x4EE4) "
$recordPrefix = "$([char]0x5BF9)$([char]0x8BDD)$([char]0x8BB0)$([char]0x5F55) "
Assert-Contains $qml ('"' + [regex]::Escape($commandPrefix) + '"\s*\+\s*exportTimestamp\(\)\s*\+\s*"\.json"') "Command export default name must use the required Chinese prefix and .json extension."
Assert-Contains $qml ('"' + [regex]::Escape($recordPrefix) + '"\s*\+\s*exportTimestamp\(\)\s*\+\s*"\.csv"') "Record export default name must use the required Chinese prefix and .csv extension."
Assert-Contains $qml 'exportFileDialog\.currentFile\s*=\s*defaultExportFileUrl\(commandExportFileName\(\)\)' "Command export dialog must refresh its default filename before opening."
Assert-Contains $qml 'exportRecordDialog\.currentFile\s*=\s*defaultExportFileUrl\(recordExportFileName\(\)\)' "Record export dialog must refresh its default filename before opening."
Assert-Contains $qml 'commandStore\.exportToFile\(selectedFile\.toString\(\)\)' "Command export must pass the FileDialog URL directly to C++."
Assert-Contains $qml 'commandStore\.importFromFile\(selectedFile\.toString\(\)\)' "Command import must pass the FileDialog URL directly to C++."

if ($qml -match 'commandStore\.(?:exportToFile|importFromFile)\(selectedFile\.toString\(\)\.replace') {
    throw "Command import/export must not strip file:/// from selectedFile before passing it to C++."
}

Assert-Contains $qml 'id:\s*terminalSendResizeHandle' "Terminal/send resize handle is missing."
Assert-Contains $qml 'readonly property int terminalSendGap:\s*15' "Terminal/send gap must match the existing 15px component spacing."
Assert-Contains $qml 'id:\s*centerColumn[\s\S]*?spacing:\s*0' "Center column spacing must be 0 so the resize handle does not add extra stacked gaps."
Assert-Contains $qml 'id:\s*terminalSendResizeHandle\s+Layout\.fillWidth:\s*true\s+Layout\.preferredHeight:\s*terminalSendGap' "Resize handle must use one 15px gap as the drag area."
Assert-Contains $qml 'cursorShape:\s*Qt\.SizeVerCursor' "Resize handle must use a vertical resize cursor."
Assert-Contains $qml 'Layout\.preferredHeight:\s*sendPanelHeight' "Send panel height must be controlled by the resize state."
Assert-Contains $qml 'sendPanelHeight\s*=\s*Math\.max\(minSendPanelHeight,\s*Math\.min\(maxSendPanelHeight,' "Resize handle must clamp send panel height."

$handleStart = $qml.IndexOf("id: terminalSendResizeHandle")
$sendCardStart = $qml.IndexOf("id: sendCard", $handleStart)
if ($handleStart -lt 0 -or $sendCardStart -lt 0) {
    throw "Could not locate the terminal/send resize handle block."
}

$handleBlock = $qml.Substring($handleStart, $sendCardStart - $handleStart)
if ($handleBlock -match 'width:\s*44[\s\S]*?height:\s*3') {
    throw "Resize handle must not draw an extra visible horizontal bar."
}

Write-Host "Export defaults and terminal/send resize regression checks passed."
