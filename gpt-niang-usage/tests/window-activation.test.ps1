$ErrorActionPreference='Stop'
$appDir=Split-Path $PSScriptRoot -Parent
$source=[IO.File]::ReadAllText((Join-Path $appDir 'widget.ps1'),[Text.Encoding]::UTF8)
$native=[regex]::Match($source,"(?s)Add-Type -TypeDefinition @'\r?\n(.*?)\r?\n'@")
if(!$native.Success){throw 'Native widget helper was not found'}
Add-Type -TypeDefinition $native.Groups[1].Value
foreach($case in @(@($false,$false,$false,'app-activation'),@($false,$true,$false,'app-activation'),@($true,$true,$false,'restore-minimized'),@($true,$false,$true,'already-foreground'),@($true,$false,$false,'app-activation'))){
  $route=[GptWidgetNative]::SelectRestoreRoute($case[0],$case[1],$case[2])
  if($route-ne $case[3]){throw "Unexpected activation route: $route"}
}
if(!$source.Contains('if(route=="restore-minimized")ShowWindowAsync(target,9);')){throw 'Native restore must be restricted to minimized windows'}
'Native helper compiles; hidden, minimized and foreground routes passed. No Codex window was changed.'
