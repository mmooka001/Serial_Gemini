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

Assert-Contains $qml 'property var portList:\s*\[\]' "Startup must use a cached portList model instead of synchronously enumerating ports in bindings."
Assert-Contains $qml 'function refreshPorts\(\)[\s\S]*?portList\s*=\s*serialManager\.availablePorts\(\)' "Port refresh must be centralized in refreshPorts()."
Assert-Contains $qml 'id:\s*startupPortRefreshTimer[\s\S]*?interval:\s*200[\s\S]*?repeat:\s*false[\s\S]*?onTriggered:\s*refreshPorts\(\)' "Port enumeration must be delayed until after initial UI creation."
Assert-Contains $qml 'id:\s*portCombo[\s\S]*?model:\s*portList' "Port ComboBox must bind to cached portList."
Assert-Contains $qml 'onClicked:\s*refreshPorts\(\)' "Refresh button must reuse refreshPorts()."
Assert-Contains $qml 'Component\.onCompleted:[\s\S]*?startupPortRefreshTimer\.start\(\)' "Startup port refresh timer must be started after component completion."

$portComboStart = $qml.IndexOf("id: portCombo")
if ($portComboStart -lt 0) {
    throw "Could not locate portCombo."
}

$portComboEnd = $qml.IndexOf("ComboBox", $portComboStart + 1)
if ($portComboEnd -lt 0) {
    $portComboEnd = $qml.IndexOf("ColumnLayout", $portComboStart)
}
if ($portComboEnd -lt 0) {
    $portComboEnd = [Math]::Min($qml.Length, $portComboStart + 2000)
}

$portComboBlock = $qml.Substring($portComboStart, $portComboEnd - $portComboStart)
if ($portComboBlock -match 'serialManager\.availablePorts\(\)') {
    throw "portCombo must not synchronously call serialManager.availablePorts() during startup binding."
}

Write-Host "Startup performance regression checks passed."
