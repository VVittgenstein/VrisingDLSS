# V Rising DLSS Mod 可分发性与技术路线调查

日期：2026-06-04

目标：为“可分发的 V Rising 真 DLSS Mod/插件”建立第一版决策依据，覆盖合规性、易用性、技术路线，以及 PureDark 公开 Mod 可借鉴性。

> 注意：本文是工程与发布风险分析，不是正式法律意见。

## 结论摘要

1. 官方路线不存在：Stunlock/Steam/NVIDIA 公开资料没有显示 V Rising 原生 DLSS 支持；Steam 页面显示游戏为 DirectX 11，且需要同意第三方 EULA。
2. 最接近历史可行方案的是 PureDark 的 VRisingPerfMod，但它是 2022-11-23 的公开版本，依赖旧 BepInExPack 1.0.0，并打包了 `PDPerfPlugin.dll`、`nvngx_dlss.dll` 等二进制；不能把它当作可直接维护和再发布的基底。
3. 可分发实现应走 clean-room：自己写 BepInEx IL2CPP C# 插件和自己的 native D3D11/DLSS bridge。PureDark 只能作为公开技术事实参考，不能复制代码、ABI、二进制或 Patreon/Discord 私有材料。
4. GitHub 发布应只包含自有源码、构建脚本、文档和可审计依赖声明。Thunderstore 包应至少声明 `BepInEx-BepInExPack_V_Rising-1.733.2` 依赖；是否打包 NVIDIA `nvngx_dlss.dll` 必须单独做许可证审查。
5. 用户易用性建议分两档：`source-only/legal-safe` 版不带 NVIDIA/PureDark 二进制；`convenience` 版只有在确认 NVIDIA/SDK/Thunderstore 分发条件后才考虑带生产版 DLSS runtime 和第三方 notices。

## 已搜索和核验的来源

### 官方与准官方

- Steam 商店页：`https://store.steampowered.com/app/1604030/V_Rising/`
  - 显示 V Rising 需要第三方 EULA。
  - 系统需求列 DirectX 11。
- V Rising EULA：`https://store.steampowered.com/eula/1604030_eula_1`
  - 限制 mods/hacks/cheats/bots、第三方 add-ons、干扰在线或网络游玩。
  - 限制复制、分发、修改、反编译、制作衍生作品。
- V Rising Terms of Service PDF：`https://cdn.stunlock.com/legal/Terms_of_Service_VRising.pdf`
  - 禁止未经许可使用 mods 或未授权第三方软件修改服务、游戏或体验。
- Stunlock Dev Update #32：`https://blog.stunlock.com/dev-update-32-the-next-era/`
  - Stunlock 表示 V Rising 不会做 1.2 内容更新，只会按需做平衡/bug 修复。
  - 官方探索过 modding support，但认为游戏结构无法达到他们希望提供给社区的官方工具标准。
- Unity 对 V Rising 的技术文章：`https://unity.com/resources/stunlock-studios-v-rising/`
  - V Rising 使用 DOTS 和 HDRP。
  - Stunlock 使用/定制 HDRP、custom visual effects、custom post-processing passes。
- NVIDIA DLSS SDK：`https://github.com/NVIDIA/DLSS`
  - 公开仓库最新 release 页面显示 DLSS 310.6.0 SDK，2026-04-21。
- NVIDIA DLSS/RTX SDK License：`https://github.com/NVIDIA/DLSS/blob/main/LICENSE.txt`
  - 允许安装使用 SDK、修改 sample source、将 SDK 材料以对象码整合进有实质功能的软件应用中分发。
  - 要求应用具有 SDK 之外的实质功能。
  - 禁止将 SDK 作为独立产品分发，禁止暗示 NVIDIA 背书，禁止反编译/绕过限制，禁止让 SDK 受开源许可证约束。
- NVIDIA Streamline SDK/Programming Guide：
  - `https://github.com/NVIDIA-RTX/Streamline`
  - `https://github.com/NVIDIA-RTX/Streamline/blob/main/docs/ProgrammingGuide.md`
  - Streamline 分发应用时需要 `sl.interposer.dll`、`sl.common.dll`；使用 DLSS/NIS 时还需要 `sl.dlss.dll`、`nvngx_dlss.dll`、`sl.nis.dll` 等。
  - NVIDIA 建议 release 使用 production build 和签名 DLL。
