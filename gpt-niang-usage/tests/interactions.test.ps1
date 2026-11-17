$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms
$appDir=Split-Path $PSScriptRoot -Parent
. ([ScriptBlock]::Create([IO.File]::ReadAllText((Join-Path $appDir 'runtime\interactions.ps1'),[Text.Encoding]::UTF8)))
$testDir=Join-Path ([IO.Path]::GetTempPath()) ('niang-interaction-ui-'+[Guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory($testDir);$script:dataDir=$testDir
$fixture=$null
try{
  [IO.File]::WriteAllText((Join-Path $testDir 'presence.json'),(@{at=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds();visible=$true}|ConvertTo-Json))
  $script:window=[Windows.Markup.XamlReader]::Parse([IO.File]::ReadAllText((Join-Path $appDir 'widget.xaml'),[Text.Encoding]::UTF8))
  $script:ui=@{SceneText=$script:window.FindName('SceneText')}
  Initialize-WidgetInteractions;Open-WidgetInteractionPanel
  if($script:interactionPanel-is [Windows.Window] -or $script:interactionPanel.Parent-ne $script:ui.SceneText){throw 'Interaction must be embedded in the original bubble'}
  if($script:interactionPanel.IsVisible){throw 'Test panel must stay hidden'}
  $config=Get-Content -LiteralPath (Join-Path $appDir 'installation.json') -Raw -Encoding UTF8|ConvertFrom-Json
  $fixture=Start-Process -FilePath $config.nodePath -ArgumentList @(('"'+(Join-Path $PSScriptRoot 'permission-hook-fixture.mjs')+'"'),('"'+$testDir+'"')) -WindowStyle Hidden -PassThru
  $deadline=[DateTime]::UtcNow.AddSeconds(4)
  do{$requestFile=Get-ChildItem -LiteralPath $script:interactionDir -Filter '*.request.json'|Select-Object -First 1;if($requestFile){break};Start-Sleep -Milliseconds 50}while([DateTime]::UtcNow-lt $deadline)
  if(!$requestFile){throw 'Fixture request was not created'}
  $script:interactionCurrent=Get-Content -LiteralPath $requestFile.FullName -Raw -Encoding UTF8|ConvertFrom-Json
  $script:interactionUi.Allow.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
  if(!$fixture.WaitForExit(4000)){throw 'Fixture failed to consume the button response'}
  $result=Get-Content -LiteralPath (Join-Path $testDir 'result.json') -Raw|ConvertFrom-Json
  if($result.hookSpecificOutput.decision.behavior-ne 'allow'){throw 'Button did not return the one-request decision'}
  Add-WidgetAttention @{type='attention';requestId='q1';threadId='thread1';title='测试';summary='选择哪项？';detail='甲 / 乙';endedAt=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()}
  if($script:interactionNotices.Count-ne 1){throw 'Question notice was not queued'}
  Add-WidgetAttention @{type='attention-clear';threadId='thread1'}
  if($script:interactionNotices.Count-ne 0){throw 'Resolved question was not removed'}
  Write-Output 'Hidden WPF panel, actual button-to-hook round trip and question clearing passed. No command executed.'
}finally{
  if($script:window){$script:window.Close()}
  if($fixture){if(!$fixture.HasExited){$fixture.Kill()};$fixture.Dispose()}
  $resolved=[IO.Path]::GetFullPath($testDir);$tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
  if(!$resolved.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Unexpected test cleanup path'}
  Remove-Item -LiteralPath $resolved -Recurse -Force
}
