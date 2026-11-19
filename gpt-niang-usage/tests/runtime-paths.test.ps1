$ErrorActionPreference='Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'runtime\runtime-paths.ps1')
$root=Join-Path ([IO.Path]::GetTempPath()) ('gn-paths-'+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory($root)
$checks=0
function Assert($Value,$Name){if(!$Value){throw $Name};$script:checks++}
try{
 $script:newNode=Join-Path $root 'node-new.exe';$script:newCodex=Join-Path $root 'codex-new.exe'
 foreach($file in @($script:newNode,$script:newCodex)){[IO.File]::WriteAllText($file,'fixture')}
 function Get-WidgetNodeCandidates{return @((Join-Path $root 'missing.exe'),$script:newNode)}
 function Get-WidgetCodexCandidates{return @($script:newCodex)}
 function Get-WidgetActiveCodexPath{return $script:activeCodex}
 function Test-WidgetNodeVersion($Path){return $Path-eq $script:newNode}
 $config=[pscustomobject]@{version='2.0.5';appDir=$root;dataDir='preserve-data-path';nodePath=(Join-Path $root 'old-node.exe');codexPath=(Join-Path $root 'old-codex.exe');customMetadata='keep'}
 $file=Join-Path $root 'installation.json';[IO.File]::WriteAllText($file,($config|ConvertTo-Json))
 Repair-WidgetRuntimePaths $config $file
 Assert ($config.nodePath-eq $script:newNode -and $config.codexPath-eq $script:newCodex) 'Missing executable paths did not recover'
 $saved=[IO.File]::ReadAllText($file)|ConvertFrom-Json
 Assert ($saved.nodePath-eq $script:newNode -and $saved.codexPath-eq $script:newCodex) 'Repaired paths were not persisted'
 Assert ($saved.customMetadata-eq 'keep' -and $saved.dataDir-eq 'preserve-data-path') 'Repair lost unrelated configuration'
 $before=[IO.File]::ReadAllText($file);Repair-WidgetRuntimePaths $config $file
 Assert ([IO.File]::ReadAllText($file)-ceq $before) 'Valid paths caused unnecessary configuration writes'
 [IO.File]::Delete($script:newNode);$script:newNode=Join-Path $root 'node-next.exe';[IO.File]::WriteAllText($script:newNode,'fixture')
 $script:runtimePathRetryAt=[DateTime]::MinValue;Repair-WidgetRuntimePaths $config $file
 Assert ($config.nodePath-eq $script:newNode) 'A second runtime upgrade did not recover'
 $script:activeCodex=Join-Path $root 'codex-running-new.exe';[IO.File]::WriteAllText($script:activeCodex,'fixture')
 Repair-WidgetRuntimePaths $config $file -CheckCurrent
 Assert ($config.codexPath-eq $script:activeCodex) 'Running Codex did not take priority over another installed version'
 Write-Output ('PASS: '+$checks+' missing path, persistence, unchanged metadata and subsequent-upgrade checks')
}finally{
 $target=[IO.Path]::GetFullPath($root)
 if(!$target.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe test cleanup'}
 Remove-Item -LiteralPath $target -Recurse -Force
}