- NVIDIA Streamline/DLSS integration checklist：
  - `https://developer.nvidia.com/rtx/streamline/get-started`
  - DLSS SR 需要在 post-processing 早期集成，准确 motion vectors、jitter、exposure、mip-map bias、camera reset、NGX cleanup。

### V Rising Mod 生态

- BepInExPack V Rising：`https://new.thunderstore.io/c/v-rising/p/BepInEx/BepInExPack_V_Rising/`
  - 当前 dependency string：`BepInEx-BepInExPack_V_Rising-1.733.2`。
  - 基于 BepInEx 6.0.0-be.733 和 Il2CppInterop PR #70。
  - 1.668.5 之后有 breaking changes：Il2CppAssemblyUnhollower 被 Il2CppInterop 替代，Mono runtime 被 CoreCLR 替代，插件可编译到 .NET 6。
- BepInEx IL2CPP docs：
  - `https://docs.bepinex.dev/v6.0.0-pre.1/api/BepInEx.IL2CPP.BasePlugin.html`
  - `https://docs.bepinex.dev/master/articles/dev_guide/plugin_tutorial/2_plugin_start.html?tabs=tabid-unityil2cpp`
  - `https://docs.bepinex.dev/master/articles/user_guide/installation/unity_il2cpp.html?tabs=tabid-win`
- Il2CppInterop class injection：
  - `https://github.com/BepInEx/Il2CppInterop/blob/master/Documentation/Class-Injection.md`
- V Rising Mod Wiki：
  - Manual install：`https://wiki.vrisingmods.com/user/Mod_Install.html`
  - How mods work：`https://wiki.vrisingmods.com/dev/how-mods-work.html`
  - Licensing：`https://wiki.vrisingmods.com/dev/licensing.html`
  - Uploading to Thunderstore：`https://wiki.vrisingmods.com/dev/upload_to_thunderstore.html`
- Thunderstore package format：
  - `https://new.thunderstore.io/package/create/docs/`
  - 必需文件：`manifest.json`、`README.md`、`icon.png`，可选 `CHANGELOG.md`。

## PureDark 本地参考材料

已拉取到本地：

- `ref/PureDark-VRisingPerfMod/`
  - 来源：`https://github.com/PureDark/VRisingPerfMod`
  - shallow clone，仅用于静态研究。
- `ref/packages/PureDark-VRisingPerfMod-1.1.0.zip`
  - 来源：`https://thunderstore.io/package/download/PureDark/VRisingPerfMod/1.1.0/`
  - 完整大小：23,003,762 bytes。
- `ref/packages/PureDark-VRisingPerfMod-1.1.0/`
  - 已解压，仅用于静态文件清单和元数据观察。

### PureDark 包内容

Thunderstore 1.1.0 包含：

| 文件 | 大小 | 静态判断 |
|---|---:|---|
| `PureDark.PerfMod/PerfMod.dll` | 36,352 | C# BepInEx 插件，未签名 |
| `PureDark.PerfMod/PDPerfPlugin.dll` | 127,488 | PureDark native bridge，未签名，不可再分发/不可复用 |
| `PureDark.PerfMod/nvngx_dlss.dll` | 14,171,176 | NVIDIA DLSS runtime，版本 2.4.12.0，签名有效 |
| `PureDark.PerfMod/libxess.dll` | 9,272,488 | Intel XeSS SDK，签名有效 |
| `PureDark.PerfMod/XeFX.dll` / `XeFX_Loader.dll` | 67,240 / 41,640 | Intel XeFX，签名有效 |
| `PureDark.PerfMod/ffx_fsr2_api_x64.dll` | 32,256 | FSR2 API loader，未签名 |
| `PureDark.PerfMod/ffx_fsr2_api_dx12_x64.dll` | 2,296,320 | FSR2 DX12 backend，未签名 |
| `PureDark.PerfMod/dxcompiler.dll` / `dxil.dll` | 20,067,744 / 1,526,184 | Microsoft DirectX compiler components，签名有效 |

Manifest：

