param([string]$OutputDirectory)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms
$appDir=Split-Path $PSScriptRoot -Parent
. ([ScriptBlock]::Create([IO.File]::ReadAllText((Join-Path $appDir 'runtime\interactions.ps1'),[Text.Encoding]::UTF8)))
$script:dataDir=$OutputDirectory;$null=[IO.Directory]::CreateDirectory($OutputDirectory)
$script:window=[Windows.Markup.XamlReader]::Parse([IO.File]::ReadAllText((Join-Path $appDir 'widget.xaml'),[Text.Encoding]::UTF8))
$script:ui=@{SceneText=$script:window.FindName('SceneText')}
$script:window.FindName('Girl').Source=[Windows.Media.Imaging.BitmapImage]::new([Uri](Join-Path $appDir 'assets\gpt-dragon-niang-bust.png'))
. ([ScriptBlock]::Create([IO.File]::ReadAllText((Join-Path $appDir 'runtime\quote-layout.ps1'),[Text.Encoding]::UTF8)))
$script:bubbleMode='quota';Set-WidgetSceneLayout
foreach($pair in @(@('ShortLeft','0%'),@('WeekLeft','84%'),@('ShortReset','今日 19:44 重置'),@('WeekReset','11-23 14:44 重置'),@('CreditBalance','493.58 credits'),@('CreditDollars','≈ $19.74'))){$script:window.FindName($pair[0]).Text=$pair[1]}
$visual=$script:window.Content
$visual.Measure([Windows.Size]::new(378,378));$visual.Arrange([Windows.Rect]::new(0,0,378,378));$visual.UpdateLayout()

$bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new(756,756,192,192,[Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($visual)
$encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
$file=Join-Path $OutputDirectory 'quota-with-credits.png';$stream=[IO.File]::OpenWrite($file);try{$encoder.Save($stream)}finally{$stream.Dispose()}
$script:window.Close();Write-Output $file
