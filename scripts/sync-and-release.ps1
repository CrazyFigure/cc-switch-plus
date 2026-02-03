# ============================================
# CC-Switch-Plus 同步上游 & 发布脚本 (PowerShell)
# ============================================

param(
    [Parameter(Position=0)]
    [ValidateSet("sync", "sync-tag", "build", "release", "tags", "diff", "help")]
    [string]$Action = "",

    [Parameter()]
    [string]$Tag = "",

    [Parameter()]
    [string]$ReleaseNotes = ""
)

$ErrorActionPreference = "Stop"
$UpstreamUrl = "https://github.com/farion1231/cc-switch.git"
$ProjectRoot = Split-Path -Parent $PSScriptRoot

# 切换到项目根目录
Set-Location $ProjectRoot

function Write-Info { param($msg) Write-Host "[信息] $msg" -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host "[成功] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "[警告] $msg" -ForegroundColor Yellow }
function Write-Err { param($msg) Write-Host "[错误] $msg" -ForegroundColor Red }

function Test-Command {
    param($cmd)
    return [bool](Get-Command $cmd -ErrorAction SilentlyContinue)
}

function Ensure-Upstream {
    $remotes = git remote
    if ($remotes -notcontains "upstream") {
        Write-Info "添加 upstream remote..."
        git remote add upstream $UpstreamUrl
    }
    Write-Info "获取上游更新..."
    git fetch upstream --tags
}

function Get-ProjectVersion {
    $packageJson = Get-Content "$ProjectRoot\package.json" | ConvertFrom-Json
    return $packageJson.version
}

function Show-Help {
    Write-Host @"

CC-Switch-Plus 同步 & 发布工具
==============================

用法: .\sync-and-release.ps1 <命令> [参数]

命令:
  sync              同步上游 main 分支的最新代码
  sync-tag -Tag <tag>   同步上游指定的 Tag (如 v3.10.0)
  build             构建项目生成安装包
  release [-Tag <tag>]  构建并发布到 GitHub Release
  tags              列出上游所有 Tags
  diff              查看本地与上游的差异
  help              显示此帮助信息

示例:
  .\sync-and-release.ps1 sync
  .\sync-and-release.ps1 sync-tag -Tag v3.10.0
  .\sync-and-release.ps1 build
  .\sync-and-release.ps1 release -Tag v3.10.3-plus

"@
}

function Resolve-MergeConflict {
    Write-Host ""
    Write-Warn "检测到合并冲突！"
    Write-Host ""
    Write-Host "冲突文件列表:" -ForegroundColor Yellow
    git diff --name-only --diff-filter=U
    Write-Host ""
    Write-Host "请选择处理方式:" -ForegroundColor Cyan
    Write-Host "  1. 打开 VS Code 解决冲突 (推荐)"
    Write-Host "  2. 保留我的修改 (放弃上游冲突部分)"
    Write-Host "  3. 使用上游版本 (放弃我的冲突部分)"
    Write-Host "  4. 中止合并，稍后手动处理"
    Write-Host ""

    $choice = Read-Host "请输入选项 (1-4)"

    switch ($choice) {
        "1" {
            Write-Info "正在打开 VS Code..."
            code .
            Write-Host ""
            Write-Host "请在 VS Code 中解决冲突后，执行以下命令完成合并:" -ForegroundColor Yellow
            Write-Host "  git add ." -ForegroundColor White
            Write-Host "  git commit -m 'chore: resolve merge conflicts'" -ForegroundColor White
            return $false
        }
        "2" {
            Write-Info "保留本地修改..."
            $conflictFiles = git diff --name-only --diff-filter=U
            foreach ($file in $conflictFiles) {
                git checkout --ours $file
                git add $file
            }
            git commit -m "chore: sync upstream, keep local changes on conflicts"
            Write-Success "已保留本地修改并完成合并"
            return $true
        }
        "3" {
            Write-Info "使用上游版本..."
            $conflictFiles = git diff --name-only --diff-filter=U
            foreach ($file in $conflictFiles) {
                git checkout --theirs $file
                git add $file
            }
            git commit -m "chore: sync upstream, accept upstream changes on conflicts"
            Write-Success "已使用上游版本并完成合并"
            return $true
        }
        "4" {
            Write-Info "中止合并..."
            git merge --abort
            Write-Warn "合并已中止，工作区已恢复"
            return $false
        }
        default {
            Write-Err "无效选项，合并已中止"
            git merge --abort
            return $false
        }
    }
}

function Sync-Latest {
    Write-Host "`n=== 同步上游最新代码 ===" -ForegroundColor Magenta

    Ensure-Upstream

    Write-Info "切换到 main 分支..."
    git checkout main

    # 检查是否有未提交的更改
    $status = git status --porcelain
    if ($status) {
        Write-Warn "检测到未提交的更改:"
        git status --short
        Write-Host ""
        $stash = Read-Host "是否暂存这些更改? (y/n)"
        if ($stash -eq "y" -or $stash -eq "Y") {
            git stash push -m "auto-stash before sync"
            Write-Info "更改已暂存，合并后会自动恢复"
            $didStash = $true
        } else {
            Write-Err "请先提交或暂存更改"
            return
        }
    }

    Write-Info "合并上游 main 分支..."
    $mergeResult = git merge upstream/main -m "chore: sync with upstream main" 2>&1

    if ($LASTEXITCODE -ne 0) {
        # 检查是否是冲突
        $hasConflict = git diff --name-only --diff-filter=U
        if ($hasConflict) {
            $resolved = Resolve-MergeConflict
            if (-not $resolved) {
                return
            }
        } else {
            Write-Err "合并失败: $mergeResult"
            return
        }
    } else {
        Write-Success "同步完成！"
    }

    # 恢复暂存
    if ($didStash) {
        Write-Info "恢复暂存的更改..."
        git stash pop
    }
}

function Sync-Tag {
    param([string]$TagName)

    Write-Host "`n=== 同步上游 Tag: $TagName ===" -ForegroundColor Magenta

    if ([string]::IsNullOrEmpty($TagName)) {
        Write-Err "请指定 Tag 名称，如: -Tag v3.10.0"
        return
    }

    Ensure-Upstream

    # 验证 Tag 是否存在
    $tagExists = git tag -l $TagName
    if (-not $tagExists) {
        Write-Err "Tag '$TagName' 不存在，请使用 'tags' 命令查看可用的 Tags"
        return
    }

    Write-Info "切换到 main 分支..."
    git checkout main

    # 检查是否有未提交的更改
    $status = git status --porcelain
    if ($status) {
        Write-Warn "检测到未提交的更改:"
        git status --short
        Write-Host ""
        $stash = Read-Host "是否暂存这些更改? (y/n)"
        if ($stash -eq "y" -or $stash -eq "Y") {
            git stash push -m "auto-stash before sync"
            Write-Info "更改已暂存，合并后会自动恢复"
            $didStash = $true
        } else {
            Write-Err "请先提交或暂存更改"
            return
        }
    }

    Write-Info "合并 Tag $TagName..."
    $mergeResult = git merge $TagName -m "chore: sync with upstream $TagName" 2>&1

    if ($LASTEXITCODE -ne 0) {
        $hasConflict = git diff --name-only --diff-filter=U
        if ($hasConflict) {
            $resolved = Resolve-MergeConflict
            if (-not $resolved) {
                return
            }
        } else {
            Write-Err "合并失败: $mergeResult"
            return
        }
    } else {
        Write-Success "已同步到 $TagName！"
    }

    # 恢复暂存
    if ($didStash) {
        Write-Info "恢复暂存的更改..."
        git stash pop
    }
}

function Build-Project {
    Write-Host "`n=== 构建项目 ===" -ForegroundColor Magenta

    if (-not (Test-Command "pnpm")) {
        Write-Err "未找到 pnpm，请先安装"
        return $false
    }

    Write-Info "安装依赖..."
    pnpm install

    Write-Info "开始构建..."
    pnpm build

    if ($LASTEXITCODE -ne 0) {
        Write-Err "构建失败"
        return $false
    }

    Write-Success "构建完成！"

    # 显示生成的文件
    $bundlePath = "$ProjectRoot\src-tauri\target\release\bundle"
    Write-Host "`n生成的安装包:" -ForegroundColor Yellow

    Get-ChildItem "$bundlePath\msi\*.msi" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Host "  - MSI: $($_.Name)" -ForegroundColor White
    }
    Get-ChildItem "$bundlePath\nsis\*.exe" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Host "  - NSIS: $($_.Name)" -ForegroundColor White
    }

    return $true
}