```json
{
  "name": "VRisingPerfMod",
  "version_number": "1.1.0",
  "website_url": "https://github.com/PureDark/VRisingPerfMod",
  "description": "First-ever DLSS/FSR2/XeSS mod, huge performance boost. MUST DISABLE TAA!",
  "dependencies": [
    "BepInEx-BepInExPack_V_Rising-1.0.0"
  ]
}
```

这说明它依赖旧 BepInExPack 1.0.0，而当前 V Rising Mod 生态公开页显示的是 1.733.2。

### PureDark 源码结构观察

入口：

- `PerfMod/PerformancePlugin.cs`
  - BepInEx plugin id：`PureDark.VRising.PerfMod`
  - 版本：`1.1.0`
  - `BasePlugin.Load()` 中执行：
    - IL2CPP class injection
    - Harmony patch
    - config 初始化
    - scene loaded 后创建 `DLSSGlobals`
    - `LoadLibrary()` 预加载 `nvngx_dlss.dll`、FSR2、XeSS、`PDPerfPlugin.dll`

项目文件：

- `PerfMod/PerfMod.csproj`
  - `TargetFramework=net6.0`
  - `PlatformTarget=x64`
  - BepInEx 包版本：`6.0.0-be.668`
  - `VRising.Unhollowed.Client`：`0.6.5.*`
  - 有 PureDark 本地机器专用 post-build copy 路径。

渲染注入：

- `PerfMod/Patches/UpscalePatches.cs`
  - Patch `CustomVignette.IsActive()`：让 upscaler 开启时确保该 custom post-process 处于 active。
  - Patch `CustomVignette.Render()`：在 postfix 中调用 `UpscaleFlat.Render(cmd, camera, source, destination)`。
  - Patch `DynamicResolutionHandler.DynamicResolutionEnabled`：强制 false。
  - Patch `HDCamera.UpdateAllViewConstants`：upscale 开启时强制 jitter projection，设置自定义 `taaFrameIndex`。
  - Patch `HDCamera.UpdateAntialiasing`：upscale 开启时跳过，避免 TAA 每帧重置 jitter index。
  - Patch `SkyManager.IsLightingSkyValid`：渲染中返回 false 防崩溃。

DLSS 数据路径：

- `PerfMod/Upscale/UpscaleFlat.cs`
  - 设置 `Camera.main.depthTextureMode = DepthTextureMode.Depth | DepthTextureMode.MotionVectors`。
  - 仅支持 `GraphicsDeviceType.Direct3D11`，否则关闭 upscaler。
  - 通过 `Texture2D.GetNativeTexturePtr()` 给 native bridge 获取 D3D11 device。
  - 使用 HDRP color buffer format 推断 DXGI format。
  - 通过 `Shader.GetGlobalTexture("_CameraDepthTexture")` 和 `Shader.GetGlobalTexture("_CameraMotionVectorsTexture")` 获取深度/运动矢量。
  - 将 color、motion vector、depth、destination、render size、sharpness、jitter、motion scale、near/far/FOV、reset 等传给 `PDPerfPlugin`。
  - 通过 `CommandBuffer.IssuePluginEvent(GetEvaluateFunc(), id)` 在渲染线程执行 native evaluate。
  - 刷新 mip-map bias。

### PureDark 可借鉴与不可借用

可借鉴的公开技术事实：

- V Rising/HDRP 可通过 custom post-processing 相关路径接入 upscaler。
- DLSS/FSR2/XeSS 需要颜色、深度、运动矢量、jitter、render scale、camera reset、mip bias。
- Unity IL2CPP 下可用 BepInEx + Harmony + Il2CppInterop 注入 MonoBehaviour。
- Unity native texture pointer + `CommandBuffer.IssuePluginEvent` 是可行的 Unity/native bridge 模式。
- 用户体验上需要配置文件、热键、模式切换、profile、sharpness、状态 overlay 和日志。

不可直接借用：

- PureDark C# 源码。该 GitHub 仓库没有发现明确开源许可证；GitHub 官方说明无 license 时默认版权法适用，通常不能复制、分发或创作衍生作品。
- `PDPerfPlugin.dll`、`PerfMod.dll`、Thunderstore 包内所有第三方 DLL。
- Patreon/Discord 私有包、会员文件、鉴权逻辑或任何非公开材料。
- PureDark native ABI 和函数名不应原样继承为兼容目标，避免形成“二进制替代/衍生”的风险。

