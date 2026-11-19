param([switch]$AncestorGit)
# Optional live public-release check. It cannot install: the isolated fixture
# uses version 99.99.99, and its configuration, binding and locks are temporary.
$ErrorActionPreference='Stop'
$app=Split-Path $PSScriptRoot -Parent
. (Join-Path $app 'runtime\supervisor-task.ps1')
. (Join-Path $app 'runtime\update-common.ps1')
. (Join-Path $app 'runtime\runtime-paths.ps1')
. ([ScriptBlock]::Create([IO.File]::ReadAllText((Join-Path $app 'runtime\update-ui.ps1'),[Text.Encoding]::UTF8)))
$root=Join-Path ([IO.Path]::GetTempPath()) ('gn-update-bootstrap-'+[guid]::NewGuid().ToString('N'))
$testApp=Join-Path $root 'install\gpt-niang-usage';$script:dataDir=Join-Path $root 'state';$agent=Join-Path $root 'agent'
$live=Read-WidgetUpdateJson (Join-Path $app 'installation.json')
$script:liveNode=$live.nodePath;$script:liveCodex=$live.codexPath
try{
 foreach($p in @($testApp,$script:dataDir,$agent)){$null=[IO.Directory]::CreateDirectory($p)}
 if($AncestorGit){
   & git init -q $root
   if($LASTEXITCODE-ne 0){throw 'Cannot create isolated workspace repository'}
   [IO.File]::WriteAllText((Join-Path $root 'workspace-note.txt'),'Tracked sibling workspace file')
   & git -c ('safe.directory='+$root) -c core.fsmonitor=false -C $root add -- workspace-note.txt
   if($LASTEXITCODE-ne 0){throw 'Cannot initialize isolated workspace index'}
 }
 foreach($name in @('runtime','.codex-plugin')){Copy-Item -LiteralPath (Join-Path $app $name) -Destination $testApp -Recurse}
 foreach($name in @('package.json','custom-build.json')){Copy-Item -LiteralPath (Join-Path $app $name) -Destination $testApp}
 $script:appDir=$testApp;$script:configPath=Join-Path $testApp 'installation.json'
 $script:config=[pscustomobject]@{version='99.99.99';appDir=$testApp;dataDir=$script:dataDir;nodePath=(Join-Path $root 'removed-runtime\node.exe');codexPath=$script:liveCodex;updateAgent=$agent}
 Write-WidgetSupervisorJson $script:configPath $script:config
 Write-WidgetSupervisorJson (Join-Path $agent 'binding.json') @{appDir=$testApp;dataDir=$script:dataDir}
 $settings=Join-Path $script:dataDir 'settings.json';[IO.File]::WriteAllText($settings,'{"scale":0.7,"desktopTopmost":true,"marker":"keep"}')
 $before=[IO.File]::ReadAllText($settings)
 function Get-WidgetNodeCandidates{return @($script:liveNode)}
 function Get-WidgetCodexCandidates{return @($script:liveCodex)}
 function Get-WidgetActiveCodexPath{return $script:liveCodex}
 $script:settingsMenuUi=@{};$script:context=[pscustomobject]@{IsOpen=$false}
 Initialize-WidgetUpdater
 Start-WidgetUpdate 'manual'
 if(!$script:updateProcess){throw 'Updater did not start after repairing the removed runtime'}
 $deadline=[DateTime]::UtcNow.AddSeconds(60)
 while(!$script:updateProcess.HasExited){if([DateTime]::UtcNow-gt $deadline){throw 'Public release check timed out'};Start-Sleep -Milliseconds 200}
 Tick-WidgetUpdater ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())
 $state=Read-WidgetUpdateJson (Join-Path $script:dataDir 'update-status.json')
 if($state.phase-ne 'current'){throw ('Real updater failed: '+$state.phase+' '+$state.message)}
 if((Read-WidgetUpdateJson $script:configPath).nodePath-ne $script:liveNode){throw 'Recovered runtime was not persisted'}
 if([IO.File]::ReadAllText($settings)-cne $before){throw 'Update check changed appearance preferences'}
 Write-Output 'PASS: removed Node path -> actual updater process -> public release response -> terminal menu state; preferences unchanged'
 $state|Add-Member retryAfterAt ([DateTimeOffset]::UtcNow.AddMinutes(1).ToUnixTimeMilliseconds()) -Force
 Write-WidgetSupervisorJson (Join-Path $script:dataDir 'update-status.json') $state
 Start-WidgetUpdate 'manual'
 if(!$script:updateProcess.WaitForExit(10000)){throw 'Rate-limit check did not complete'}
 Tick-WidgetUpdater ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())
 $limited=Read-WidgetUpdateJson (Join-Path $script:dataDir 'update-status.json')
 if($limited.phase-ne 'rate-limited' -or $limited.retryAfterAt-ne $state.retryAfterAt){throw 'Manual launch lost GitHub rate-limit state'}
 Write-Output 'PASS: startup feedback preserves the GitHub retry deadline'
 # A truly missing runtime must produce a useful error instead of a silent return.
 function Get-WidgetNodeCandidates{return @()}
 $script:config.nodePath=Join-Path $root 'missing\node.exe'
 Start-WidgetUpdate 'manual'
 $state=Read-WidgetUpdateJson (Join-Path $script:dataDir 'update-status.json')
 if($state.phase-ne 'failed' -or $state.message-notmatch 'Node.js 24'){throw 'Missing runtime was not reported clearly'}
 Write-Output 'PASS: unavailable runtime produces an explicit failure without starting a process'
}finally{
 if($script:updateProcess){try{if(!$script:updateProcess.HasExited){$script:updateProcess.Kill();$script:updateProcess.WaitForExit()}}catch{};$script:updateProcess.Dispose()}
 $target=[IO.Path]::GetFullPath($root)
 if(!$target.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe bootstrap fixture cleanup'}
 Remove-Item -LiteralPath $target -Recurse -Force
}
