param(
    [Parameter(Mandatory=$true)]
    [string]$ScriptPath,
    [string[]]$ExtraArgs = @(),
    [int]$TimeoutSeconds = 30
)
# Compatibility entry point: never run QA against the player's project/save location.
$ErrorActionPreference = 'Stop'
try {
    & (Join-Path $PSScriptRoot 'verify_town_doors.ps1') -Checks @($ScriptPath) -UserArguments $ExtraArgs -TimeoutSeconds $TimeoutSeconds
    exit 0
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
