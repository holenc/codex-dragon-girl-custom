$ErrorActionPreference='Stop'
$appDir=Split-Path $PSScriptRoot -Parent
$configPath=Join-Path $appDir 'installation.json'
$config=[IO.File]::ReadAllText($configPath,[Text.Encoding]::UTF8)|ConvertFrom-Json
. (Join-Path $PSScriptRoot 'runtime-paths.ps1')
Repair-WidgetRuntimePaths $config $configPath -CheckCurrent
# Relay bytes, not PowerShell objects, so MCP JSON-RPC never gains formatting,
# profile output or a dependency on an obsolete versioned Node executable path.
Add-Type -TypeDefinition @'
using System;using System.Diagnostics;using System.Threading.Tasks;
public static class GptNiangMcpRelay {
 public static int Run(string node,string script){
  var info=new ProcessStartInfo(node,"\""+script+"\"");
  info.UseShellExecute=false;info.CreateNoWindow=true;
  info.RedirectStandardInput=true;info.RedirectStandardOutput=true;info.RedirectStandardError=true;
  using(var process=Process.Start(info)){
   var input=Console.OpenStandardInput().CopyToAsync(process.StandardInput.BaseStream);
   var output=process.StandardOutput.BaseStream.CopyToAsync(Console.OpenStandardOutput());
   var error=process.StandardError.BaseStream.CopyToAsync(Console.OpenStandardError());
   while(!process.WaitForExit(100))if(input.IsCompleted){
    try{process.StandardInput.Close();}catch{}
    if(!process.WaitForExit(2000))process.Kill();break;
   }
   process.WaitForExit();Task.WaitAll(new[]{output,error},2000);return process.ExitCode;
  }
 }
}
'@
exit [GptNiangMcpRelay]::Run($config.nodePath,(Join-Path $PSScriptRoot 'mcp.mjs'))
