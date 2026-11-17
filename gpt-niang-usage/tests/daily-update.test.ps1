$ErrorActionPreference='Stop'
. ([ScriptBlock]::Create([IO.File]::ReadAllText((Join-Path (Split-Path $PSScriptRoot -Parent) 'runtime\update-ui.ps1'),[Text.Encoding]::UTF8)))
$checks=0
function Assert($Value,$Name){if(!$Value){throw $Name};$script:checks++}
$start=100000L;$ready=$start+30000;$day=86400000L
Assert ($null-eq (Get-WidgetAutomaticUpdateMode ($ready-1) $start $false 0 $null)) 'Startup quiet period lost'
Assert ((Get-WidgetAutomaticUpdateMode $ready $start $false 0 $null)-eq 'automatic-enabled') 'Startup check missing'
Assert ($null-eq (Get-WidgetAutomaticUpdateMode ($ready+$day-1) $start $true ($ready+$day) $null)) 'Daily check ran too early'
Assert ((Get-WidgetAutomaticUpdateMode ($ready+$day) $start $true ($ready+$day) $null)-eq 'automatic') 'Daily check missing at 24 hours'
Assert ($null-eq (Get-WidgetAutomaticUpdateMode ($ready+$day) $start $true ($ready+$day) @{nextCheckAt=$ready+2*$day})) 'Daily check ignored retry deadline'
Assert ($null-eq (Get-WidgetAutomaticUpdateMode $ready $start $false 0 @{retryAfterAt=$ready+1000})) 'Startup check ignored GitHub rate limit'
Assert ((Get-WidgetAutomaticUpdateMode ($ready+2*$day) $start $true ($ready+$day) $null)-eq 'automatic') 'Resume after several days did not check'
Write-Output ('PASS: '+$checks+' startup, daily, resume and rate-limit schedule checks')
