$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationCore,PresentationFramework,WindowsBase
$appDir=Split-Path $PSScriptRoot -Parent
. (Join-Path $appDir 'runtime/characters.ps1')
. (Join-Path $appDir 'runtime/quota-expression.ps1')
$now=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
function Fixture($used,$credits,$week=84){@{ok=$true;queryOk=$true;observedAt=$now;credits=@{balance=$credits};windows=@(@{minutes=300;used=$used;resetsAt=($now/1000+300)},@{minutes=10080;remaining=$week})}}
foreach($case in @(@(90,0,84,'normal'),@(90,2,0,'money'),@(90,0,0,'closed'),@(100,2,84,'money'),@(100,2,0,'money'),@(100,0,84,'drooling'),@(100,0,5,'drooling'),@(100,0,4.999,'closed'),@(100,$null,0,'normal'))){
  $actual=Get-WidgetQuotaExpression (Fixture $case[0] $case[1] $case[2]) $now
  if($actual-ne $case[3]){throw "Wrong state: expected $($case[3]), got $actual"}
}
$s=Fixture 100 0 0;$s.queryOk=$false;if((Get-WidgetQuotaExpression $s $now)-ne 'normal'){throw 'Failed snapshot'}
$s=Fixture 21 386 0;$s.queryOk=$false;$s.accountKey='a'*64;$s.clearPrevious=$false
if((Get-WidgetQuotaExpression $s $now)-ne 'money'){throw 'Recent same-account weekly exhaustion cache was lost'}
$s.accountVerified=$false;if((Get-WidgetQuotaExpression $s $now)-ne 'normal'){throw 'Unverified account cache was used'}
$s=Fixture 21 386 0;$s.windows[1].resetsAt=$now/1000-1
if((Get-WidgetQuotaExpression $s $now)-ne 'normal'){throw 'Weekly reset did not restore normal expression'}
$s=Fixture 100 0 0;$s.observedAt=$now-180001;if((Get-WidgetQuotaExpression $s $now)-ne 'normal'){throw 'Old snapshot'}
$s=Fixture 100 0 0;$s.windows[0].resetsAt=$now/1000-1;if((Get-WidgetQuotaExpression $s $now)-ne 'closed'){throw 'Five-hour reset must not bypass exhausted weekly quota'}
$s.windows[1].resetsAt=$now/1000-1;if((Get-WidgetQuotaExpression $s $now)-ne 'normal'){throw 'Reset recovery'}
$script:appDir=$appDir;$script:characterId='gpt-dragon';$script:ui=@{Girl=[Windows.Controls.Image]::new()}
$script:quotaExpressionCache=@{}
foreach($case in @(@(100,10,84,'money'),@(100,0,84,'drooling'),@(100,0,0,'closed'),@(21,10,0,'money'),@(21,0,0,'closed'),@(21,0,98,'normal'),@(0,0,84,'normal'))){
  $script:status=Fixture $case[0] $case[1] $case[2];Update-WidgetQuotaExpression
  if($script:quotaExpressionError -or $script:quotaExpressionKey-ne $case[3]){throw "Image activation failed: $script:quotaExpressionError"}
  if($script:alphaPixels.Length-ne $script:bitmap.PixelWidth*$script:bitmap.PixelHeight*4){throw 'Click-through alpha map mismatch'}
  if($script:ui.Girl.Source-ne $script:bitmap){throw 'Image source mismatch'}
}
'Quota expression rules and image transitions passed.'
