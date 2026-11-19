function Get-WidgetNodeCandidates {
  $paths=[Collections.Generic.List[string]]::new()
  try{foreach($p in @(Get-AppxPackage -Name 'OpenAI.CodexPrimaryRuntime*' -ErrorAction Stop|Sort-Object Version -Descending)){$paths.Add((Join-Path $p.InstallLocation 'dependencies\node\bin\node.exe'))}}catch{}
  $command=Get-Command node.exe -ErrorAction SilentlyContinue
  if($command){$paths.Add($command.Source)}
  if($env:ProgramFiles){$paths.Add((Join-Path $env:ProgramFiles 'nodejs\node.exe'))}
  return $paths.ToArray()
}
function Get-WidgetCodexCandidates {
  $paths=[Collections.Generic.List[string]]::new()
  if($env:CODEX_CLI_PATH){$paths.Add($env:CODEX_CLI_PATH)}
  try{foreach($p in @(Get-AppxPackage -Name 'OpenAI.Codex' -ErrorAction Stop|Sort-Object Version -Descending)){$paths.Add((Join-Path $p.InstallLocation 'app\resources\codex.exe'))}}catch{}
  $command=Get-Command codex.exe -ErrorAction SilentlyContinue
  if($command){$paths.Add($command.Source)}
  if($env:LOCALAPPDATA){$paths.Add((Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\bin\codex.exe'))}
  return $paths.ToArray()
}
function Get-WidgetActiveCodexPath {
  $session=[Diagnostics.Process]::GetCurrentProcess().SessionId
  try{
    foreach($p in @(Get-CimInstance Win32_Process -Filter "Name='ChatGPT.exe' OR Name='Codex.exe'" -ErrorAction Stop)){
      if($p.SessionId-ne $session -or !$p.CommandLine -or $p.CommandLine-match '(?i)(?:^|\s)--type(?:=|\s)' -or
        $p.ExecutablePath-notmatch '(?i)\\(?:OpenAI\.Codex_[^\\]+\\app|OpenAI\\Codex(?:\\app)?)\\(?:ChatGPT|Codex)\.exe$'){continue}
      $candidate=Join-Path (Split-Path $p.ExecutablePath -Parent) 'resources\codex.exe'
      if([IO.File]::Exists($candidate)){return $candidate}
    }
  }catch{}
}
function Test-WidgetNodeVersion([string]$Path) {
  $start=[Diagnostics.ProcessStartInfo]::new();$start.FileName=$Path;$start.Arguments='--version'
  $start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
  $process=[Diagnostics.Process]::new();$process.StartInfo=$start
  try{
    if(!$process.Start()){return $false}
    $out=$process.StandardOutput.ReadToEndAsync();$err=$process.StandardError.ReadToEndAsync()
    if(!$process.WaitForExit(3000)){try{$process.Kill()}catch{};return $false}
    return ($process.ExitCode-eq 0 -and $out.Result-match '^v(\d+)\.' -and [int]$Matches[1]-ge 24)
  }catch{return $false}finally{$process.Dispose()}
}
function Repair-WidgetRuntimePaths($Configuration,[string]$ConfigPath,[switch]$CheckCurrent) {
  if(!$Configuration.nodePath -and !$Configuration.codexPath){return}
  $missingNode=![IO.File]::Exists([string]$Configuration.nodePath)
  $missingCodex=![IO.File]::Exists([string]$Configuration.codexPath)
  if(!$missingNode -and !$missingCodex -and !$CheckCurrent){return}
  $now=[DateTime]::UtcNow
  if(!$CheckCurrent -and $script:runtimePathRetryAt -and $now-lt $script:runtimePathRetryAt){return}
  $script:runtimePathRetryAt=$now.AddSeconds(30)
  $changed=$false
  if($missingNode -or $CheckCurrent){foreach($candidate in @(Get-WidgetNodeCandidates|Select-Object -Unique)){
    if([IO.File]::Exists($candidate) -and (Test-WidgetNodeVersion $candidate)){$selected=[IO.Path]::GetFullPath($candidate);if($Configuration.nodePath-ine $selected){$Configuration.nodePath=$selected;$changed=$true};break}
  }}
  if($missingCodex -or $CheckCurrent){foreach($candidate in @(@(Get-WidgetActiveCodexPath)+@(Get-WidgetCodexCandidates)|Select-Object -Unique)){
    if($candidate -and [IO.File]::Exists($candidate)){$selected=[IO.Path]::GetFullPath($candidate);if($Configuration.codexPath-ine $selected){$Configuration.codexPath=$selected;$changed=$true};break}
  }}
  if(!$changed -or !$ConfigPath){return}
  # Refresh only machine paths; preserve all settings and unrelated metadata.
  $saved=[IO.File]::ReadAllText($ConfigPath,[Text.Encoding]::UTF8)|ConvertFrom-Json
  if($saved.version-ne $Configuration.version -or $saved.appDir-ine $Configuration.appDir){return}
  $saved.nodePath=$Configuration.nodePath;$saved.codexPath=$Configuration.codexPath
  $temp=$ConfigPath+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
  try{[IO.File]::WriteAllText($temp,($saved|ConvertTo-Json -Depth 24),[Text.UTF8Encoding]::new($false));[IO.File]::Replace($temp,$ConfigPath,[Management.Automation.Language.NullString]::Value)}
  finally{if([IO.File]::Exists($temp)){[IO.File]::Delete($temp)}}
}
