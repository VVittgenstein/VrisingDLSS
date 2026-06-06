# RenderGraph Pass Data Gameplay Result - 2026-06-06

## Question

Can the default-off `rendergraph-pass-data` probe read focused HDRP
`UberPostPassData`, `EASUData`, and `FinalPassData` in the protected local
`11111` gameplay fixture at true `1920x1080` Windowed, while keeping the route
read-only and avoiding `GetTexture`/native pointer/evaluate work?

## Runtime Setup

- Artifact label: `rendergraph-pass-data-gameplay-1080p-20260606-r1`.
- Game path: `C:\Software\VRising`.
- Stage: `rendergraph-pass-data`.
- Window mode: V Rising `ClientSettings.GraphicSettings.WindowMode=3`
  temporarily, plus `-windowed`.
- Resolution: `1920x1080`.
- Native DLL: release-safe local native from `artifacts\native-build\Release`.
- DLSS: `EnableDLSS=false`; all evaluate probes disabled.
- Broad RenderGraph `GetTexture` probe: disabled.
- Save fixture:
  `C:\Users\Administrator\AppData\LocalLow\Stunlock Studios\VRising\CloudSaves\76561198564171843\v4\f0e07524-03f4-4ef4-945c-b1f7e982071b`.

## Protocol

- Backed up the protected save before launch.
- Started V Rising with `scripts\start-vrising-automation-session.ps1`.
- Computer Use selected the real `VRising` Unity window, not the BepInEx console.
- Computer Use clicked the main-menu `Continue` entry once.
- No movement keys or gameplay action keys were sent.
- Gameplay was observed with HUD, character, quest text, and minimap visible.
- Captured a gameplay screenshot.
- Stopped the session with `scripts\stop-vrising-automation-session.ps1`.
- Archived the run-mutated save, restored the pre-run backup, and compared the
  restored save.

## Evidence

- Session:
  `artifacts/gameplay-automation/Session-rendergraph-pass-data-gameplay-1080p-20260606-r1.json`.
- Computer Use record:
  `artifacts/gameplay-automation/ComputerUseGameplay-rendergraph-pass-data-gameplay-1080p-20260606-r1.json`.
- Gameplay screenshot:
  `artifacts/gameplay-automation/GameplayScreenshot-rendergraph-pass-data-gameplay-1080p-20260606-r1.png`.
- BepInEx log:
  `artifacts/gameplay-automation/LogOutput-rendergraph-pass-data-gameplay-1080p-20260606-r1.log`.
- Analyzer:
  `artifacts/gameplay-automation/Analysis-rendergraph-pass-data-gameplay-1080p-20260606-r1.txt`.
- Chain summary:
  `artifacts/gameplay-automation/PassDataChainSummary-rendergraph-pass-data-gameplay-1080p-20260606-r1.json`.
- Cleanup:
  `artifacts/gameplay-automation/Cleanup-rendergraph-pass-data-gameplay-1080p-20260606-r1.json`.
- Save restore:
  `artifacts/gameplay-automation/SaveCompareAfterRestore-rendergraph-pass-data-gameplay-1080p-20260606-r1.json`.

## Result

Pass.

- Gameplay entry succeeded through the known local/private `11111` Continue
  route.
- Player log reported `SetResolution 1920, 1080, fullScreenMode Windowed`.
- Cleanup reported `Status=Pass`, `CrashEventCount=0`,
  `RemainingVRisingProcessCount=0`, `RestoredClientSettings=true`,
  `RestoredLoaderConfig=true`, and `RestoredReleaseSafeNative=true`.
- Save restore reported `BeforeChangeCount=3`, `CompareStatus=Restored`, and
  `ChangeCount=0`.
- Analyzer reported `RenderGraph Pass Data=Pass`.
- Log counts:
  - `RenderGraph pass-data snapshot #`: `321`.
  - `memberCount=`: `321`.
  - `data=not found`: `0`.
  - typed-read failures: `0`.
  - broad `RenderGraph GetTexture call #`: `0`.
  - `UberPostPassData`: `162`.
  - `EASUData`: `75`.
  - `FinalPassData`: `84`.
- Chain summary found `73` complete `Uber Post -> Edge Adaptive Spatial
  Upsampling -> Final Pass` chains.
- `73/73` chains matched `Uber.destination == EASU.source`.
- `73/73` chains matched `EASU.destination == Final.source`.
- Dominant chain: `Uber 78 -> EASU 78 -> 79 -> Final 79`, `72` occurrences.
- All complete chains reported `UberSize=1920x1080`,
  `EASU input=1920x1080 output=1920x1080`,
  `performUpsampling=True`, `dynamicResIsOn=True`, and
  `dynamicResFilter=EdgeAdaptiveScalingUpres`.

## Decision

Accept `rendergraph-pass-data` as a proven read-only gameplay observation
boundary for focused HDRP pass data in this local V Rising build. Do not rerun
menu or protected gameplay pass-data unchanged.

This does not prove a safe evaluate boundary. It proves only that the safe
`CompileRenderGraph(int)` observation point can map the official HDRP
postprocess/upscale/final pass data chain in real gameplay without resolving
textures or evaluating DLSS.

## Next

Use this pass-data chain to design the next minimal read-only/no-evaluate
execution-boundary candidate. Do not jump directly to generated EASU/Final render
function patching or DLSS evaluate without a smaller safety proof.
