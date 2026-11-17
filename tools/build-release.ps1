param([Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$app=Join-Path $root 'gpt-niang-usage'
$manifest=Get-Content (Join-Path $app 'package.json') -Raw -Encoding UTF8|ConvertFrom-Json
$version=$manifest.version
$out=[IO.Path]::GetFullPath($OutputDirectory)
if(Test-Path -LiteralPath $out){throw 'Choose a new, empty output directory.'}
$stage=Join-Path $out 'source/GPT娘额度挂件'
$null=[IO.Directory]::CreateDirectory($stage)
function Copy-ReleaseFile($Source,$Relative){
  $target=Join-Path $stage $Relative
  $null=[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
  [IO.File]::Copy($Source,$target,$false)
}
foreach($name in @('README.md','CHANGELOG.md','LICENSE','UPSTREAM-README.md','UPSTREAM-CHANGELOG.md','安装GPT娘.cmd','打开GPT娘.cmd','停用GPT娘.cmd','检测套餐.cmd')){
  Copy-ReleaseFile (Join-Path $root $name) $name
}
foreach($dir in @('.agents','gpt-niang-usage/assets','gpt-niang-usage/runtime','gpt-niang-usage/tests','gpt-niang-usage/.codex-plugin','tools')){
  foreach($file in Get-ChildItem -LiteralPath (Join-Path $root $dir) -Recurse -File -Force){
    if($file.Attributes-band [IO.FileAttributes]::ReparsePoint){throw 'Links may not be packaged.'}
    if($file.Name-match '\.(?:bak|tmp|log)$'){continue}
    Copy-ReleaseFile $file.FullName ([IO.Path]::GetRelativePath($root,$file.FullName))
  }
}
foreach($name in @('Install.ps1','Uninstall.ps1','Detect-Plan.ps1','launch.vbs','supervisor.vbs','widget.ps1','widget.xaml','package.json','LICENSE','README.md','local-build.json','custom-build.json','custom-defaults.json')){
  Copy-ReleaseFile (Join-Path $app $name) ('gpt-niang-usage/'+$name)
}
[IO.File]::WriteAllText((Join-Path $stage 'gpt-niang-usage/.mcp.json'),'{"mcpServers":{"gpt-niang-usage":{"command":"node","args":["./runtime/mcp.mjs"]}}}',[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $stage '.gitignore'),"**/installation.json`n**/.mcp.json`n**/*.bak`n**/*.log`n**/*.tmp`nstate/`nupdates/`nrelease/`n",[Text.UTF8Encoding]::new($false))
$forbidden=@(Get-ChildItem -LiteralPath $stage -Recurse -File -Force|Where-Object{$_.Name-match '^(?:installation|settings|auth|hooks|presence|activity|update-preferences|update-transaction)\.json$' -or $_.Extension-in @('.sqlite','.jsonl')})
if($forbidden.Count){throw ('Local state was included: '+($forbidden.Name-join ', '))}
foreach($file in Get-ChildItem -LiteralPath $stage -Recurse -File -Force|Where-Object{$_.Extension-in @('.ps1','.mjs','.json','.md','.txt','.cmd','.vbs','.cs','.xaml')}){
  $text=[IO.File]::ReadAllText($file.FullName)
  if($text-match '(?i)C:(?:\\+|/)Users(?:\\+|/)(?:Administrator|ADMINI~1)(?:\\+|/)' -or $text-match 'gh[pousr]_[A-Za-z0-9]{25,}|sk-proj-[A-Za-z0-9_-]{20,}'){
    throw ('Machine path or credential pattern in '+[IO.Path]::GetRelativePath($stage,$file.FullName))
  }
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zipName='gpt-niang-usage-widget-v'+$version+'-windows.zip'
$zip=Join-Path $out $zipName
[IO.Compression.ZipFile]::CreateFromDirectory($stage,$zip,[IO.Compression.CompressionLevel]::Optimal,$true)
$hash=(Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText((Join-Path $out 'SHA256SUMS.txt'),$hash+'  '+$zipName+"`n",[Text.UTF8Encoding]::new($false))
[pscustomobject]@{version=$version;source=$stage;zip=$zip;sha256=$hash;bytes=(Get-Item $zip).Length}|ConvertTo-Json
