$ErrorActionPreference='Stop'
try {
  $inputJson=[Console]::In.ReadToEnd()
  $config=Get-Content -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'installation.json') -Raw -Encoding UTF8|ConvertFrom-Json
  $inputJson|& $config.nodePath (Join-Path $PSScriptRoot 'permission-hook.mjs')
}catch{
  # No decision means Codex continues with its own normal approval prompt.
  exit 0
}
