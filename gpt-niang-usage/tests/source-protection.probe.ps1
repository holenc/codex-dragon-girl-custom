param([string]$AppDir)
$ErrorActionPreference='Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'runtime\update-common.ps1')
Get-WidgetSourceProtection $AppDir|ConvertTo-Json -Compress
