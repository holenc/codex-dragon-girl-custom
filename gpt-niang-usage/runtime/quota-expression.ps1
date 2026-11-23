function Get-WidgetQuotaExpression($Status,[long]$Now=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()) {
  # Unknown, failed or old snapshots must not be interpreted as an empty wallet.
  if(!$Status -or $Status.ok-ne $true -or $Status.accountVerified-eq $false -or !$Status.observedAt -or $Now-[double]$Status.observedAt-gt 180000){return 'normal'}
  # The refresh queue retains a recently verified same-account snapshot after
  # a transient query failure. Keep using that snapshot until its normal expiry.
  if($Status.queryOk-ne $true -and !($Status.accountKey-match '^[a-f0-9]{64}$' -and $Status.clearPrevious-eq $false)){return 'normal'}
  $short=@($Status.windows|Where-Object {$_.minutes-eq 300})|Select-Object -First 1
  $week=@($Status.windows|Where-Object {$_.minutes-eq 10080})|Select-Object -First 1
  $shortSpent=$short -and $null-ne $short.used -and [double]$short.used-ge 100 -and (!$short.resetsAt -or [double]$short.resetsAt*1000-gt $Now)
  $weekSpent=$week -and (($null-ne $week.remaining -and [double]$week.remaining-le 0) -or ($null-ne $week.used -and [double]$week.used-ge 100)) -and (!$week.resetsAt -or [double]$week.resetsAt*1000-gt $Now)
  $balance=$Status.credits.balance
  if(($shortSpent -or $weekSpent) -and ($Status.credits.unlimited-eq $true -or ($null-ne $balance -and [double]$balance-gt 0))){return 'money'}
  if(!$shortSpent -and !$weekSpent){return 'normal'}
  if($null-eq $balance){return 'normal'}
  if([double]$balance-lt 0){return 'normal'}
  if($weekSpent -or ($week -and $null-ne $week.remaining -and [double]$week.remaining-lt 5 -and (!$week.resetsAt -or [double]$week.resetsAt*1000-gt $Now))){return 'closed'}
  return 'drooling'
}

function Update-WidgetQuotaExpression {
  if($script:characterId-ne 'gpt-dragon'){return}
  $state=Get-WidgetQuotaExpression $script:status
  if((Get-Command Get-WidgetActivityFailures -ErrorAction SilentlyContinue) -and @(Get-WidgetActivityFailures).Count-gt 0){$state='drooling'}
  if($script:quotaExpressionKey-eq $state){return}
  try{
    if(!$script:quotaExpressionCache){$script:quotaExpressionCache=@{}}
    if(!$script:quotaExpressionCache.ContainsKey($state)){
      $file=switch($state){'money'{'gpt-dragon-money.png'} 'closed'{'gpt-dragon-closed.png'} 'drooling'{'gpt-dragon-drooling.png'} default{'gpt-dragon-niang-bust.png'}}
      $image=Read-WidgetCharacterImage (Join-Path $script:appDir ('assets\'+$file))
      $alpha=[Windows.Media.Imaging.FormatConvertedBitmap]::new($image,[Windows.Media.PixelFormats]::Bgra32,$null,0)
      $alpha.Freeze();$stride=$image.PixelWidth*4;$pixels=New-Object byte[] ($stride*$image.PixelHeight)
      $alpha.CopyPixels($pixels,$stride,0)
      $script:quotaExpressionCache[$state]=@{image=$image;alpha=$alpha;stride=$stride;pixels=$pixels}
    }
    $entry=$script:quotaExpressionCache[$state]
    $script:bitmap=$entry.image;$script:alphaBitmap=$entry.alpha;$script:alphaStride=$entry.stride;$script:alphaPixels=$entry.pixels
    $script:ui.Girl.Source=$entry.image
    if($script:widgetColors){foreach($overlay in @($script:widgetColors.halo,$script:widgetColors.tint)){if($overlay -and $overlay.OpacityMask){$overlay.OpacityMask.ImageSource=$entry.image}}}
    $script:quotaExpressionKey=$state;$script:quotaExpressionError=$null
  }catch{$script:quotaExpressionError=$_.Exception.Message}
}
