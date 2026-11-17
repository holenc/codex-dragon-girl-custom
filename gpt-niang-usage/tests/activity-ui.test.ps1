$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$script:appDir=Split-Path $PSScriptRoot -Parent
. (Join-Path $script:appDir 'runtime/activity.ps1')
. (Join-Path $script:appDir 'runtime/quota-expression.ps1')
. (Join-Path $script:appDir 'runtime/characters.ps1')
$window=[Windows.Markup.XamlReader]::Parse([IO.File]::ReadAllText((Join-Path $script:appDir 'widget.xaml'),[Text.Encoding]::UTF8))
$script:ui=@{};foreach($name in @('ActivityRunning','ActivityWaiting','Girl')){$script:ui[$name]=$window.FindName($name)}
$now=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$script:characterId='gpt-dragon';$script:quotaExpressionCache=@{}
$script:status=@{ok=$true;queryOk=$true;observedAt=$now;credits=@{balance=0};windows=@(@{minutes=300;used=0;remaining=100;resetsAt=$now/1000+100})}
foreach($case in @(@(0,''),@(1,'......'),@(3,'3......'),@(100,'99......'))){
  $script:activityState=@{ok=$true;at=$now;running=$case[0];waiting=2;failures=@()};Update-WidgetActivityBadge
  if($script:ui.ActivityRunning.Text-ne $case[1] -or $script:ui.ActivityWaiting.Text-ne '+2'){throw 'Badge count/layout failure'}
}
$script:activityState=@{ok=$true;at=$now;running=1;waiting=0;failures=@(@{quota=$false})};Update-WidgetActivityBadge
if($script:quotaExpressionKey-ne 'drooling'){throw 'Task failure did not override normal expression'}
$script:activityState.failures=@();Update-WidgetActivityBadge
if($script:quotaExpressionKey-ne 'normal'){throw 'Resolved failure did not restore normal expression'}
$script:activityState.at=$now-11000;Update-WidgetActivityBadge
if($script:ui.ActivityRunning.Text-ne '?'){throw 'Stale source left a permanent running number'}
$window.Close()
'Badge 0/1/3/99, waiting count, failure override/recovery and stale-source checks passed.'
