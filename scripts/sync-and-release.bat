@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: ============================================
:: CC-Switch-Plus 同步上游 & 发布脚本
:: ============================================

echo.
echo ========================================
echo   CC-Switch-Plus 同步 ^& 发布工具
echo ========================================
echo.

:: 检查必要工具
where git >nul 2>&1 || (
    echo [错误] 未找到 git，请先安装 Git
    pause
    exit /b 1
)

where pnpm >nul 2>&1 || (
    echo [错误] 未找到 pnpm，请先安装 pnpm
    pause
    exit /b 1
)

where gh >nul 2>&1 || (
    echo [警告] 未找到 GitHub CLI (gh)，发布功能将不可用
    echo        安装方法: winget install GitHub.cli
    echo.
    set "GH_AVAILABLE=0"
) || (
    set "GH_AVAILABLE=1"
)

:: 进入项目目录
cd /d "%~dp0.."
echo [信息] 工作目录: %cd%
echo.

:: 菜单选择
:MENU
echo 请选择操作:
echo   1. 同步上游最新代码 (sync upstream)
echo   2. 同步上游指定 Tag
echo   3. 构建项目 (build)
echo   4. 构建并发布到 GitHub Release
echo   5. 查看上游所有 Tags
echo   6. 查看本地与上游差异
echo   0. 退出
echo.
set /p choice="请输入选项 (0-6): "

if "%choice%"=="1" goto SYNC_LATEST
if "%choice%"=="2" goto SYNC_TAG
if "%choice%"=="3" goto BUILD
if "%choice%"=="4" goto BUILD_AND_RELEASE
if "%choice%"=="5" goto LIST_TAGS
if "%choice%"=="6" goto SHOW_DIFF
if "%choice%"=="0" goto END
echo [错误] 无效选项，请重新选择
echo.
goto MENU

:: ============================================
:: 同步上游最新代码
:: ============================================
:SYNC_LATEST
echo.
echo [步骤] 检查 upstream remote...
git remote get-url upstream >nul 2>&1 || (
    echo [信息] 添加 upstream remote...
    git remote add upstream https://github.com/farion1231/cc-switch.git
)

echo [步骤] 获取上游更新...
git fetch upstream --tags

echo [步骤] 切换到 main 分支...
git checkout main

echo [步骤] 合并上游 main 分支...
git merge upstream/main -m "chore: sync with upstream main"

if %errorlevel% neq 0 (
    echo.
    echo [警告] 合并过程中可能有冲突，请手动解决后执行:
    echo        git add .
    echo        git commit -m "chore: resolve merge conflicts"
    pause
    goto MENU
)

echo.
echo [成功] 同步完成！
echo.
pause
goto MENU

:: ============================================
:: 同步上游指定 Tag
:: ============================================
:SYNC_TAG
echo.
echo [步骤] 检查 upstream remote...
git remote get-url upstream >nul 2>&1 || (
    echo [信息] 添加 upstream remote...
    git remote add upstream https://github.com/farion1231/cc-switch.git
)

echo [步骤] 获取上游更新...
git fetch upstream --tags

echo.
echo 可用的上游 Tags (最近 10 个):
git tag --sort=-version:refname | head -10
echo.

set /p tag_name="请输入要同步的 Tag 名称 (如 v3.10.0): "

if "%tag_name%"=="" (
    echo [错误] Tag 名称不能为空
    pause
    goto MENU
)

echo [步骤] 切换到 main 分支...
git checkout main

echo [步骤] 合并 Tag %tag_name%...
git merge %tag_name% -m "chore: sync with upstream %tag_name%"

if %errorlevel% neq 0 (
    echo.
    echo [警告] 合并过程中可能有冲突，请手动解决
    pause
    goto MENU
)

echo.
echo [成功] 已同步到 %tag_name%！
echo.
pause
goto MENU

:: ============================================
:: 构建项目
:: ============================================
:BUILD
echo.
echo [步骤] 安装依赖...
call pnpm install

echo [步骤] 开始构建...
call pnpm build

if %errorlevel% neq 0 (
    echo [错误] 构建失败
    pause
    goto MENU
)

echo.
echo [成功] 构建完成！
echo [信息] 输出文件位于: src-tauri\target\release\bundle\
echo.

:: 显示生成的文件
echo 生成的安装包:
dir /b "src-tauri\target\release\bundle\msi\*.msi" 2>nul
dir /b "src-tauri\target\release\bundle\nsis\*.exe" 2>nul

