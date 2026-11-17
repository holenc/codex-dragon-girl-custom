function Initialize-WidgetInteractions {
  $script:interactionPanel=$null;$script:interactionCurrent=$null;$script:interactionUi=@{}
  $script:interactionNotices=@{};$script:interactionDismissed=@{};$script:interactionLastError=$null
  $script:interactionDir=Join-Path $script:dataDir 'interactions'
  $null=[IO.Directory]::CreateDirectory($script:interactionDir)
}
function Add-WidgetAttention($Event) {
  if($Event.type-eq 'attention-clear'){
    foreach($key in @($script:interactionNotices.Keys)){if($script:interactionNotices[$key].threadId-eq $Event.threadId){$script:interactionNotices.Remove($key)}}
    return
  }
  if(!$Event.requestId -or !$Event.threadId -or $Event.summary-isnot [string]){return}
  if($script:interactionNotices.Count-ge 64){return}
  $script:interactionNotices[$Event.requestId]=@{id=$Event.requestId;kind='notice';threadId=$Event.threadId;title=$Event.title;summary=$Event.summary;detail=$Event.detail;createdAt=$Event.endedAt;expiresAt=([long]$Event.endedAt+300000)}
}
function Complete-WidgetInteraction([string]$Decision) {
  $request=$script:interactionCurrent
  if(!$request){return}
  if($request.kind-eq 'permission'){
    $file=Join-Path $script:interactionDir ($request.id+'.request.json')
    try{
      $live=Get-Content -LiteralPath $file -Raw -Encoding UTF8 -ErrorAction Stop|ConvertFrom-Json
      if((Get-Command Test-WidgetInteractionPending -ErrorAction SilentlyContinue) -and !(Test-WidgetInteractionPending $live)){throw 'Codex 已处理或取消本次请求。'}
      if($live.id-ne $request.id -or $live.token-ne $request.token -or $live.fingerprint-ne $request.fingerprint -or $live.detail-cne $request.detail -or $live.summary-cne $request.summary -or $live.threadId-ne $request.threadId -or $live.turnId-ne $request.turnId -or [long]$live.expiresAt-le [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()){throw '本次请求已失效，请在 Codex 核对。'}
      $owner=Get-Process -Id ([int]$live.hookPid) -ErrorAction Stop
      if($owner.ProcessName-ne 'node' -or $owner.StartTime.ToUniversalTime()-gt [DateTimeOffset]::FromUnixTimeMilliseconds([long]$live.createdAt).UtcDateTime){throw '授权接收进程已改变。'}
      $response=@{id=$live.id;token=$live.token;fingerprint=$live.fingerprint;decision=$Decision}
      $responseFile=Join-Path $script:interactionDir ($live.id+'.response.json')
      $temp=$responseFile+'.tmp';[IO.File]::WriteAllText($temp,($response|ConvertTo-Json -Compress),[Text.UTF8Encoding]::new($false));[IO.File]::Move($temp,$responseFile)
    }catch{$script:interactionLastError=$_.Exception.Message;$script:interactionUi.Feedback.Text=$script:interactionLastError;$script:interactionUi.Feedback.Visibility=[Windows.Visibility]::Visible;$script:interactionUi.Summary.Visibility=[Windows.Visibility]::Collapsed;$script:interactionUi.DetailHost.Visibility=[Windows.Visibility]::Collapsed;return}
  }
  $script:interactionDismissed[$request.id]=$true
  Hide-WidgetInteractionBubble
  $script:interactionCurrent=$null
}
function Open-WidgetInteractionPanel {
  if($script:interactionPanel){return}
  $script:interactionPanel=[Windows.Markup.XamlReader]::Parse(@'
<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
 Width="184" Height="115" Visibility="Collapsed" Background="Transparent" HorizontalAlignment="Center" VerticalAlignment="Center">
 <Grid.Resources>
  <Style TargetType="Button"><Setter Property="FontSize" Value="13"/><Setter Property="Focusable" Value="False"/><Setter Property="Cursor" Value="Hand"/><Setter Property="Foreground" Value="#745A98"/><Setter Property="Background" Value="#EEE6F7"/><Setter Property="Padding" Value="2,1"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border CornerRadius="5" Padding="{TemplateBinding Padding}" Background="{TemplateBinding Background}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#DDCBEF"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
 </Grid.Resources>
 <Grid.RowDefinitions><RowDefinition Height="23"/><RowDefinition Height="*"/><RowDefinition Height="25"/></Grid.RowDefinitions>
 <DockPanel Margin="16,0,16,0"><Button x:Name="Close" DockPanel.Dock="Right" Content="×" Width="18" Height="18" Background="Transparent" ToolTip="稍后处理"/><TextBlock x:Name="Title" FontSize="15" FontWeight="Bold" Foreground="#745A98" TextTrimming="CharacterEllipsis" VerticalAlignment="Center"/></DockPanel>
 <TextBlock x:Name="Kind" Visibility="Collapsed"/>
 <TextBlock x:Name="Summary" Grid.Row="1" FontSize="15" LineHeight="18" TextWrapping="Wrap" Foreground="#594766" MaxHeight="54" TextAlignment="Center" VerticalAlignment="Center"/>
 <ScrollViewer x:Name="DetailHost" Grid.Row="1" Visibility="Collapsed" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"><TextBlock x:Name="Detail" TextWrapping="Wrap" FontSize="11" Foreground="#594766"/></ScrollViewer>
 <TextBlock x:Name="Feedback" Grid.Row="1" Visibility="Collapsed" FontSize="12" Foreground="#9C4771" TextWrapping="Wrap"/>
 <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Center">
  <Button x:Name="Details" Content="详情" Width="34" Height="22" Margin="0,0,3,0"/>
  <Button x:Name="Open" Content="Codex" Width="49" Height="22" Margin="0,0,3,0"/>
  <Button x:Name="Deny" Content="拒绝" Width="35" Height="22" Margin="0,0,3,0"/>
  <Button x:Name="Allow" Content="同意" Width="48" Height="22" ToolTip="仅同意本次操作"/>
 </StackPanel>
</Grid>
'@)
  foreach($name in @('Title','Kind','Summary','Detail','DetailHost','Details','Feedback','Open','Deny','Allow','Close')){$script:interactionUi[$name]=$script:interactionPanel.FindName($name)}
  $script:ui.SceneText.Children.Add($script:interactionPanel)|Out-Null
  $script:interactionPanel.Add_MouseLeftButtonUp({param($sender,$event)$event.Handled=$true})
  $script:interactionUi.Details.Add_Click({
    $show=$script:interactionUi.DetailHost.Visibility-ne [Windows.Visibility]::Visible
    $script:interactionUi.DetailHost.Visibility=if($show){[Windows.Visibility]::Visible}else{[Windows.Visibility]::Collapsed}
    $script:interactionUi.Summary.Visibility=if($show){[Windows.Visibility]::Collapsed}else{[Windows.Visibility]::Visible}
    $script:interactionUi.Details.Content=if($show){'返回'}else{'详情'}
  })
  $script:interactionUi.Allow.Add_Click({Complete-WidgetInteraction 'allow'})
  $script:interactionUi.Deny.Add_Click({Complete-WidgetInteraction 'deny'})
  $script:interactionUi.Open.Add_Click({
    if($script:interactionCurrent.kind-eq 'permission'){Complete-WidgetInteraction 'fallback'}
    [GptWidgetNative]::RestoreCodex($script:hostHandle)|Out-Null
  })
  $script:interactionUi.Close.Add_Click({if($script:interactionCurrent.kind-eq 'permission'){Complete-WidgetInteraction 'fallback'}elseif($script:interactionCurrent.source-eq 'activity'){[GptWidgetNative]::RestoreCodex($script:hostHandle)|Out-Null}else{Complete-WidgetInteraction 'dismiss'}})
}
function Show-WidgetInteractionBubble {
  if(!$script:interactionPanel){return}
  if($script:completionTemporary){Stop-TemporaryCompletion}
  foreach($timer in @($script:sceneTimer,$script:resetPhaseTimer,$script:closeTimer)){if($timer){$timer.Stop()}}
  $script:sceneTimer=$null;$script:resetPhaseTimer=$null;$script:closeTimer=$null
  $script:collapsed=$false;$script:bubbleMode='interaction';$script:sceneDeadline=0
  Apply-Scene;Set-BubbleState
}
function Hide-WidgetInteractionBubble {
  if($script:interactionPanel){$script:interactionPanel.Visibility=[Windows.Visibility]::Collapsed}
  if($script:bubbleMode-eq 'interaction'){Hide-Quota -KeepCompletion;$script:bubbleMode='quota';Apply-Scene}
}
function Tick-WidgetInteractions {
  try{
    if(Get-Command Read-WidgetActivity -ErrorAction SilentlyContinue){Read-WidgetActivity}
    $now=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds();$requests=@()
    foreach($file in @(Get-ChildItem -LiteralPath $script:interactionDir -Filter '*.request.json' -File -ErrorAction SilentlyContinue|Select-Object -First 64)){
      try{
        if($file.Length-gt 128KB){continue}
        $r=Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8|ConvertFrom-Json
        if($r.version-ne 1 -or $r.id-notmatch '^[0-9a-f-]{36}$' -or $file.Name-ne ($r.id+'.request.json') -or $r.token-notmatch '^[0-9a-f]{64}$' -or $r.fingerprint-notmatch '^[0-9a-f]{64}$' -or $r.kind-ne 'permission' -or [long]$r.expiresAt-le $now -or [long]$r.createdAt-gt $now+5000){continue}
        if(!(Get-Process -Id ([int]$r.hookPid) -ErrorAction SilentlyContinue)){continue}
        if((Get-Command Test-WidgetInteractionPending -ErrorAction SilentlyContinue) -and !(Test-WidgetInteractionPending $r)){continue}
        if(!(Test-Path -LiteralPath (Join-Path $script:interactionDir ($r.id+'.response.json')))){$requests+=,$r}
      }catch{}
    }
    foreach($id in @($script:interactionNotices.Keys)){if([long]$script:interactionNotices[$id].expiresAt-le $now){$script:interactionNotices.Remove($id)}}
    $requests+=@($script:interactionNotices.Values)
    # A native fallback notice must not duplicate its still-live hook buttons.
    $directIds=@($requests|Where-Object{$_.kind-eq 'permission'}|ForEach-Object{$_.id})
    $requests=@($requests|Where-Object{!$_.nativePermissionId -or $_.nativePermissionId-notin $directIds})
    $requests=@($requests|Where-Object{!$script:interactionDismissed.ContainsKey($_.id)}|Sort-Object @{Expression={if($_.kind-eq 'permission' -or $_.nativePermissionId){0}else{1}}},createdAt)
    if(Get-Command Update-WidgetActivityBadge -ErrorAction SilentlyContinue){Update-WidgetActivityBadge $requests.Count}
    $next=$requests|Select-Object -First 1
    if(!$next){Hide-WidgetInteractionBubble;$script:interactionCurrent=$null;return}
    if($script:drag -or $script:context.IsOpen){return}
    Open-WidgetInteractionPanel
    if(!$script:interactionCurrent -or $script:interactionCurrent.id-ne $next.id){
      $script:interactionCurrent=$next;$script:interactionUi.Title.Text=$next.title;$script:interactionUi.Summary.Text=$next.summary;$script:interactionUi.Detail.Text=$next.detail
      $script:interactionUi.Title.ToolTip=$next.title;$script:interactionUi.Summary.ToolTip=$next.summary
      $script:interactionUi.Summary.Visibility=[Windows.Visibility]::Visible;$script:interactionUi.DetailHost.Visibility=[Windows.Visibility]::Collapsed;$script:interactionUi.Details.Content='详情'
      $direct=$next.kind-eq 'permission'
      $script:interactionUi.Kind.Text=if($direct){'等待你的授权 · '+$next.tool}else{'等待你回答'}
      $script:interactionUi.Allow.Visibility=if($direct){[Windows.Visibility]::Visible}else{[Windows.Visibility]::Collapsed}
      $script:interactionUi.Deny.Visibility=$script:interactionUi.Allow.Visibility
      $script:interactionUi.Feedback.Text='';$script:interactionUi.Feedback.Visibility=[Windows.Visibility]::Collapsed
      $script:interactionUi.Open.ToolTip=if($direct){'交回 Codex 处理'}else{'打开 Codex 回答'}
    }
    if($script:bubbleMode-ne 'interaction' -or $script:collapsed){Show-WidgetInteractionBubble}
  }catch{$script:interactionLastError=$_.Exception.Message}
}
function Get-WidgetInteractionStatus {
  return @{panelVisible=[bool]($script:interactionPanel -and $script:interactionPanel.IsVisible);kind=if($script:interactionCurrent){$script:interactionCurrent.kind}else{$null};title=if($script:interactionCurrent){$script:interactionCurrent.title}else{$null};questionNotices=$script:interactionNotices.Count;error=$script:interactionLastError}
}
