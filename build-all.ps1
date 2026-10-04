# ============================================================================
#  NomadDriveMod 一键构建
#
#  构建两个产物：
#    src/GamePatcher   -> bin/patcher/    (dnlib 补丁器，命令行 exe)
#    src/NomadDriveMod -> bin/mod/        (MOD 程序集)
#
#  需要 .NET SDK：
#    - GamePatcher 需 .NET 8 SDK
#    - MOD 需 .NET SDK（目标 net472，只需引用编译，不需要 .NET Framework 开发包）
#
#  用法：  ./build-all.ps1
#          ./build-all.ps1 -GameDir "D:\STEAM\steamapps\common\Nomad Drive Demo"
# ============================================================================
param(
  [string]$GameDir = ''
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$root = $PSScriptRoot
if (-not $GameDir) {
  $GameDir = 'D:\STEAM\steamapps\common\Nomad Drive Demo'
}

# 优先用仓库自带的 SDK（如果有），否则用 PATH 里的
$dotnet = Join-Path $root 'tools\dotnet-sdk\dotnet.exe'
if (-not (Test-Path $dotnet)) { $dotnet = 'dotnet' }

$modProj     = Join-Path $root 'src\NomadDriveMod\NomadDriveMod.csproj'
$patcherProj = Join-Path $root 'src\GamePatcher\GamePatcher.csproj'
$modOut      = Join-Path $root 'bin\mod'
$patcherOut  = Join-Path $root 'bin\patcher'

Write-Host "SDK   : $dotnet"
Write-Host "游戏  : $GameDir"
Write-Host ""

foreach ($p in @($modProj, $patcherProj)) {
  if (-not (Test-Path $p)) { throw "找不到项目: $p" }
}

Write-Host "[1/2] 构建 GamePatcher ..."
& $dotnet build $patcherProj -c Release -o $patcherOut -p:GameDir="$GameDir" --nologo
if ($LASTEXITCODE -ne 0) { throw "GamePatcher 构建失败" }

Write-Host ""
Write-Host "[2/2] 构建 NomadDriveMod ..."
& $dotnet build $modProj -c Release -o $modOut -p:GameDir="$GameDir" --nologo
if ($LASTEXITCODE -ne 0) { throw "NomadDriveMod 构建失败" }

Write-Host ""
Write-Host "构建完成："
Write-Host "  补丁器  $patcherOut\GamePatcher.exe"
Write-Host "  MOD     $modOut\NomadDriveMod.dll"
Write-Host ""
Write-Host "安装到游戏：  ./scripts/install.ps1 -GameDir '$GameDir'"