echo.
pause
goto MENU

:: ============================================
:: 构建并发布
:: ============================================
:BUILD_AND_RELEASE
echo.

:: 检查 gh 是否可用
where gh >nul 2>&1 || (
    echo [错误] 发布功能需要 GitHub CLI (gh)
    echo        安装方法: winget install GitHub.cli
    echo        安装后执行: gh auth login
    pause
    goto MENU
)

:: 检查 gh 登录状态
gh auth status >nul 2>&1 || (
    echo [错误] 请先登录 GitHub CLI
    echo        执行: gh auth login
    pause
    goto MENU
)

:: 获取版本号
for /f "tokens=2 delims=:, " %%a in ('findstr /c:"\"version\"" package.json') do (
    set "VERSION=%%~a"
    goto :GOT_VERSION
)
:GOT_VERSION
set "VERSION=%VERSION:"=%"
echo [信息] 当前版本: v%VERSION%

set /p release_tag="请输入发布 Tag (默认 v%VERSION%): "
if "%release_tag%"=="" set "release_tag=v%VERSION%"

set /p release_title="请输入发布标题 (默认 %release_tag%): "
if "%release_title%"=="" set "release_title=%release_tag%"

echo.
echo [步骤] 安装依赖...
call pnpm install

echo [步骤] 开始构建...
call pnpm build

if %errorlevel% neq 0 (
    echo [错误] 构建失败
    pause
    goto MENU
)

echo.
echo [步骤] 准备发布文件...

:: 查找生成的安装包
set "MSI_FILE="
set "NSIS_FILE="

for %%f in ("src-tauri\target\release\bundle\msi\*.msi") do set "MSI_FILE=%%f"
for %%f in ("src-tauri\target\release\bundle\nsis\*.exe") do set "NSIS_FILE=%%f"

echo [信息] 找到的安装包:
if defined MSI_FILE echo   - MSI: %MSI_FILE%
if defined NSIS_FILE echo   - NSIS: %NSIS_FILE%

:: 创建 Tag
echo.
echo [步骤] 创建 Git Tag...
git tag -a %release_tag% -m "Release %release_tag%" 2>nul || (
    echo [警告] Tag %release_tag% 已存在，跳过创建
)

echo [步骤] 推送 Tag 到远程...
git push origin %release_tag%

:: 创建 Release
echo [步骤] 创建 GitHub Release...

set "RELEASE_FILES="
if defined MSI_FILE set "RELEASE_FILES=%RELEASE_FILES% "%MSI_FILE%""
if defined NSIS_FILE set "RELEASE_FILES=%RELEASE_FILES% "%NSIS_FILE%""

gh release create %release_tag% %RELEASE_FILES% ^
    --title "%release_title%" ^
    --notes "## What's Changed`n`n- Synced with upstream`n- See full changelog in commits" ^
    --latest

if %errorlevel% neq 0 (
    echo [错误] 创建 Release 失败
    pause
    goto MENU
)

echo.
echo [成功] 发布完成！
echo [信息] 查看发布: https://github.com/CrazyFigure/cc-switch-plus/releases/tag/%release_tag%
echo.
pause
goto MENU

:: ============================================
:: 查看上游 Tags
:: ============================================
:LIST_TAGS
echo.
echo [步骤] 检查 upstream remote...
git remote get-url upstream >nul 2>&1 || (
    echo [信息] 添加 upstream remote...
    git remote add upstream https://github.com/farion1231/cc-switch.git
)

echo [步骤] 获取上游 Tags...
git fetch upstream --tags

echo.
echo 上游所有 Tags (按版本排序):
echo ----------------------------------------
git tag --sort=-version:refname
echo ----------------------------------------
echo.
pause
goto MENU

:: ============================================
:: 查看差异
:: ============================================
:SHOW_DIFF
echo.
echo [步骤] 检查 upstream remote...
git remote get-url upstream >nul 2>&1 || (
    echo [信息] 添加 upstream remote...
    git remote add upstream https://github.com/farion1231/cc-switch.git
)

echo [步骤] 获取上游更新...
git fetch upstream --tags

echo.
echo === 本地比上游多的提交 ===
git log upstream/main..HEAD --oneline 2>nul || echo (无)

echo.
echo === 上游比本地多的提交 ===
git log HEAD..upstream/main --oneline 2>nul || echo (无)

echo.
pause
goto MENU

:: ============================================
:: 退出
:: ============================================
:END
echo.
echo 再见！
endlocal
exit /b 0
