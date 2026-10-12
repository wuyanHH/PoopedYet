#!/usr/bin/env pwsh
# 按分组渲染视觉稿 PNG。
#
# 用法： pwsh .design/build-shots.ps1
#
# 流程：先量出每组 .stage 的实际宽高，再按实测尺寸开窗口截图。
# 为什么要先量：headless Chrome 的 --screenshot 只截「窗口大小」这块区域，
# 不会自动截整页；窗口给小了内容被切，给大了底部一片空白。
#
# ⚠ 踩过的坑（改这个脚本前先看）：
#   1. "--window-size=$w,$h" 必须整体加引号。裸写会让 PowerShell 把逗号解析成数组，
#      Chrome 收到两个参数后静默回退到默认窗口（约 495x261），出来的图全糊。
#   2. 量高度要量 .stage，不能量 body —— body 有 min-height:100vh，
#      量出来的是被视口撑开的高度，不是内容高度。
#   3. 分组切换走 JS（location.hash），不要用 CSS :has()/:target，
#      在无头 Chrome 里行为不稳定，曾导致 4 组同时渲染。

$ErrorActionPreference = 'Stop'
$d = $PSScriptRoot

$chrome = @(
  "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
  "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
  "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
  "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $chrome) { throw '没找到 Chrome / Edge' }

$html = Get-Content "$d\ui-reference.html" -Raw -Encoding UTF8

# 量尺寸用的探针：只读 .stage 的 border box，不改变布局
$probe = @'
window.addEventListener('load',function(){setTimeout(function(){
  var s=document.querySelector('.stage'), r=s.getBoundingClientRect();
  var box=document.querySelector('.grp[style*="block"] .phones');
  var us=[].slice.call(box.querySelectorAll('.unit')), t={};
  us.forEach(function(u){ t[u.offsetTop]=1; });
  document.body.innerHTML='<pre id="M">'+Math.ceil(r.width)+'|'+Math.ceil(r.height)+'|'+Object.keys(t).length+'</pre>';
},900)});
'@

$probeFile = Join-Path $d '_probe.html'
$shotFile  = Join-Path $d '_shot.html'
$html.Replace('</body>', "<script>`n$probe`n</script>`n</body>") | Set-Content $probeFile -Encoding UTF8 -NoNewline
$html | Set-Content $shotFile -Encoding UTF8 -NoNewline

try {
  foreach ($g in @('main', 'history', 'people', 'calendar', 'calnav')) {
    $dom = & $chrome --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files `
      "--force-device-scale-factor=1" "--window-size=2400,3000" --virtual-time-budget=9000 `
      --dump-dom "file:///$($probeFile -replace '\\','/')#$g" 2>$null | Out-String

    $m = [regex]::Matches($dom, '(?s)<pre id="M">(\d+)\|(\d+)\|(\d+)</pre>')
    if (-not $m.Count) { Write-Warning "$g 尺寸探测失败，跳过"; continue }
    $sw   = [int]$m[$m.Count-1].Groups[1].Value
    $sh   = [int]$m[$m.Count-1].Groups[2].Value
    $rows = [int]$m[$m.Count-1].Groups[3].Value
    if ($rows -ne 1) { Write-Warning "$g 手机排成了 $rows 行（应为 1 行）" }

    $winW = $sw + 130     # 补上 body 左右内边距 + 窗口与视口的宽度差
    $winH = $sh + 230     # 同理补高度差，避免底部被切
    $out  = Join-Path $d "ui-$g.png"
    if (Test-Path $out) { Remove-Item $out -Force }

    & $chrome --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files `
      "--force-device-scale-factor=1.6" "--window-size=$winW,$winH" --virtual-time-budget=9000 `
      --screenshot="$out" "file:///$($shotFile -replace '\\','/')#$g" 2>&1 | Out-Null

    Add-Type -AssemblyName System.Drawing
    $img = [System.Drawing.Image]::FromFile($out)
    Write-Host ("{0,-9} stage={1}x{2}  窗口={3}x{4}  PNG={5}x{6}  {7} KB" -f `
      $g, $sw, $sh, $winW, $winH, $img.Width, $img.Height, [math]::Round((Get-Item $out).Length / 1KB))
    $img.Dispose()
  }
}
finally {
  Remove-Item $probeFile, $shotFile -Force -ErrorAction SilentlyContinue
}
