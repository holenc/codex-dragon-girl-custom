function Test-WidgetActivityFresh {
  return ($script:activityState -and $script:activityState.ok-eq $true -and [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()-[long]$script:activityState.at-le 10000)
}
function Read-WidgetActivity {
  try{
    $file=Join-Path $script:dataDir 'activity.json'
    if((Get-Item -LiteralPath $file -ErrorAction Stop).Length-gt 512KB){throw 'Activity snapshot too large'}
    $state=Get-Content -LiteralPath $file -Raw -Encoding UTF8|ConvertFrom-Json
    if($state.version-ne 1){throw 'Unknown activity snapshot'}
    $script:activityState=$state
  }catch{$script:activityState=$null}
  if(!(Test-WidgetActivityFresh)){
    foreach($key in @($script:interactionNotices.Keys)){if($script:interactionNotices[$key].source-eq 'activity'){$script:interactionNotices.Remove($key)}}
    return
  }
  # A full reconciled snapshot replaces notices instead of accumulating counters.
  $script:interactionNotices=@{}
  foreach($q in @($script:activityState.questions)){
    $script:interactionNotices[$q.id]=@{id=$q.id;kind='notice';threadId=$q.threadId;turnId=$q.turnId;title=$q.title;summary=$q.summary;detail=$q.detail;createdAt=$q.createdAt;expiresAt=[long]::MaxValue;source='activity';nativePermissionId=$q.nativePermissionId}
  }
}
function Test-WidgetInteractionPending($Request) {
  if(!(Test-WidgetActivityFresh)){return $true}
  if($script:activityState.at-lt $Request.createdAt){return $true}
  if(@($script:activityState.resolvedPermissionIds)-contains $Request.id){return $false}
  $t=@($script:activityState.threads|Where-Object{$_.threadId-eq $Request.threadId})|Select-Object -First 1
  if($t){return ($t.turnId-eq $Request.turnId -and $t.status-eq 'inProgress')}
  return ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()-[long]$Request.createdAt-lt 10000)
}
function Test-WidgetQuotaAvailable {
  $s=$script:status
  if(!$s -or $s.queryOk-ne $true -or !$s.observedAt -or [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()-[long]$s.observedAt-gt 180000){return $false}
  if($s.credits.unlimited-eq $true -or ($null-ne $s.credits.balance -and [double]$s.credits.balance-gt 0)){return $true}
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  $rows=@($s.windows|Where-Object{$null-ne $_.remaining})
  return ($rows.Count-gt 0 -and @($rows|Where-Object{[double]$_.remaining-le 0 -and (!$_.resetsAt -or [double]$_.resetsAt-gt $now)}).Count-eq 0)
}
function Get-WidgetActivityFailures {
  if(!(Test-WidgetActivityFresh)){return @()}
  return @($script:activityState.failures|Where-Object{!$_.quota -or !(Test-WidgetQuotaAvailable)})
}
function Update-WidgetActivityBadge([int]$Waiting=-1) {
  if(!$script:ui.ActivityRunning){return}
  $healthy=Test-WidgetActivityFresh
  $running=if($healthy){[Math]::Min(99,[int]$script:activityState.running)}else{0}
  $waitingCount=if($Waiting-ge 0){$Waiting}elseif($healthy){[int]$script:activityState.waiting}else{0}
  $script:activityRunningCount=$running;$script:activityWaitingCount=$waitingCount
  $script:ui.ActivityRunning.Text=if(!$healthy){'?'}elseif($running-eq 1){'......'}elseif($running-gt 1){[string]$running+'......'}else{''}
  $script:ui.ActivityWaiting.Text=if($waitingCount-gt 0){'+'+[Math]::Min(99,$waitingCount)}else{''}
  $script:ui.ActivityRunning.ToolTip=if($healthy){'Running chats: '+$running}else{'Reconnecting to Codex activity'}
  if(Get-Command Update-WidgetQuotaExpression -ErrorAction SilentlyContinue){Update-WidgetQuotaExpression}
}
function Get-WidgetActivityStatus {
  return @{healthy=[bool](Test-WidgetActivityFresh);running=$script:activityRunningCount;waiting=$script:activityWaitingCount;failures=@(Get-WidgetActivityFailures).Count;error=if($script:activityState){$script:activityState.error}else{'Activity source unavailable'}}
}