function Build-And-Release {
    param([string]$ReleaseTag)

    Write-Host "`n=== 构建并发布 ===" -ForegroundColor Magenta

    # 检查 gh CLI
    if (-not (Test-Command "gh")) {
        Write-Err "发布功能需要 GitHub CLI (gh)"
        Write-Host "  安装方法: winget install GitHub.cli"
        Write-Host "  安装后执行: gh auth login"
        return
    }

    # 检查登录状态
    $authStatus = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Err "请先登录 GitHub CLI: gh auth login"
        return
    }

    # 获取版本号
    $version = Get-ProjectVersion
    if ([string]::IsNullOrEmpty($ReleaseTag)) {
        $ReleaseTag = "v$version"
    }

    Write-Info "当前版本: $version"
    Write-Info "发布 Tag: $ReleaseTag"

    # 构建
    $buildSuccess = Build-Project
    if (-not $buildSuccess) {
        return
    }

    # 收集发布文件
    $bundlePath = "$ProjectRoot\src-tauri\target\release\bundle"
    $releaseFiles = @()

    Get-ChildItem "$bundlePath\msi\*.msi" -ErrorAction SilentlyContinue | ForEach-Object {
        $releaseFiles += $_.FullName
    }
    Get-ChildItem "$bundlePath\nsis\*.exe" -ErrorAction SilentlyContinue | ForEach-Object {
        $releaseFiles += $_.FullName
    }

    if ($releaseFiles.Count -eq 0) {
        Write-Err "未找到可发布的安装包"
        return
    }

    Write-Info "准备发布以下文件:"
    $releaseFiles | ForEach-Object { Write-Host "  - $_" }

    # 创建 Tag
    Write-Info "创建 Git Tag..."
    git tag -a $ReleaseTag -m "Release $ReleaseTag" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Tag $ReleaseTag 已存在，跳过创建"
    }

    Write-Info "推送 Tag 到远程..."
    git push origin $ReleaseTag

    # 创建 Release
    Write-Info "创建 GitHub Release..."

    $releaseNotes = @"