需要重新验证的技术点：

- 当前 V Rising 是否仍有同名/同签名的 `CustomVignette`、`HDCamera.UpdateAllViewConstants`、`HDCamera.UpdateAntialiasing`、`SkyManager.IsLightingSkyValid`。
- 当前 HDRP 版本中 `_CameraDepthTexture` 和 `_CameraMotionVectorsTexture` 是否在目标注入点有效且帧对齐。
- 当前 BepInExPack 1.733.2 对 `VRising.Unhollowed.Client` 或替代 interop assembly 的推荐用法。
- V Rising 当前渲染是否仍以 D3D11 为主，是否存在 Vulkan/DX12/Proton 情况。

## 合规性路线

### 发布物分层

建议把发布物拆为三层：

1. GitHub 源码仓库
   - 只放自有 C# 插件、自有 C++ native bridge、构建脚本、README、third-party notices。
   - 不放 PureDark 源码/二进制。
   - 不放游戏 DLL、反编译游戏代码、修改后的游戏文件。
   - NVIDIA SDK headers/libs 是否放入仓库需要单独确认；更稳妥是要求构建者从 NVIDIA 官方 SDK 获取。

2. Thunderstore 包
   - 最低风险版只放：
     - 我们自己的 `VrisingDLSS.dll`
     - 我们自己的 `VrisingDLSS.Native.dll`
     - `README.md`
     - `CHANGELOG.md`
     - `manifest.json`
     - `icon.png`
     - `ThirdPartyNotices.md`
   - 依赖：
     - `BepInEx-BepInExPack_V_Rising-1.733.2`
   - 不默认打包 PureDark/NVIDIA/游戏二进制。

3. 可选便利安装器或分发包
   - 只有在确认 NVIDIA SDK 对“Mod 作为有实质功能应用/插件”的对象码分发条件适用后，才考虑打包生产版 `nvngx_dlss.dll`。
   - 如果打包，必须：
     - 不把 NVIDIA DLL 置于开源许可证下。
     - 提供 NVIDIA license/notice。
     - 不暗示 NVIDIA 或 Stunlock 背书。
     - 只使用 production/non-watermarked runtime。

### 许可证建议

- 自有 C#/C++ 源码：MIT 或 Apache-2.0 更适合降低用户和社区复用阻力。
- 如果仓库包含任何 NVIDIA SDK 源/头/二进制，需要把这些材料排除在项目开源许可证之外，并加清楚的 third-party license notice。
- 不使用 GPL/AGPL 之类强 copyleft 许可证作为主许可证，避免触发 NVIDIA SDK license 中关于 open source license 约束的冲突风险。

### EULA/线上使用声明

README 应明确：

- 非官方 Mod，与 Stunlock/NVIDIA/PureDark 无隶属、无背书。
- 仅图形渲染用途，不修改网络协议、不提供作弊、不改变玩法数值。
- 不保证官方/公共 PvP 服务器允许使用。
- 建议离线、私人世界、私人服务器测试。
- 使用者自行承担 EULA、服务器规则、崩溃和封禁风险。

## 易用性路线

### 安装目标

优先支持 Thunderstore/R2ModMan/Thunderstore Mod Manager：

```json
{
  "name": "VrisingDLSS",
  "version_number": "0.1.0",
  "website_url": "https://github.com/<owner>/VrisingDLSS",
  "description": "Unofficial client-side DLSS Super Resolution mod for V Rising.",
  "dependencies": [
    "BepInEx-BepInExPack_V_Rising-1.733.2"
  ]
}
```

手动安装：

1. 安装 BepInExPack V Rising。
2. 首次启动游戏，让 BepInEx 生成 `BepInEx/interop` 和配置。
3. 将我们的插件目录放到 `VRising/BepInEx/plugins/VrisingDLSS/`。
4. 如果最低风险版不带 DLSS runtime，则提示用户把生产版 `nvngx_dlss.dll` 放到同一目录或指定目录。
5. 启动后检查 `BepInEx/LogOutput.log`。

### 用户体验要求

最低可用版本应具备：

