<#
.SYNOPSIS
    根据 docs/images/README.md 中的对照表，把 README.md 里的截图占位标记
    替换为真实图片引用。仅当对应文件确实存在于 docs/images/ 时才替换。

.DESCRIPTION
    README.md 中的占位标记形如：

        <!-- Screenshot: VMware Workstation 17.6.2 关于对话框 -->

    docs/images/README.md 中维护了一张「占位标记 -> 建议文件名」的对照表。
    本脚本读取该表，对每个已就位的图片生成引用：

        ![VMware Workstation 17.6.2 关于对话框](docs/images/01-vmware-version.png)

    未能找到文件的占位标记会原样保留，并在结果中列出，便于继续补图。

.PARAMETER RepoRoot
    仓库根目录，默认为本脚本所在目录的上一级。

.PARAMETER WhatIf
    只列出将要进行的替换，不写入文件。

.EXAMPLE
    .\Sync-ScreenshotImages.ps1 -WhatIf

.EXAMPLE
    .\Sync-ScreenshotImages.ps1
#>
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}
$readme = Join-Path $RepoRoot 'README.md'
$mapDoc = Join-Path $RepoRoot 'docs\images\README.md'
$imgDir = Join-Path $RepoRoot 'docs\images'

foreach ($p in @($readme, $mapDoc)) {
    if (-not (Test-Path -LiteralPath $p)) { throw "找不到文件：$p" }
}

# 解析对照表：| `<!-- Screenshot: 描述 -->` | `NN-name.png` |
$rowRe = '^\|\s*`<!-- Screenshot: (?<desc>.+?) -->`\s*\|\s*`(?<file>[^`]+)`\s*\|'
$map = @()
foreach ($line in [IO.File]::ReadAllLines($mapDoc)) {
    $m = [regex]::Match($line, $rowRe)
    if ($m.Success) {
        $map += [pscustomobject]@{
            Desc = $m.Groups['desc'].Value.Trim()
            File = $m.Groups['file'].Value.Trim()
        }
    }
}

Write-Host ("对照表条目：{0} 条" -f $map.Count) -ForegroundColor Cyan
if ($map.Count -eq 0) { throw '未能从 docs/images/README.md 解析出对照表，请检查表格格式。' }

$text = [IO.File]::ReadAllText($readme)
$orig = $text
$done = @()
$pending = @()

foreach ($item in $map) {
    $placeholder = '<!-- Screenshot: {0} -->' -f $item.Desc
    if ($text -notlike ('*' + $placeholder + '*')) {
        $pending += [pscustomobject]@{ Desc = $item.Desc; File = $item.File; State = 'README 中无此占位标记' }
        continue
    }

    $imgPath = Join-Path $imgDir $item.File
    if (-not (Test-Path -LiteralPath $imgPath)) {
        $pending += [pscustomobject]@{ Desc = $item.Desc; File = $item.File; State = '图片未就位' }
        continue
    }

    $size = [math]::Round((Get-Item -LiteralPath $imgPath).Length / 1KB, 1)
    $replacement = '![{0}](docs/images/{1})' -f $item.Desc, $item.File
    $text = $text.Replace($placeholder, $replacement)
    $done += [pscustomobject]@{ Desc = $item.Desc; File = $item.File; SizeKB = $size }
}

Write-Host ''
Write-Host ('已替换 {0} 处：' -f $done.Count) -ForegroundColor Green
$done | ForEach-Object { Write-Host ('  [{0,6} KB] {1}  ->  {2}' -f $_.SizeKB, $_.File, $_.Desc) }

Write-Host ''
Write-Host ('仍待补充 {0} 处：' -f $pending.Count) -ForegroundColor Yellow
$pending | ForEach-Object { Write-Host ('  [{0}] {1}  ({2})' -f $_.State, $_.File, $_.Desc) }

if ($text -eq $orig) {
    Write-Host ''
    Write-Host 'README 无变化，未写入。' -ForegroundColor DarkGray
    return
}

if ($WhatIf) {
    Write-Host ''
    Write-Host '-WhatIf：未写入文件。' -ForegroundColor Yellow
    return
}

[IO.File]::WriteAllText($readme, $text, (New-Object System.Text.UTF8Encoding($false)))
Write-Host ''
Write-Host ('已更新 {0}' -f $readme) -ForegroundColor Green
Write-Host '后续：git add -A ; git commit -m "docs: 补充截图" ; git push' -ForegroundColor Cyan
