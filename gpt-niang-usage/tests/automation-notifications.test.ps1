$ErrorActionPreference='Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'runtime\completion-notifications.ps1')
function Assert($Value,[string]$Message){if(!$Value){throw $Message}}
function Start-CompletionMonitor {}
function Reset-WidgetAutoQuoteSchedule {}
function Stop-TemporaryCompletion {}
function Test-WidgetUpdateEditor {return $false}
function Test-WidgetCompletionHostForeground {return $true}
function Test-WidgetCompletionForeground {return $true}
function Open-WidgetBubble([string]$Mode){$script:lastShown=$script:completionDisplayText;$script:collapsed=$false;$script:bubbleMode=$Mode}
function Hide-Quota([switch]$KeepCompletion){$script:collapsed=$true}
$script:window=@{IsVisible=$true};$script:drag=$null;$script:context=@{IsOpen=$false};$script:settingsSizePreview=$false;$script:closeTimer=$null
Initialize-CompletionNotificationState @{taskCompletionBubble=$true}
$script:collapsed=$true
function Emit-Start([string]$Id,[string]$Title,[long]$At=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()){
  Receive-CompletionMonitorLine ((@{type='automation-start';sessionId='test';turnId=$Id;title=$Title;endedAt=$At}|ConvertTo-Json -Compress))
}
Emit-Start 'a' '英国课程';Emit-Start 'a' '英国课程';Emit-Start 'b' '一次性提醒'
Assert ($script:automationNotifications.Count-eq 2) 'Starts were lost or duplicated'
Tick-CompletionNotifications $true
Assert ($script:lastShown-eq '英国课程' -and $script:automationNotifications.Count-eq 1) 'First title did not display'
Receive-CompletionMonitorLine ((@{type='completion';sessionId='test';turnId='normal';endedAt=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()}|ConvertTo-Json -Compress))
Dismiss-CompletionNotification
Assert $script:completionPending 'An automation bubble erased an ordinary completion'
$script:collapsed=$true;Tick-CompletionNotifications $true
Assert ($script:lastShown-eq '一次性提醒') 'Simultaneous tasks did not queue'
$script:collapsed=$true;Tick-CompletionNotifications $true
Assert ($script:completionNotificationKind-eq 'completion' -and !$script:completionDisplayText) 'Ordinary completion did not retain its default text'
Emit-Start 'old' '过期' ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()-180000)
Assert ($script:automationNotifications.Count-eq 0) 'Stale automation replayed'
Write-Output 'Automation notification queue, title routing, dedupe, stale filtering and ordinary completion checks passed.'
