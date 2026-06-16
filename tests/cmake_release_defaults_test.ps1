$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$cmakePath = Join-Path $root "CMakeLists.txt"
$cmake = Get-Content -Raw -Encoding UTF8 $cmakePath

if ($cmake -notmatch 'if\s*\(\s*NOT\s+CMAKE_BUILD_TYPE\s+AND\s+NOT\s+CMAKE_CONFIGURATION_TYPES\s*\)') {
    throw "CMake must set a default build type only for single-config generators."
}

if ($cmake -notmatch 'set\s*\(\s*CMAKE_BUILD_TYPE\s+Release\s+CACHE\s+STRING\s+"Build type"\s+FORCE\s*\)') {
    throw "Single-config builds must default to Release for distributable startup performance."
}

Write-Host "CMake release default checks passed."
