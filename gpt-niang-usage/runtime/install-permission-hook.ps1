function Install-WidgetPermissionHook([string]$AppDir) {
  $homeDir=if($env:CODEX_HOME){[IO.Path]::GetFullPath($env:CODEX_HOME)}else{Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex'}
  $file=Join-Path $homeDir 'hooks.json'
  $config=if(Test-Path -LiteralPath $file){Get-Content -LiteralPath $file -Raw -Encoding UTF8|ConvertFrom-Json}else{[pscustomobject]@{}}
  if(!$config.PSObject.Properties['hooks']){$config|Add-Member hooks ([pscustomobject]@{})}
  $command='powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -File "'+(Join-Path $AppDir 'runtime\permission-hook-launch.ps1')+'"'
  $rule=[pscustomobject]@{matcher='Bash|apply_patch|mcp__.*';hooks=@([pscustomobject]@{type='command';command=$command;timeout=86410;statusMessage='等待你在龙娘中确认本次操作'})}
  $retained=@()
  foreach($entry in @($config.hooks.PermissionRequest)){
    if(!$entry){continue}
    $others=@($entry.hooks|Where-Object{$_.command-notlike '*permission-hook-launch.ps1*'})
    if($others.Count){$entry.hooks=$others;$retained+=,$entry}
  }
  $config.hooks|Add-Member PermissionRequest (@($retained)+@($rule)) -Force
  $text=$config|ConvertTo-Json -Depth 24
  $null=[IO.Directory]::CreateDirectory($homeDir)
  # Preserve all unrelated hooks; never alter the client's trust records.
  [IO.File]::WriteAllText($file,$text,[Text.UTF8Encoding]::new($false))
  Write-Output 'Permission hook configured. Review/trust it in Codex Hooks before using pet approval buttons.'
}
