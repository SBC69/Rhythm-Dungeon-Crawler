param(
    [string[]]$Checks = @(
        'res://tests/run_all.gd', 'res://tests/town_doors_regression.gd',
        'res://tests/town_doors_regression.gd::edges', 'res://tests/town_doors_regression.gd::village',
        'res://tests/town_doors_regression.gd::balance-ui', 'res://tests/town_doors_regression.gd::devices',
        'res://tests/town_doors_regression.gd::final',
        'res://tests/town_doors_regression.gd::write', 'res://tests/town_doors_regression.gd::read',
        'res://tests/town_doors_regression.gd::escape-write', 'res://tests/town_doors_regression.gd::escape-read',
        'res://tests/town_doors_regression.gd::legacy-write', 'res://tests/town_doors_regression.gd::legacy-read',
        'res://docs/qa/probe-town-and-doors-e2e.gd',
        'res://tests/town_door_paths.gd::0', 'res://tests/town_door_paths.gd::1', 'res://tests/town_door_paths.gd::2',
        'res://tests/town_door_paths.gd::3', 'res://tests/town_door_paths.gd::4', 'res://tests/town_door_paths.gd::5',
        'res://tests/town_door_paths.gd::6', 'res://tests/town_door_paths.gd::7', 'res://tests/town_door_paths.gd::8',
        'res://tests/town_doors_regression.gd::negative', 'res://tests/run_all.gd::negative',
        'res://docs/qa/probe-town-and-doors-e2e.gd::negative'
    ),
    [string[]]$UserArguments = @(),
    [switch]$CaptureVisuals,
    [string]$Engine = 'D:\godot\Godot_v4.5.1-stable_win64.exe',
    [int]$TimeoutSeconds = 45,
    [string]$AuditRoot = ''
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $AuditRoot) { $AuditRoot = Join-Path ([IO.Path]::GetTempPath()) ('game002-town-fix-' + [guid]::NewGuid().ToString('N').Substring(0, 8)) }
$AuditRoot = [IO.Path]::GetFullPath($AuditRoot)
if ($AuditRoot.StartsWith($projectRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'AuditRoot must be outside the source project' }
[void][IO.Directory]::CreateDirectory($AuditRoot)
foreach ($folder in @('scripts', 'scenes', 'assets', 'localization', 'tests', 'docs/qa')) {
    foreach ($sourceFile in Get-ChildItem -LiteralPath (Join-Path $projectRoot $folder) -File -Recurse) {
        if ($folder -eq 'docs/qa') {
            $ancestor = $sourceFile.DirectoryName
            $ignoredEvidence = $false
            while ($ancestor.StartsWith((Join-Path $projectRoot 'docs/qa'), [StringComparison]::OrdinalIgnoreCase)) {
                if (Test-Path -LiteralPath (Join-Path $ancestor '.gdignore')) { $ignoredEvidence = $true; break }
                $ancestor = [IO.Path]::GetDirectoryName($ancestor)
            }
            if ($ignoredEvidence) { continue }
        }
        $relativeFile = [IO.Path]::GetRelativePath($projectRoot, $sourceFile.FullName)
        $targetFile = Join-Path $AuditRoot $relativeFile
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($targetFile))
        Copy-Item -LiteralPath $sourceFile.FullName -Destination $targetFile -Force
    }
}
Copy-Item -LiteralPath (Join-Path $projectRoot 'project.godot') -Destination $AuditRoot -Force
# The storage location is replaced before any autoload is instantiated.
$storePath = Join-Path $AuditRoot 'scripts/persistence/save_store.gd'
$store = [IO.File]::ReadAllText($storePath).Replace('"user://saves"', '"' + (Join-Path $AuditRoot 'isolated-save').Replace('\', '/') + '"')
[IO.File]::WriteAllText($storePath, $store)
function Invoke-IsolatedGodot([string]$Name, [string[]]$EngineArguments, [bool]$Render = $false, [bool]$ExpectFailure = $false) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $Engine
    $start.Environment["APPDATA"] = (Join-Path $AuditRoot "appdata")
    $start.Environment["LOCALAPPDATA"] = (Join-Path $AuditRoot "localappdata")
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $displayArguments = @('--display-driver', 'windows', '--rendering-method', 'gl_compatibility', '--position', '-32000,-32000')
    if (-not $Render) { $displayArguments = @('--headless') }
    foreach ($argument in $displayArguments + @('--disable-crash-handler', '--path', $AuditRoot, '--log-file', (Join-Path $AuditRoot ($Name + '.engine.log'))) + $EngineArguments) { $start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $sampledPeak = 0L
    $finished = $false
    while ($watch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        if ($process.WaitForExit(100)) { $finished = $true; break }
        $process.Refresh()
        $sampledPeak = [Math]::Max($sampledPeak, $process.WorkingSet64)
    }
    if (-not $finished) { $process.Kill($true); $process.WaitForExit() }
    $out = $stdout.GetAwaiter().GetResult()
    $err = $stderr.GetAwaiter().GetResult()
    [IO.File]::WriteAllText((Join-Path $AuditRoot ($Name + '.stdout.txt')), $out)
    [IO.File]::WriteAllText((Join-Path $AuditRoot ($Name + '.stderr.txt')), $err)
    $peakMB = [Math]::Round($sampledPeak / 1MB, 1)
    $code = $process.ExitCode
    $process.Dispose()
    Write-Output "$Name exit=$code timeout=$(-not $finished) sampledPeakWorkingSetMB=$peakMB"
    Write-Output $out
    if ($err) { Write-Output $err }
    if ($ExpectFailure) {
        if (-not $finished -or $code -ne 1 -or $out -match 'ALL .*PASSED|STATUS: SUCCESS' -or ($out + $err) -match 'SCRIPT ERROR:') { throw "Negative canary did not fail correctly: $Name" }
        Write-Output "NEGATIVE CANARY VERIFIED: $Name"
        return
    }
    if (-not $finished -or $code -ne 0 -or ($out + $err) -match '(?m)SCRIPT ERROR:|^\[FAIL\]|^FAIL:|^ERROR:.*(Parse|CSV|locale)') { throw "Check failed: $Name; evidence: $AuditRoot" }
}
Write-Output "EVIDENCE: $AuditRoot"
Invoke-IsolatedGodot 'import' @('--editor', '--import', '--quit')
if ($CaptureVisuals) { $Checks += 'res://tests/town_visual_check.gd' }
$index = 0
foreach ($check in $Checks) {
    $index++
    $parts = $check.Split('::')
    $arguments = @('--script', $parts[0])
    if ($parts[0] -eq 'res://tests/run_all.gd') {
        if ($parts.Length -gt 1 -and $parts[1] -eq 'negative') { $arguments += @('--', '--case', 'FAIL-INTENTIONAL', '--strict') }
        else { $arguments += @('--', '--all', '--strict') }
    }
    elseif ($parts.Length -gt 1) { $arguments += @('--', ('--mode=' + $parts[1])) }
    if ($UserArguments.Count -gt 0) {
        if ($arguments -notcontains '--') { $arguments += '--' }
        $arguments += $UserArguments
    }
    Invoke-IsolatedGodot "check-$index" $arguments ($parts[0] -eq 'res://tests/town_visual_check.gd') ($parts.Length -gt 1 -and $parts[1] -eq 'negative')
}