## What's Changed

- Synced with upstream
- Custom modifications for cc-switch-plus

See full changelog in commits.
"@

    $ghArgs = @(
        "release", "create", $ReleaseTag
    ) + $releaseFiles + @(
        "--title", $ReleaseTag,
        "--notes", $releaseNotes,
        "--latest"
    )

    & gh @ghArgs

    if ($LASTEXITCODE -eq 0) {
        Write-Success "发布完成！"
        $repoUrl = (git remote get-url origin) -replace "\.git$", ""
        Write-Host "`n查看发布: $repoUrl/releases/tag/$ReleaseTag" -ForegroundColor Cyan
    }
    else {
        Write-Err "创建 Release 失败"
    }
}

function Show-Tags {
    Write-Host "`n=== 上游 Tags ===" -ForegroundColor Magenta

    Ensure-Upstream

    Write-Host "`n上游所有 Tags (按版本排序):" -ForegroundColor Yellow
    Write-Host "----------------------------------------"
    git tag --sort=-version:refname
    Write-Host "----------------------------------------"
}

function Show-Diff {
    Write-Host "`n=== 本地与上游差异 ===" -ForegroundColor Magenta

    Ensure-Upstream

    Write-Host "`n本地比上游多的提交:" -ForegroundColor Yellow
    $localAhead = git log upstream/main..HEAD --oneline 2>$null
    if ($localAhead) { $localAhead } else { Write-Host "(无)" }

    Write-Host "`n上游比本地多的提交:" -ForegroundColor Yellow
    $upstreamAhead = git log HEAD..upstream/main --oneline 2>$null
    if ($upstreamAhead) { $upstreamAhead } else { Write-Host "(无)" }
}

# 交互式菜单
function Show-Menu {
    while ($true) {
        Write-Host "`n========================================"
        Write-Host "  CC-Switch-Plus 同步 & 发布工具"
        Write-Host "========================================`n"
        Write-Host "请选择操作:"
        Write-Host "  1. 同步上游最新代码"
        Write-Host "  2. 同步上游指定 Tag"
        Write-Host "  3. 构建项目"
        Write-Host "  4. 构建并发布到 GitHub Release"
        Write-Host "  5. 查看上游所有 Tags"
        Write-Host "  6. 查看本地与上游差异"
        Write-Host "  0. 退出`n"

        $choice = Read-Host "请输入选项 (0-6)"

        switch ($choice) {
            "1" { Sync-Latest }
            "2" {
                $tagInput = Read-Host "请输入 Tag 名称 (如 v3.10.0)"
                Sync-Tag -TagName $tagInput
            }
            "3" { Build-Project }
            "4" {
                $tagInput = Read-Host "请输入发布 Tag (留空使用当前版本)"
                Build-And-Release -ReleaseTag $tagInput
            }
            "5" { Show-Tags }
            "6" { Show-Diff }
            "0" {
                Write-Host "`n再见！"
                return
            }
            default { Write-Err "无效选项，请重新选择" }
        }

        Write-Host "`n按任意键继续..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

# 主逻辑
switch ($Action) {
    "sync" { Sync-Latest }
    "sync-tag" { Sync-Tag -TagName $Tag }
    "build" { Build-Project }
    "release" { Build-And-Release -ReleaseTag $Tag }
    "tags" { Show-Tags }
    "diff" { Show-Diff }
    "help" { Show-Help }
    default { Show-Menu }
}
