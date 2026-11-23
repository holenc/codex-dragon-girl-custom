$ErrorActionPreference='Stop'
$app=Split-Path $PSScriptRoot -Parent
. (Join-Path $app 'runtime\codex-lifetime.ps1')
$checks=0
function Assert($Value,$Name){if(!$Value){throw $Name};$script:checks++}
$self=[Diagnostics.Process]::GetCurrentProcess()
$script:records=@([pscustomobject]@{SessionId=$self.SessionId;Name='ChatGPT.exe';ExecutablePath='C:\Program Files\WindowsApps\OpenAI.Codex_fixture\app\ChatGPT.exe';CommandLine='ChatGPT.exe';ProcessId=$PID;ParentProcessId=0;CreationDate=$self.StartTime.ToUniversalTime()})
$script:queries=0
function Get-CimInstance { $script:queries++;return $script:records }
try{
 $main=$script:records[0].PSObject.Copy()
 $utility=$main.PSObject.Copy();$utility.ProcessId=101;$utility.ParentProcessId=$main.ProcessId;$utility.CommandLine='ChatGPT.exe --type=utility';$utility.CreationDate=$main.CreationDate.AddSeconds(1)
 $server=$utility.PSObject.Copy();$server.ProcessId=102;$server.ParentProcessId=101;$server.Name='codex.exe';$server.ExecutablePath=Join-Path (Split-Path $main.ExecutablePath) 'resources\codex.exe';$server.CommandLine='codex.exe app-server';$server.CreationDate=$main.CreationDate.AddSeconds(2)
 Assert (@(Get-WidgetDesktopAppServers @($main,$utility,$server) $self.SessionId).Count-eq 1) 'Utility-owned app-server was lost'
 $server.ParentProcessId=$main.ProcessId
 Assert (@(Get-WidgetDesktopAppServers @($main,$server) $self.SessionId).Count-eq 1) 'Direct app-server was lost'
 $server.ParentProcessId=101;$server.CommandLine='codex.exe exec-server'
 Assert (@(Get-WidgetDesktopAppServers @($main,$utility,$server) $self.SessionId).Count-eq 0) 'Exec server accepted'
 $server.CommandLine='codex.exe app-server';$server.SessionId=$self.SessionId+1
 Assert (@(Get-WidgetDesktopAppServers @($main,$utility,$server) $self.SessionId).Count-eq 0) 'Foreign session server accepted'
 $server.SessionId=$self.SessionId;$utility.ExecutablePath='C:\Other\ChatGPT.exe'
 Assert (@(Get-WidgetDesktopAppServers @($main,$utility,$server) $self.SessionId).Count-eq 0) 'Foreign client ancestor accepted'
 $utility.ExecutablePath=$main.ExecutablePath;$utility.CreationDate=$server.CreationDate.AddSeconds(1)
 Assert (@(Get-WidgetDesktopAppServers @($main,$utility,$server) $self.SessionId).Count-eq 0) 'Reused parent PID accepted'
 $utility.CreationDate=$main.CreationDate.AddSeconds(1);$utility.ParentProcessId=$server.ProcessId
 Assert (@(Get-WidgetDesktopAppServers @($main,$utility,$server) $self.SessionId).Count-eq 0) 'Cyclic ancestry accepted'
 Assert (Test-WidgetCodexDesktopRunning -Refresh) 'Validated main process was not retained'
 for($i=0;$i-lt 20;$i++){Assert (Test-WidgetCodexDesktopRunning) 'Live cached process was lost'}
 Assert ($script:queries-eq 1) 'Normal ticks repeated the WMI query'
 $renderer=$script:records[0].PSObject.Copy();$renderer.CommandLine='ChatGPT.exe --type=renderer'
 Assert (!(Test-WidgetCodexDesktopProcess $renderer $self.SessionId)) 'Renderer kept the pet alive'
 $foreign=$script:records[0].PSObject.Copy();$foreign.ExecutablePath='C:\Other\ChatGPT.exe'
 Assert (!(Test-WidgetCodexDesktopProcess $foreign $self.SessionId)) 'Unrelated ChatGPT application accepted'
 $foreign.SessionId=$self.SessionId+1
 Assert (!(Test-WidgetCodexDesktopProcess $foreign $self.SessionId)) 'Foreign Windows session accepted'
 Clear-WidgetLifetimeProcesses
 $start=[Diagnostics.ProcessStartInfo]::new();$start.FileName=Join-Path $env:WINDIR 'System32\cmd.exe';$start.Arguments='/d /c exit 0';$start.UseShellExecute=$false;$start.CreateNoWindow=$true
 $child=[Diagnostics.Process]::Start($start);$null=$child.Handle;$child.WaitForExit()
 $script:lifetimeProcesses=@($child);$script:lifetimeNextScan=[DateTime]::UtcNow.AddHours(1)
 $before=$script:queries;$clock=[Diagnostics.Stopwatch]::StartNew()
 Assert (!(Test-WidgetCodexDesktopRunning)) 'Exited host remained alive until rescan'
 Assert ($script:queries-eq $before) 'Host exit waited for WMI'
 Assert ($clock.ElapsedMilliseconds-lt 250) 'Cached process exit check was slow'
 Assert (Test-WidgetCodexDesktopRunning) 'Rescan did not recover an active host'
 Assert ($script:queries-eq $before+1) 'Rescan did not run after exit'
 $signal=[GptWidgetLifetimeSignal]::new($self.SessionId)
 Assert (!$signal.Wait(1)) 'Idle event signal was already set'
 if($signal.Available){
   $fixtureDir=Join-Path ([IO.Path]::GetTempPath()) ('gn-lifetime-events-'+[guid]::NewGuid().ToString('N'))
   $null=[IO.Directory]::CreateDirectory($fixtureDir)
   $exe=Join-Path $fixtureDir 'ChatGPT.exe'
   Add-Type -TypeDefinition 'public static class LifetimeFixture {public static void Main(){System.Threading.Thread.Sleep(4000);}}' -OutputAssembly $exe -OutputType ConsoleApplication
   $start.FileName=$exe;$start.Arguments=''
   $clock.Restart();$eventChild=[Diagnostics.Process]::Start($start)
   $signal.Track([Diagnostics.Process[]]@($eventChild))
   Assert ($signal.Wait(2500)) 'Windows process start did not wake the monitor'
   $startMs=$clock.ElapsedMilliseconds;Write-Output ('Process start event observed after '+$startMs+' ms')
   $eventChild.WaitForExit();$clock.Restart()
   Assert ($signal.Wait(2500)) 'Windows process exit did not wake the monitor'
   Write-Output ('Native event wakeup: start='+$startMs+' ms, exit='+$clock.ElapsedMilliseconds+' ms (isolated dummy process)')
 }
 Write-Output ('PASS: '+$checks+' lifecycle identity, cache, immediate exit and recovery checks; process events available='+$signal.Available)
}finally{
 if($eventChild){$eventChild.WaitForExit();$eventChild.Dispose()}
 if($signal){$signal.Dispose()};Clear-WidgetLifetimeProcesses;$self.Dispose()
 if($fixtureDir){
   $resolved=[IO.Path]::GetFullPath($fixtureDir)
   if(!$resolved.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe fixture cleanup'}
   Remove-Item -LiteralPath $resolved -Recurse -Force
 }
}
