param([string]$AppDir)
# Read-only support report. Do not launch helpers, change files, clear locks,
# read account/auth files, or include request/authorization tokens.
$ErrorActionPreference='Stop'
function Read-DiagnosticJson([string]$File){
  try{if((Get-Item -LiteralPath $File -ErrorAction Stop).Length-gt 512KB){return $null};return [IO.File]::ReadAllText($File,[Text.Encoding]::UTF8)|ConvertFrom-Json}catch{return $null}
}
function Test-DiagnosticProcess($Value){if(!$Value -or [long]$Value-le 0){return $false};try{return [bool](Get-Process -Id ([int]$Value) -ErrorAction Stop)}catch{return $null}}
function Diagnostic-Age($Value){if(!$Value){return $null};try{return [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()-[long]$Value}catch{return $null}}
function Diagnostic-ErrorText([string]$File){
  try{
    $text=[IO.File]::ReadAllText($File,[Text.Encoding]::UTF8)
    if($text.Length-gt 2000){$text=$text.Substring(0,2000)}
    $profile=[Environment]::GetFolderPath('UserProfile');if($profile){$text=$text.Replace($profile,'%USERPROFILE%')}
    return $text
  }catch{return $null}
}
Add-Type -TypeDefinition @'
using System;using System.Runtime.InteropServices;
public static class GptNiangDiagnosticFolder {
 [DllImport("shell32.dll")]static extern int SHGetKnownFolderPath(ref Guid id,uint flags,IntPtr token,out IntPtr path);
 public static string Local(){var id=new Guid("F1B32785-6FBA-4FCF-9D55-7B8E7F157091");IntPtr p=IntPtr.Zero;try{Marshal.ThrowExceptionForHR(SHGetKnownFolderPath(ref id,0x10000,IntPtr.Zero,out p));return Marshal.PtrToStringUni(p);}finally{if(p!=IntPtr.Zero)Marshal.FreeCoTaskMem(p);}}
}
'@
$local=[GptNiangDiagnosticFolder]::Local()
$agent=Join-Path $local 'GPTNiangUsage\update-agent'
$binding=Read-DiagnosticJson (Join-Path $agent 'binding.json')
if(!$AppDir){$AppDir=[string]$binding.appDir}
if(!$AppDir){throw 'No installation binding was found. Supply -AppDir with the gpt-niang-usage directory.'}
$AppDir=[IO.Path]::GetFullPath($AppDir)
$config=Read-DiagnosticJson (Join-Path $AppDir 'installation.json')
if(!$config){throw 'installation.json is missing or unreadable at the selected installation.'}
$data=[string]$config.dataDir
if(!$data){throw 'The installed configuration has no data directory.'}
$manifest=Read-DiagnosticJson (Join-Path $AppDir 'package.json')
$plugin=Read-DiagnosticJson (Join-Path $AppDir '.codex-plugin\plugin.json')
$state=Read-DiagnosticJson (Join-Path $data 'update-status.json')
$runtime=Read-DiagnosticJson (Join-Path $data 'runtime.json')
$presence=Read-DiagnosticJson (Join-Path $data 'presence.json')
$idle=Read-DiagnosticJson (Join-Path $data 'update-idle.json')
$worker=Read-DiagnosticJson (Join-Path $data 'worker-status.json')
$policy=Read-DiagnosticJson (Join-Path $AppDir 'custom-build.json')
$preferences=Read-DiagnosticJson (Join-Path $data 'update-preferences.json')
$journal=Read-DiagnosticJson (Join-Path $agent 'update-transaction.json')
$lock=Read-DiagnosticJson (Join-Path $agent 'update.lock\owner.json')
$git=$false;for($dir=$AppDir;$dir;$dir=Split-Path $dir -Parent){if(Test-Path -LiteralPath (Join-Path $dir '.git')){$git=$true;break}}
$report=[ordered]@{
  reportVersion=1
  versions=@{installed=$config.version;package=$manifest.version;plugin=$plugin.version}
  executables=@{nodeExists=[IO.File]::Exists([string]$config.nodePath);codexExists=[IO.File]::Exists([string]$config.codexPath)}
  registration=@{bindingMatches=([string]$binding.appDir-ieq $AppDir);isGitCheckout=$git;updateMode=$policy.updates.mode;repository=$policy.updates.repository;automatic=($preferences.automatic-ne $false)}
  update=@{phase=$state.phase;message=$state.message;targetVersion=$state.version;ageMs=(Diagnostic-Age $state.at);nextCheckAt=$state.nextCheckAt;retryAfterAt=$state.retryAfterAt}
  widget=@{runtimeProcessVisible=(Test-DiagnosticProcess $runtime.pid);presenceAgeMs=(Diagnostic-Age $presence.at);visible=$presence.visible}
  idle=@{ageMs=(Diagnostic-Age $idle.at);menu=$idle.menu;editor=$idle.editor;drag=$idle.drag;workerBusy=$worker.busy;workerAgeMs=(Diagnostic-Age $worker.at)}
  lock=@{exists=!!$lock;ownerAlive=(Test-DiagnosticProcess $lock.pid);helperAlive=(Test-DiagnosticProcess $lock.helperPid)}
  transaction=@{phase=$journal.phase;oldVersion=$journal.oldVersion;targetVersion=$journal.version;cleanupPending=$journal.cleanupPending}
  diagnostics=@{update=(Diagnostic-ErrorText (Join-Path $agent 'update-diagnostic.txt'));cleanup=(Diagnostic-ErrorText (Join-Path $agent 'update-cleanup-error.txt'))}
}
$report|ConvertTo-Json -Depth 6
