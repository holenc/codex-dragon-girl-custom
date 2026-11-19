function Set-WidgetUpdateState($Values) {
  $file=Join-Path $script:dataDir 'update-status.json'
  $previous=Read-WidgetUpdateJson $file
  $merged=@{}
  if($previous){foreach($property in $previous.PSObject.Properties){$merged[$property.Name]=$property.Value}}
  foreach($key in $Values.Keys){$merged[$key]=$Values[$key]}
  if(!$Values.ContainsKey('at')){$merged.at=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()}
  Write-WidgetSupervisorJson $file $merged
}
function Get-WidgetAutomaticUpdateMode([long]$Now,[long]$StartedAt,[bool]$StartupChecked,[long]$NextDailyAt,$State) {
  if($Now-lt $StartedAt+30000 -or $Now-lt [long]$State.retryAfterAt){return $null}
  if(!$StartupChecked){return 'automatic-enabled'}
  if($Now-ge [Math]::Max($NextDailyAt,[long]$State.nextCheckAt)){return 'automatic'}
  return $null
}
function Initialize-WidgetUpdater {
  $script:updateErrorTask=$null;$script:updateLaunchedAt=0L
  $script:updateNextDailyAt=0L
  $script:updateProcess=$null;$script:updateLastTick=0;$script:updateStartedAt=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds();$script:updateCleanupChecked=$false;$script:updateStartupChecked=$false
  $preferences=Read-WidgetUpdateJson (Join-Path $script:dataDir 'update-preferences.json')
  $script:customUpdatePolicy=Read-WidgetUpdateJson (Join-Path $script:appDir 'custom-build.json')
  $script:manualUpdatesOnly=$script:customUpdatePolicy.updates.mode-eq 'manual-only'
  $script:autoUpdate=(!$script:manualUpdatesOnly -and !($preferences -and $preferences.automatic-eq $false))
}
function Test-WidgetUpdateEditor {
  return [bool]($script:audioDialogOpen -or ($script:quoteEditor -and $script:quoteEditor.IsVisible) -or ($script:colorTriggerEditor -and $script:colorTriggerEditor.IsVisible) -or ($script:characterGallery -and $script:characterGallery.IsVisible))
}
function Start-WidgetUpdate([string]$Mode='manual') {
  if($script:manualUpdatesOnly -and $Mode-ne 'cleanup'){return}
  if($script:updateProcess){if(!$script:updateProcess.HasExited){return};$script:updateProcess.Dispose();$script:updateProcess=$null}
  if($Mode-eq 'manual' -and (Test-WidgetUpdateEditor)){
    [Windows.MessageBox]::Show($script:window,'请先保存并关闭编辑窗口，再检查更新。','GPT 娘更新')|Out-Null;return
  }
  try{
    if(Get-Command Repair-WidgetRuntimePaths -ErrorAction SilentlyContinue){Repair-WidgetRuntimePaths $script:config $script:configPath -CheckCurrent}
    if(![IO.File]::Exists([string]$script:config.nodePath)){throw 'Node.js 24+ is unavailable. Open Codex to restore its runtime, then retry.'}
  }catch{
    Set-WidgetUpdateState @{phase='failed';message=('无法启动更新器：'+$_.Exception.Message);nextCheckAt=[DateTimeOffset]::UtcNow.AddDays(1).ToUnixTimeMilliseconds()}
    Update-WidgetUpdateMenu;return
  }
  if($Mode-ne 'cleanup'){
    $script:updateStartupChecked=$true
    $script:updateNextDailyAt=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()+86400000L
  }
  $info=New-Object Diagnostics.ProcessStartInfo
  $info.FileName=$script:config.nodePath
  $info.Arguments='"'+(Join-Path $script:appDir 'runtime\update.mjs')+'" "'+$script:configPath+'" '+$Mode
  $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardError=$true
  $info.StandardErrorEncoding=[Text.UTF8Encoding]::new($false)
  $process=New-Object Diagnostics.Process;$process.StartInfo=$info
  $script:updateLaunchedAt=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  Set-WidgetUpdateState @{phase=$(if($Mode-eq 'cleanup'){'cleaning'}else{'starting'});message=$(if($Mode-eq 'cleanup'){'正在整理更新文件…'}else{'正在启动更新器…'});at=$script:updateLaunchedAt}
  try{if(!$process.Start()){throw 'Updater process did not start.'};$script:updateProcess=$process;$script:updateErrorTask=$process.StandardError.ReadToEndAsync()}
  catch{$process.Dispose();Set-WidgetUpdateState @{phase='failed';message=$_.Exception.Message;nextCheckAt=[DateTimeOffset]::UtcNow.AddDays(1).ToUnixTimeMilliseconds()}}
}
function Set-WidgetAutomaticUpdate([bool]$Enabled) {
  if($script:manualUpdatesOnly){$Enabled=$false}
  $script:autoUpdate=$Enabled
  Write-WidgetSupervisorJson (Join-Path $script:dataDir 'update-preferences.json') @{automatic=$Enabled}
  if($Enabled){Start-WidgetUpdate 'automatic-enabled'}
  Update-WidgetUpdateMenu
}
function Update-WidgetUpdateMenu {
  if(!$script:settingsMenuUi.UpdateVersion){return}
  $script:settingsMenuUi.UpdateVersion.Header='当前版本：'+$script:config.version
  $script:settingsMenuUi.AutoUpdate.IsChecked=$script:autoUpdate
  if($script:manualUpdatesOnly){
    $script:settingsMenuUi.AutoUpdate.IsEnabled=$false
    $script:settingsMenuUi.UpdateStatus.Header.Text='仅手动更新'
    $script:settingsMenuUi.UpdateStatus.ToolTip='自动更新已关闭。'
    return
  }
  $state=Read-WidgetUpdateJson (Join-Path $script:dataDir 'update-status.json')
  $label=switch($state.phase){
    'starting' {'正在启动更新器…'}
    'cleaning' {'正在整理更新文件…'}
    'busy' {'已有更新正在进行，请稍候'}
    'checking' {'正在检查更新…'}
    'downloading' {'正在下载：'+[Math]::Round([double]$state.bytes/1MB,1)+' MiB'}
    'waiting' {'已校验，等待挂件空闲'}
    'installing' {'正在安装更新…'}
    'updated' {'已更新至 '+$state.version}
    'rolled-back' {'更新失败，已恢复上一版'}
    'failed' {'更新失败：'+$state.message}
    'source' {'源码目录请使用 Git 更新'}
    'rate-limited' {'GitHub 限流，稍后再检查'}
    'current' {'已是最新版本'}
    'cancelled' {'自动更新已关闭'}
    default {'启动时及每 24 小时检查更新'}
  }
  $script:settingsMenuUi.UpdateStatus.Header.Text=$label
  $script:settingsMenuUi.UpdateStatus.ToolTip=$state.message
}
function Tick-WidgetUpdater([long]$Now) {
  if($Now-$script:updateLastTick-lt 1000){return};$script:updateLastTick=$Now
  Write-WidgetSupervisorJson (Join-Path $script:dataDir 'update-idle.json') @{at=$Now;pid=$PID;editor=(Test-WidgetUpdateEditor);menu=[bool]$script:context.IsOpen;drag=[bool]$script:drag}
  if($script:updateProcess -and $script:updateProcess.HasExited){
    if($script:updateProcess.ExitCode-ne 0){
      $state=Read-WidgetUpdateJson (Join-Path $script:dataDir 'update-status.json')
      if($state.phase-notin @('failed','rolled-back') -or [long]$state.at-lt $script:updateLaunchedAt){
        $detail=if($script:updateErrorTask -and $script:updateErrorTask.IsCompleted){$script:updateErrorTask.Result.Trim()}else{''}
        if($detail.Length-gt 700){$detail=$detail.Substring(0,700)}
        Set-WidgetUpdateState @{phase='failed';message=('更新进程退出（'+$script:updateProcess.ExitCode+'）'+$(if($detail){'：'+$detail}else{'，请检查安装配置后重试。'}));nextCheckAt=$Now+86400000}
      }
    }
    $script:updateErrorTask=$null
    $script:updateProcess.Dispose();$script:updateProcess=$null
  }
  $state=Read-WidgetUpdateJson (Join-Path $script:dataDir 'update-status.json')
  # Cleanup is independent of the preference to check for new releases.
  if(!$script:updateCleanupChecked -and $Now-ge $script:updateStartedAt+30000 -and !$script:updateProcess){
    $script:updateCleanupChecked=$true;Start-WidgetUpdate 'cleanup'
  }
  if($script:autoUpdate -and !$script:updateProcess){
    $mode=Get-WidgetAutomaticUpdateMode $Now $script:updateStartedAt $script:updateStartupChecked $script:updateNextDailyAt $state
    if($mode){Start-WidgetUpdate $mode}
  }
  if($script:context.IsOpen){Update-WidgetUpdateMenu}
}
