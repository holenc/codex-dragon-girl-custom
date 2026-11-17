param([string]$OutputDirectory)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms
$appDir=Split-Path $PSScriptRoot -Parent
. ([ScriptBlock]::Create([IO.File]::ReadAllText((Join-Path $appDir 'runtime\interactions.ps1'),[Text.Encoding]::UTF8)))
$script:dataDir=$OutputDirectory;$null=[IO.Directory]::CreateDirectory($OutputDirectory)
$script:window=[Windows.Markup.XamlReader]::Parse([IO.File]::ReadAllText((Join-Path $appDir 'widget.xaml'),[Text.Encoding]::UTF8))
$script:ui=@{SceneText=$script:window.FindName('SceneText')}
$script:window.FindName('Girl').Source=[Windows.Media.Imaging.BitmapImage]::new([Uri](Join-Path $appDir 'assets\gpt-dragon-niang-bust.png'))
foreach($name in @('QuotaText','QuoteText','Refresh')){$script:window.FindName($name).Visibility=[Windows.Visibility]::Collapsed}
Initialize-WidgetInteractions;Open-WidgetInteractionPanel
$script:interactionPanel.Visibility=[Windows.Visibility]::Visible
$script:interactionUi.Title.Text='作业 · 待确认';$script:interactionUi.Summary.Text='允许修改作业文件？'
$script:interactionUi.Detail.Text='仅为布局测试，不会执行操作。'
$visual=$script:window.Content
$visual.Measure([Windows.Size]::new(378,378));$visual.Arrange([Windows.Rect]::new(0,0,378,378));$visual.UpdateLayout()
if($script:interactionPanel.ActualWidth-gt 184.1 -or $script:interactionPanel.ActualHeight-gt 115.1){throw 'Interaction exceeds the original bubble content area'}
$bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new(756,756,192,192,[Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($visual)
$encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
$file=Join-Path $OutputDirectory 'interaction-in-original-bubble.png';$stream=[IO.File]::OpenWrite($file);try{$encoder.Save($stream)}finally{$stream.Dispose()}
$script:window.Close();Write-Output $file