- 自动检测：
  - BepInExPack 版本。
  - 当前游戏图形 API。
  - 是否 RTX GPU。
  - 是否找到 `nvngx_dlss.dll`。
  - 是否成功加载 native bridge。
  - 是否找到深度/运动矢量纹理。
- 配置：
  - enable/disable
  - DLSS quality mode
  - sharpness
  - overlay on/off
  - log verbosity
  - hotkeys
- 失败时行为：
  - 不崩溃。
  - 自动回退原生渲染。
  - 日志给出明确原因。
- 游戏内提示：
  - 简短 overlay：`DLSS Off/Quality/Balanced/Performance`
  - 可选诊断 overlay：render resolution、display resolution、mvec/depth status、DLL version。

## 技术路线

### 推荐架构

```text
VrisingDLSS/
  src/
    VrisingDLSS.Plugin/       # C# BepInEx IL2CPP plugin
    VrisingDLSS.Native/       # C++ D3D11 + NGX/DLSS bridge
  package/
    thunderstore/
      manifest.json
      README.md
      CHANGELOG.md
      icon.png
      ThirdPartyNotices.md
  docs/
    install.md
    troubleshooting.md
    legal-notes.md
```

C# 插件职责：

- BepInEx `BasePlugin` 入口。
- Harmony patch 当前 V Rising/HDRP 的稳定注入点。
- 注册 IL2CPP MonoBehaviour。
- 管理配置、热键、日志、overlay。
- 获取 Unity/HDRP render resources。
- 调用 native bridge。

C++ native bridge 职责：

- 获取 D3D11 device/context。
- 初始化 NVIDIA NGX/DLSS 或 Streamline。
- Query DLSS support/modes。
- 根据 quality mode 计算 render size。
- 每帧 evaluate。
- 管理资源释放、resize、camera reset。
- 返回 DLL/runtime/version/status 给 C#。

### NGX 直连 vs Streamline

优先建议第一版走 NGX/DLSS SR 直连 D3D11 bridge，而不是 Streamline：

- V Rising Steam 页面和 PureDark 历史实现都指向 DirectX 11。
- Streamline 分发和接入链路更重，需要 interposer/common/plugin DLL 以及更复杂的资源 tagging。
- 只做 DLSS Super Resolution 时，直接 NGX bridge 的文件和调试面更小。

保留 Streamline 作为第二阶段：

- 如果后续需要 Reflex、Frame Generation、DLSS-G 或统一支持 NIS/XeSS/FSR，Streamline 更有价值。
- DLSS Frame Generation 不应作为初版目标，因为它对 UI/HUD-less color、present lifecycle、Reflex/frame index 等要求更高。

### 第一阶段技术验证任务

1. 建立空 BepInEx IL2CPP 插件，确认当前 V Rising + BepInExPack 1.733.2 能加载。
2. 从当前游戏 interop assemblies 中查找：
   - `CustomVignette`
   - `HDCamera`
   - `DynamicResolutionHandler`
   - `SkyManager`
   - `HDRenderPipeline`
3. 先用只读 hook probe 扫描当前已加载程序集，确认目标类型/方法是否存在。
4. 再用 Harmony patch 做只读日志，不改变渲染，验证目标方法是否仍被调用。
5. 在目标注入点读取并记录：
   - source/destination RT size/format
   - `_CameraDepthTexture`
   - `_CameraMotionVectorsTexture`
   - `camera.taaJitter`
   - near/far/FOV
6. 做 native smoke test：
   - C# 调用自有 native bridge。
   - native 获取 D3D11 device。
   - `IssuePluginEvent` 能在 render thread 执行。
7. 再接入 DLSS init/query，不急着 evaluate。
8. 最后加入 render-scale、mip bias、evaluate 和 overlay。

## 下一步建议

### 当前本地进展（2026-06-04）

已完成：

1. `src/VrisingDLSS.Plugin` C# BepInEx IL2CPP 插件 scaffold。
2. `src/VrisingDLSS.Native` 自有 native bridge scaffold。
3. 配置项、hook probe、可选 Harmony call probe、native bridge smoke test、render-thread smoke test、D3D11 texture pointer probe 的代码骨架。
4. `.NET SDK 6.0.428` 下 C# Release 构建通过。
5. `w64devkit 2.8.0` 下 native bridge 构建通过，输出 `artifacts\native-build\Release\VrisingDLSS.Native.dll`。
6. release boundary 检查通过。
7. Thunderstore zip 已生成：`dist\VrisingDLSS-0.1.0-thunderstore.zip`。

