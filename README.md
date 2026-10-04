# NomadDriveMod

**《Nomad Drive Demo》的 C# IL 改写型 MOD** — 不使用 BepInEx、不做运行时 Hook。

作者：**BY-13oz** ｜ 游戏：[Nomad Drive Demo](https://store.steampowered.com/app/2223980/)（Steam AppID 2223980）

---

## 这是什么

一个不依赖任何注入器框架的 MOD。它在**游戏启动之前**用 [dnlib](https://github.com/0xd4d/dnlib) 直接改写
`Assembly-CSharp.dll` 的 IL：把一个引导入口和若干功能开关**注入到游戏程序集本身**。
MOD 程序集在运行时只做两件事——读写这些静态字段、画 IMGUI 面板。

因此没有 `winhttp.dll` 劫持、没有 MonoMod / HarmonyX、没有每帧 detour 的性能开销。

### 为什么不用 BepInEx

本作是 Unity **Mono** 构建，其 `mscorlib` 装不起 HarmonyX / MonoMod 的运行时补丁栈
（实测 BepInEx preloader 会直接崩溃）。所以改走"预编译期改写 IL"这条路。

---

## 架构

```
┌──────────────────────────────────────────────────────────────┐
│ 1. 安装阶段（一次性，游戏关闭时）                              │
│                                                              │
│   GamePatcher.exe  ──dnlib──▶  Assembly-CSharp.dll            │
│     • 备份原文件为 Assembly-CSharp.dll.orig                    │
│     • 注入 NomadDriveBootstrap.Bootstrap（引导入口）            │
│     • 注入 FeatureFlags 静态字段（MOD 与游戏的唯一契约）        │
│     • 改写若干方法体重定向到这些字段（带开关保护）              │
│                                                              │
│   同时把 NomadDriveMod.dll 放进 _Data\Managed                 │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼  启动游戏
┌──────────────────────────────────────────────────────────────┐
│ 2. 运行阶段（零 Hook）                                        │
│                                                              │
│   游戏 BasicTimeManager.OnStartClient                        │
│     └─▶ NomadDriveBootstrap.Bootstrap()                      │
│           └─▶ 反射加载 NomadDriveMod.dll                     │
│                 ├─ 绑定 FeatureFlags 静态字段                 │
│                 ├─ 每帧读键盘 → 直接写那些字段                │
│                 └─ OnGUI 画面板 / ESP                        │
└──────────────────────────────────────────────────────────────┘
```

**关键点**：MOD 与游戏之间**唯一的接口是共享的静态字段名**。补丁只在字段读写点上生效，
所以功能失效时是"开关没反应"，而不是崩溃。

---

## 目录结构

```
NomadDriveMod/
├── src/
│   ├── NomadDriveMod/        MOD 本体（C# / net472）
│   │   ├── Mod.cs                 入口、Bootstrap、日志
│   │   ├── FeatureFlags.cs        与游戏共享的静态开关（契约层）
│   │   ├── ModConfig.cs           mod.ini 读写
│   │   ├── ModUI.cs               IMGUI 面板
│   │   ├── FunActions.cs          核心功能集
│   │   ├── VehicleTuning.cs       车辆操控 / 抓地
│   │   ├── PlayerTweaks.cs        第三人称 / 旋转 / 鸡形态
│   │   ├── BuildingSpawner.cs     凭空造建筑
│   │   ├── NetworkLimits.cs       房间人数上限
│   │   ├── ItemEsp.cs             物品绘制
│   │   ├── ItemNamesZh.cs         缺失的中文物品名
│   │   ├── Brightness.cs          亮度 / 跳跃
│   │   └── Actions.cs             玩家状态
│   ├── GamePatcher/           IL 补丁器（C# / net8.0，命令行）
│   └── dninspect/             dnlib 检查工具（开发用：type / il / xref / find / strings）
├── scripts/
│   ├── install.ps1            安装：备份 → 部署 → 打补丁
│   └── ab-test.ps1            A/B 回归对比（原版 vs 打过补丁，查异常数）
├── docs/
│   ├── 功能说明.md             完整功能与快捷键
│   ├── 安装指南.md             详细安装 / 卸载 / 排错
│   └── DEVELOPMENT.md          技术细节与逆向笔记
├── dist/                      发行包（不含 GamePatcher.exe，它走 Release）
├── build-all.ps1              一键构建
└── DISCLAIMER.md
```

---

## 安装

### 方式一：用发行包（推荐普通用户）

1. 到 [Releases](../../releases) 下载最新 `NomadDriveMod-vX.Y.Z.zip`
2. **完整解压**到一个文件夹（不要在压缩包里直接运行）
3. **关闭游戏**
4. 双击 `INSTALL.bat`

### 方式二：从源码构建

需要 .NET SDK（GamePatcher 需要 .NET 8）。

```powershell
# 构建（-GameDir 指向游戏根目录，含 Nomad Drive Demo.exe）
./build-all.ps1 -GameDir "D:\Steam\steamapps\common\Nomad Drive Demo"

# 安装
./scripts/install.ps1 -GameDir "D:\Steam\steamapps\common\Nomad Drive Demo"
```

产物：`bin/patcher/GamePatcher.exe`、`bin/mod/NomadDriveMod.dll`。

> **游戏必须先关闭** —— 它会把 `Assembly-CSharp.dll` 映射到内存，占用时无法写入。

### 卸载

```powershell
./scripts/uninstall.ps1 -GameDir "<游戏目录>"
```

或直接在 Steam 里「验证游戏文件完整性」，效果一样。

---

## 怎么用

**进入或创建一个存档后**，左上角会出现面板。按 **`Delete`** 显示 / 隐藏。

> ⚠️ 在游戏主菜单看不到面板，必须进存档。面板约在启动后 105~120 秒才出现
> （取决于游戏自己 `OnStartClient` 的时机）。

| 按键 | 作用 |
|---|---|
| `Delete` | 显示 / 隐藏面板 |
| `↑` `↓` | 选择（**可长按连续滚动**） |
| `←` `→` | 调数值 / 切换目标 |
| `Enter` | 切换开关 / 进入子菜单 / 执行（**在刷物品页可长按连刷**） |
| `Esc` | 返回上一级 |
| 鼠标 | 也可以直接点 |

### 面板页面

| 页面 | 内容 |
|---|---|
| 主页面 | 生存系列开关、移动与视野、各子菜单入口 |
| **物品绘制** | 屏幕上给物品画框 + 中文名 + 距离，按类别开关，可调最大距离 |
| **刷出物品** | 按用途分类的物品清单，可滚动、可长按连刷 |
| **车辆调校** | 操控性增强、全地形抓地 |
| **玩家 / 形态** | 第三人称、快速旋转、鸡形态 |
| **凭空造建筑** | 扫描场景建筑 → 按类型分组的子菜单 → 造在准星前方 |
| **多人设置** | 房间人数上限 |
| **趣味功能** | 删除 / 补给 / 车辆 / 修复 / 对抗 / 减益 |

### 快捷键

F1~F24 已绑定全部主要功能，详见 [docs/功能说明.md](docs/功能说明.md)。

> ⚠️ **F13~F24 在多数键盘上不存在**。这些功能请用面板 `Enter` 执行。
> 所有键位都可以在 `mod.ini` 里改。

---

## 功能概览

### 单机

- **生存**：无限生存、无敌、回血解毒、无限燃油、引擎不过热、摔落无伤
- **移动**：奔跑加速、跳跃增强、拾取大件不减速、无视黑暗
- **车辆**：操控性增强、全地形抓地（沙地不打滑）、一键修车、一键安装、车辆加速
- **视角**：第三人称、快速旋转、鸡形态（仍可正常驾驶）
- **世界**：删除准星建筑（带轮廓高亮）、凭空造建筑、刷出物品
- **修复**：一键抛光 / 喷漆 / 除锈（需手持对应工具）、快速转移液体
- **物品绘制**：按类别 ESP，含玩家标记

### 联机（会影响其他玩家，请仅在自建主机使用）

| 功能 | 谁能用 |
|---|---|
| 大部分开关 | 都能用（改的是自己） |
| 掠夺、变鸡 | **仅主机** |
| 夺取物品、拆轮胎 / 方向盘、一键安装、一键修车 | 客机也能用 |
| 召唤空车 | 能发出，主机侧更稳定 |
| 房间人数上限 | **仅主机**（游戏原本是 4） |

**请勿用于陌生玩家的公开房间。** 拆轮子、搬车、变鸡这些对别人体验破坏很大。

---

## 技术说明

想了解"为什么这些功能能生效"（服务端校验点、Mirror `requiresAuthority` 的实测结果、
逆向方法论），见 **[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)**。

几个值得一提的实现前提：

- 本作 **Mono** 构建 + **Mirror** 网络 + **HDRP** 渲染 + **NWH VehiclePhysics2** 车辆物理
- 游戏有 **FloatingOrigin**（浮动原点），传坐标必须补偿 `CurrentOriginShift()`
- Unity `Key` 枚举只到 **F24**，没有 F25
- `.cs` 必须存为 **UTF-8 带 BOM**（或纯 ASCII）—— 无 BOM 的 UTF-8 会让 Roslyn 按 ANSI 读，中文变乱码

---

## 已知限制

- **游戏更新后补丁会被覆盖**，重跑一次安装即可。若提示"有 N 个补丁点没找到"，说明代码结构变了，需适配
- 面板只在**进入存档后**出现
- 联机时若你不是主机，很多改动会被服务端覆盖回去
- 建造功能是**克隆场景里已加载的建筑**（客户端本地物件），不是游戏原生的放置系统

---

## 免责声明

见 [DISCLAIMER.md](DISCLAIMER.md)。**仅供学习交流与单机娱乐使用。**

## 许可

[MIT](LICENSE)
