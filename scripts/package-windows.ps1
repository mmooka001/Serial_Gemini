param(
    [Parameter(Mandatory = $true)][string]$QtRoot,
    [Parameter(Mandatory = $true)][string]$CompilerBin,
    [string]$NinjaExecutable = 'ninja'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$QtRoot = (Resolve-Path -LiteralPath $QtRoot).Path
$CompilerBin = (Resolve-Path -LiteralPath $CompilerBin).Path
$env:PATH = "$QtRoot\bin;$CompilerBin;$env:PATH"
$cmake = (Get-Command cmake -ErrorAction Stop).Source
$ninja = (Get-Command $NinjaExecutable -ErrorAction Stop).Source
$deployTool = Join-Path $QtRoot 'bin/windeployqt.exe'
$projectText = Get-Content -LiteralPath (Join-Path $projectRoot 'CMakeLists.txt') -Raw
$version = [regex]::Match($projectText, 'project\(MySerial_Gemini VERSION ([0-9.]+)').Groups[1].Value
if (-not $version) { throw 'Cannot read project version.' }

$packageName = "Gemini-Serial-v$version-win64"
$buildDirectory = Join-Path $projectRoot "build_release/v$version"
$stageDirectory = Join-Path $projectRoot "release_staging/$packageName"
$artifactDirectory = Join-Path $projectRoot 'release_artifacts'
$archive = Join-Path $artifactDirectory "$packageName.zip"
if ((Test-Path -LiteralPath $stageDirectory) -or (Test-Path -LiteralPath $archive)) {
    throw 'Release output already exists; use a new version or archive the existing output first.'
}

& $cmake -S $projectRoot -B $buildDirectory -G Ninja "-DCMAKE_MAKE_PROGRAM=$ninja" `
    "-DCMAKE_PREFIX_PATH=$QtRoot" -DCMAKE_BUILD_TYPE=Release
if ($LASTEXITCODE -ne 0) { throw 'Release configure failed.' }
& $cmake --build $buildDirectory --parallel 6
if ($LASTEXITCODE -ne 0) { throw 'Release build failed.' }

New-Item -ItemType Directory -Path $stageDirectory, $artifactDirectory -Force | Out-Null
$executable = Join-Path $stageDirectory 'GeminiSerial.exe'
Copy-Item -LiteralPath (Join-Path $buildDirectory 'MySerial_Gemini.exe') -Destination $executable

# Scan production QML only, without traversing old builds, releases or tests.
$qmlInputs = Join-Path $buildDirectory 'deployment-qml-inputs'
New-Item -ItemType Directory -Path $qmlInputs -Force | Out-Null
Get-ChildItem -LiteralPath $projectRoot -Filter '*.qml' -File | Copy-Item -Destination $qmlInputs
& $deployTool --release --compiler-runtime --translations zh_CN,zh_TW `
    --skip-plugin-types qmltooling,generic --exclude-plugins qopensslbackend `
    --qmldir $qmlInputs --dir $stageDirectory $executable
if ($LASTEXITCODE -ne 0) { throw 'Qt deployment failed.' }

Copy-Item -LiteralPath (Join-Path $projectRoot 'LICENSE') -Destination $stageDirectory
Copy-Item -LiteralPath (Join-Path $projectRoot "docs/RELEASE_NOTES_v$version.md") `
    -Destination (Join-Path $stageDirectory 'RELEASE_NOTES.md')
$utf8 = [Text.UTF8Encoding]::new($false)
$readme = @"
Gemini Serial v$version - Windows x64

完整解压后运行 GeminiSerial.exe，无需安装 Qt。
请保留附带的 DLL、qml 和 platforms 等目录，不要只复制 EXE。

长按左侧导航约 0.3 秒后可滑动切换；主题按钮可调整明暗及强调色。
指令与配置保存在系统应用数据目录，升级时沿用已有数据。

项目：https://github.com/mmooka001/Serial_Gemini
更新内容：RELEASE_NOTES.md
应用许可证：LICENSE
Qt 和编译器运行库说明：THIRD_PARTY_NOTICES.txt、licenses/
"@
[IO.File]::WriteAllText((Join-Path $stageDirectory 'README.txt'), $readme, $utf8)

$qtLicenses = Join-Path (Split-Path (Split-Path $QtRoot -Parent) -Parent) 'Licenses'
if (-not (Test-Path -LiteralPath (Join-Path $qtLicenses 'LICENSE'))) { throw 'Qt license texts not found.' }
$licenseDirectory = Join-Path $stageDirectory 'licenses'
New-Item -ItemType Directory -Path $licenseDirectory -Force | Out-Null
Copy-Item -LiteralPath $qtLicenses -Destination (Join-Path $licenseDirectory 'Qt') -Recurse
foreach ($runtime in @('gcc', 'mingw-w64', 'winpthreads')) {
    $runtimeLicenses = Join-Path (Split-Path $CompilerBin -Parent) "licenses/$runtime"
    Copy-Item -LiteralPath $runtimeLicenses -Destination (Join-Path $licenseDirectory $runtime) -Recurse
}
$qtVersion = (& (Join-Path $QtRoot 'bin/qtpaths.exe') --qt-version).Trim()
$licenseTexts = [Collections.Generic.List[string]]::new()
$seenLicenses = @{}
foreach ($module in @('qtbase', 'qtdeclarative', 'qtserialport', 'qtsvg', 'qttranslations')) {
    $sbomFile = Join-Path $QtRoot "sbom/$module-$qtVersion.spdx.json"
    if (-not (Test-Path -LiteralPath $sbomFile)) { throw "Qt license metadata missing: $module" }
    $sbom = Get-Content -LiteralPath $sbomFile -Raw | ConvertFrom-Json
    foreach ($license in $sbom.hasExtractedLicensingInfos) {
        $licenseKey = $license.licenseId + "`n" + $license.extractedText
        if ($license.extractedText -and -not $seenLicenses.ContainsKey($licenseKey)) {
            $seenLicenses[$licenseKey] = $true
            $licenseTexts.Add("$($license.licenseId)`r`n$($license.extractedText)")
        }
    }
}
[IO.File]::WriteAllText((Join-Path $licenseDirectory 'Qt/THIRD_PARTY_LICENSES.txt'),
    ($licenseTexts -join "`r`n`r`n----------------------------------------`r`n`r`n"), $utf8)
$notices = @"
Gemini Serial is distributed under the MIT license; see LICENSE.

Qt $qtVersion is dynamically linked. Qt license texts, including LGPLv3/GPLv3,
and extracted third-party license notices are supplied in licenses/Qt/.
Qt source: https://download.qt.io/official_releases/qt/$($qtVersion.Substring(0, $qtVersion.LastIndexOf('.')))/$qtVersion/single/
Qt project: https://www.qt.io/licensing/open-source-lgpl-obligations

MinGW GCC runtime, MinGW-w64 and winpthreads license texts are supplied in
licenses/gcc/, licenses/mingw-w64/ and licenses/winpthreads/.
The package includes the dynamically linked runtime DLLs so they can be replaced.
"@
[IO.File]::WriteAllText((Join-Path $stageDirectory 'THIRD_PARTY_NOTICES.txt'), $notices, $utf8)

$requiredFiles = @('GeminiSerial.exe', 'Qt6Core.dll', 'Qt6Gui.dll', 'Qt6Quick.dll',
    'Qt6SerialPort.dll', 'platforms/qwindows.dll', 'libgcc_s_seh-1.dll',
    'libstdc++-6.dll', 'libwinpthread-1.dll', 'qml/QtQuick/Effects/qmldir')
foreach ($relativePath in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $stageDirectory $relativePath))) {
        throw "Missing runtime file: $relativePath"
    }
}
$unexpected = Get-ChildItem -LiteralPath $stageDirectory -File -Recurse | Where-Object {
    $_.Extension -in @('.pdb', '.log', '.cpp', '.h', '.ps1') -or $_.Name -in @('commands.json', 'stdout.txt', 'stderr.txt')
}
if ($unexpected) { throw 'Unexpected development or private files in release package.' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($stageDirectory, $archive,
    [IO.Compression.CompressionLevel]::Optimal, $true)
$sha256 = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText("$archive.sha256", "$sha256  $packageName.zip`n", $utf8)
[pscustomobject]@{
    Version = $version
    Archive = $archive
    Bytes = (Get-Item -LiteralPath $archive).Length
    Files = (Get-ChildItem -LiteralPath $stageDirectory -Recurse -File).Count
    SHA256 = $sha256
}