尚未完成：

1. `C:\Software\VRising` 尚未安装 BepInExPack，未生成 `BepInEx\interop`。
2. 插件尚未在真实游戏进程中加载验证。
3. HDRP hook probe、Harmony call probe、render-thread event、D3D11 texture/device probe 尚未拿到真实运行日志。
4. DLSS init/query 和 evaluate 尚未实现。

下一步建议：

1. 等 Visual Studio Build Tools 手动安装完成后，补一轮 MSVC native build 验证。
2. 在授权/离线测试环境安装 BepInExPack V Rising 1.733.2，首次启动生成 interop。
3. 拷贝当前 package 到 `BepInEx\plugins\VrisingDLSS\`，先只开 Stage 1 loader validation。
4. 逐步开启 `EnableHookProbe`、`EnableHarmonyCallProbe`、native smoke、render-thread smoke、D3D11 texture probe。
5. 只有上述 runtime 证据都稳定后，再接 NVIDIA DLSS SDK / NGX init/query。

## 时间评估

这里的“能用上”拆成四档，因为 POC 成功不等于稳定可分发。

假设：

- 1 名开发者主导，熟悉 C#、C++、Unity/HDRP、D3D11 基础。
- 有当前 V Rising 客户端、本机 RTX 显卡、可反复启动测试。
- 不复制 PureDark 代码或二进制，走 clean-room。
- 第一版只做 DLSS Super Resolution，不做 Frame Generation。
- 第一版优先 Windows + D3D11 + 本地/私人世界测试。

### 里程碑估计

| 里程碑 | 目标 | 预计时间 | 风险 |
|---|---|---:|---|
| M0：环境与加载 | BepInExPack 1.733.2 下插件能加载，日志/配置可用 | 0.5-2 天 | 低 |
| M1：只读渲染探针 | 找到当前 HDRP 注入点，能读 source/destination、depth、motion vector、jitter | 3-7 天 | 中 |
| M2：native bridge smoke test | 自有 native DLL 能拿到 D3D11 device，`IssuePluginEvent` 在 render thread 正常执行 | 3-7 天 | 中 |
| M3：DLSS 初始化 | 能加载生产版 `nvngx_dlss.dll`，查询支持与 quality modes，完成 init/shutdown | 4-10 天 | 中 |
| M4：第一帧 DLSS 输出 | 能完成一次 evaluate，画面非黑屏/非崩溃，可开关 | 1-2 周 | 中高 |
| M5：可玩 alpha | render scale、mip bias、resize、camera reset、profile、日志、回退可用 | 2-4 周 | 高 |
| M6：私人可用 beta | 30-60 分钟游玩稳定，常见分辨率/画质档测试，README/排错文档齐 | 4-6 周 | 高 |
| M7：公开可分发 release | Thunderstore 包、source release、notices、安装体验、边界声明、基础 QA | 6-10 周 | 高 |

### 最现实判断

- **最快能看到“有 DLSS 画面”的时间：约 2-4 周。**
- **自己能在离线/私人世界比较可靠地用：约 4-6 周。**
- **能放心公开给普通玩家装：约 6-10 周。**

如果当前 V Rising 的 HDRP patch 点已经变化很大，或者 motion vectors/depth 在可用注入点拿不到，时间可能变成 **10-14 周**。如果还要做 Frame Generation、自动安装 NVIDIA runtime、跨 Proton/Steam Deck、或者完整支持 FSR2/XeSS，则更接近 **3 个月以上**。

### 主要拖慢因素

- 当前游戏 interop 类型和 PureDark 2022 patch 点不一致。
- depth/motion vector 与 color buffer 帧不同步，导致 ghosting、闪烁、黑屏。
- native D3D11/DLSS bridge 需要从零实现，而 PureDark 的 `PDPerfPlugin.dll` 不可复用。
- NVIDIA runtime 分发需要法律审查，否则易用性会被“用户自行提供 `nvngx_dlss.dll`”拖低。
- 公共服务器/EULA 风险导致 README、默认配置和支持范围必须保守。
