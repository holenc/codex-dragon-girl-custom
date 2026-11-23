# Native event callbacks only signal a wait handle; they never run PowerShell.
Add-Type -AssemblyName System.Management
if(!('GptWidgetLifetimeSignal' -as [type])){
Add-Type -TypeDefinition @'
using System;using System.Management;using System.Threading;using System.Diagnostics;
public sealed class GptWidgetLifetimeSignal:IDisposable {
 readonly AutoResetEvent changed=new AutoResetEvent(false);
 ManagementEventWatcher start;
 Process[] tracked=new Process[0];
 public bool Available {get;private set;}
 public GptWidgetLifetimeSignal(int session){
  try{
   string filter=" WHERE SessionID="+session+" AND (ProcessName='ChatGPT.exe' OR ProcessName='Codex.exe' OR ProcessName='codex.exe')";
   start=new ManagementEventWatcher(new WqlEventQuery("SELECT * FROM Win32_ProcessStartTrace"+filter));
   start.EventArrived+=OnChanged;
   start.Start();Available=true;
  }catch{CloseWatchers();}
 }
 void OnChanged(object sender,EventArrivedEventArgs args){try{changed.Set();}catch(ObjectDisposedException){}}
 void OnExited(object sender,EventArgs args){try{changed.Set();}catch(ObjectDisposedException){}}
 public void Track(Process[] processes){
  foreach(var process in tracked){try{process.Exited-=OnExited;}catch{}}
  tracked=processes??new Process[0];
  foreach(var process in tracked){try{process.Exited+=OnExited;process.EnableRaisingEvents=true;if(process.HasExited)changed.Set();}catch{}}
 }
 public bool Wait(int milliseconds){return changed.WaitOne(milliseconds);}
 void CloseWatchers(){if(start!=null){try{start.Stop();}catch{}start.Dispose();}start=null;Available=false;}
 public void Dispose(){Track(null);CloseWatchers();changed.Dispose();}
}
'@ -ReferencedAssemblies ([System.Management.ManagementEventWatcher].Assembly.Location)
}
function Test-WidgetCodexDesktopProcess($Process,[int]$SessionId) {
  return $Process.SessionId-eq $SessionId -and
    $Process.Name-in @('ChatGPT.exe','Codex.exe') -and
    $Process.ExecutablePath-match '(?i)\\(?:OpenAI\.Codex_[^\\]+\\app|OpenAI\\Codex(?:\\app)?)\\(?:ChatGPT|Codex)\.exe$' -and
    [string]$Process.CommandLine -and $Process.CommandLine-notmatch '(?i)(?:^|\s)--type(?:=|\s)'
}
function Get-WidgetDesktopAppServers($Processes,[int]$SessionId) {
  $byId=@{}
  foreach($record in $Processes){$byId[[int]$record.ProcessId]=$record}
  foreach($server in $Processes){
    if($server.SessionId-ne $SessionId -or $server.Name-ine 'codex.exe' -or
      $server.CommandLine-notmatch '(?i)(?:^|\s)app-server(?:\s|$)' -or
      $server.ExecutablePath-notmatch '(?i)^(.*)\\resources\\codex\.exe$'){continue}
    $appRoot=$Matches[1]
    $child=$server;$seen=@{}
    for($depth=0;$depth-lt 16;$depth++){
      $parentId=[int]$child.ParentProcessId
      if($seen.ContainsKey($parentId) -or !$byId.ContainsKey($parentId)){break}
      $seen[$parentId]=$true;$parent=$byId[$parentId]
      # Keep ancestry inside this installed client and Windows session. Creation
      # times prevent an exited parent's reused PID from becoming a false match.
      if($parent.SessionId-ne $SessionId -or !$parent.CreationDate -or !$child.CreationDate -or
        $parent.CreationDate-gt $child.CreationDate -or
        $parent.ExecutablePath-notin @((Join-Path $appRoot 'ChatGPT.exe'),(Join-Path $appRoot 'Codex.exe'))){break}
      if(Test-WidgetCodexDesktopProcess $parent $SessionId){$server;break}
      $child=$parent
    }
  }
}
function Clear-WidgetLifetimeProcesses {
  if($script:lifetimeSignal){$script:lifetimeSignal.Track(@())}
  foreach($process in @($script:lifetimeProcesses)){if($process){$process.Dispose()}}
  $script:lifetimeProcesses=@()
}
function Test-WidgetCodexDesktopRunning([switch]$Refresh) {
  $now=[DateTime]::UtcNow
  $live=@($script:lifetimeProcesses|Where-Object{try{!$_.HasExited}catch{$false}})
  # A retained kernel process handle detects exit without waiting for WMI.
  if($script:lifetimeProcesses.Count -and !$live.Count -and !$Refresh){
    Clear-WidgetLifetimeProcesses
    $script:lifetimeNextScan=[DateTime]::MinValue
    $script:activityAppServerStartedAt=$null
    return $false
  }
  if(!$Refresh -and $script:lifetimeNextScan -and $now-lt $script:lifetimeNextScan){return $live.Count-gt 0}
  $sessionId=[Diagnostics.Process]::GetCurrentProcess().SessionId
  $processes=@(Get-CimInstance Win32_Process -Filter "Name='ChatGPT.exe' OR Name='Codex.exe'" -ErrorAction Stop)
  $desktopProcesses=@($processes|Where-Object{Test-WidgetCodexDesktopProcess $_ $sessionId})
  $handles=@(foreach($record in $desktopProcesses){
    $process=$null
    try{
      $process=[Diagnostics.Process]::GetProcessById([int]$record.ProcessId)
      if(!$process.HasExited -and [Math]::Abs(($process.StartTime.ToUniversalTime()-$record.CreationDate.ToUniversalTime()).TotalMilliseconds)-lt 1){
        # Open and retain the handle now, protecting against PID reuse.
        $null=$process.Handle;$process;$process=$null
      }
    }catch{}finally{if($process){$process.Dispose()}}
  })
  Clear-WidgetLifetimeProcesses
  $script:lifetimeProcesses=$handles
  if($script:lifetimeSignal){$script:lifetimeSignal.Track([Diagnostics.Process[]]$handles)}
  $servers=@(Get-WidgetDesktopAppServers $processes $sessionId | Sort-Object CreationDate)
  $script:activityAppServerStartedAt=if($servers.Count){$servers[0].CreationDate.ToUniversalTime().ToString('o')}else{$null}
  # Events wake us immediately; these scans recover from missed/unavailable events.
  $script:lifetimeNextScan=$now.AddSeconds($(if($handles.Count){10}else{1}))
  return $handles.Count-gt 0
}
