# DLSS Optimal Settings Runtime Protocol - 2026-06-06

Status: passed in a local V Rising runtime run.

## Question

Can the local SDK-wrapper native bridge query DLSS optimal settings inside the actual
V Rising D3D11 device route, using the local `nvngx_dlss.dll`, without creating a DLSS
feature or evaluating a gameplay frame?

## Hypothesis

The API 12 `dlss-optimal-settings` probe can create a temporary Unity RenderTexture,
obtain a D3D11 device, initialize NGX through the SDK-wrapper native DLL, and query
recommended render dimensions for `3840x2160` output and `DLSS.QualityMode=Performance`.
For a 4K Performance query, the expected render recommendation is approximately
`1920x1080`, with dynamic min/max dimensions also logged.

## Command

Dry run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-vrising-diagnostic.ps1 -GamePath "C:\Software\VRising" -Stage dlss-optimal-settings -UseSdkWrapperNative -DlssRuntimePath "Z:\VrisingDLSS\ref\NVIDIA-DLSS-310.6.0\nvngx_dlss.dll" -DurationSeconds 60 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3 -DryRun
```

Actual run, only after the dry run matches this protocol:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-vrising-diagnostic.ps1 -GamePath "C:\Software\VRising" -Stage dlss-optimal-settings -UseSdkWrapperNative -DlssRuntimePath "Z:\VrisingDLSS\ref\NVIDIA-DLSS-310.6.0\nvngx_dlss.dll" -DurationSeconds 60 -SetClientResolution -SetClientWindowMode -ClientWindowMode 3
```

## Expected Evidence

- `run-vrising-diagnostic.ps1` result reports:
  - `CrashEventCount=0`
  - `RestoredLoaderConfig=true`
  - `RestoredReleaseSafeNative=true`
  - `RestoredClientSettings=true`
  - `GameReportedFullScreenMode=Windowed`
  - `GameReportedWidth=1920`
  - `GameReportedHeight=1080`
- Archived BepInEx log contains:
  - `Running DLSS optimal-settings probe`
  - `DLSS optimal-settings temporary RenderTexture native pointer`
  - `DLSS optimal-settings probe succeeded:`
  - output dimensions, perf-quality mode, optimal render size, dynamic min/max, and
    sharpness.
- Analyzer reports Stage 6B as `Pass`.
- The release-safe native DLL and loader config are restored after the run.
- No `VRising.exe` or `VRisingServer.exe` process remains.

## Actual Result

Run label: `dlss-optimal-settings-20260606-115921`

Artifacts:

- `artifacts/runtime-logs/LogOutput-dlss-optimal-settings-20260606-115921.log`
- `artifacts/runtime-logs/Analysis-dlss-optimal-settings-20260606-115921.txt`
- `artifacts/runtime-logs/Player-dlss-optimal-settings-20260606-115921.log`

Result:

- `CrashEventCount=0`
- `ClosedByScript=True`
- `RestoredLoaderConfig=True`
- `RestoredReleaseSafeNative=True`
- `RestoredClientSettings=True`
- `GameReportedWidth=1920`
- `GameReportedHeight=1080`
- `GameReportedFullScreenMode=Windowed`
- `GameReportedSetResolutionLine=SetResolution 1920, 1080, fullScreenMode Windowed`

BepInEx evidence:

```text
[Info   :VrisingDLSS] Running DLSS optimal-settings probe for output=3840x2160; qualityMode=Performance.
[Info   :VrisingDLSS] DLSS optimal-settings temporary RenderTexture native pointer: 0x285BA07C360
[Info   :VrisingDLSS] DLSS optimal-settings probe succeeded: DLSS optimal-settings probe completed via SDK wrapper ProjectID; appId=0; init=0x00000001; capability=0x00000001; available=1(result=0x00000001); output=3840x2160; perfQuality=0; optimal=0x00000001; render=1920x1080; dynamicMax=3840x2160; dynamicMin=1920x1080; sharpness=0.350; destroy=0x00000001; shutdown=0x00000001
```

Analyzer result:

```text
Stage 6B DLSS Optimal Settings: Pass
```

Note: the player window shape for the run was `1920x1080` Windowed. The
`output=3840x2160` value in the BepInEx evidence is the diagnostic DLSS optimal-settings
query target, not the game window size.

## Pass Signal

Pass if the archived analysis reports `Stage 6B DLSS Optimal Settings: Pass`, the
native status line reports a successful optimal-settings query, and cleanup/restoration
signals are true with no crash events or leftover processes.

## Fail Or Block Signals

- `DLSS optimal-settings probe blocked:` means the wrong native bridge was used or the
  wrapper route is unavailable.
- `DLSS optimal-settings probe failed:` or `skipped:` is a failure for this proof.
- Missing BepInEx log or missing analyzer output is a failure.
- Any Windows crash event, leftover game/server process, or failed config/native/settings
  restoration is a failure.
- A non-Windowed player log is a test-shape failure even if the DLSS query succeeds.

## Cleanup

The diagnostic script must:

- close V Rising after the diagnostic window;
- archive BepInEx log, analyzer output, Player log, and WER events;
- restore the release-safe native DLL after the SDK-wrapper run;
- restore loader diagnostic config;
- restore `ClientSettings.json` to the user's pre-run state.

If cleanup fails, manually inspect and restore before any follow-up run:

```powershell
Get-Process VRising,VRisingServer -ErrorAction SilentlyContinue
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-local-package.ps1 -GamePath "C:\Software\VRising"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\write-diagnostic-config.ps1 -GamePath "C:\Software\VRising" -Stage loader
```

## Product Boundary

This is a local/private SDK-wrapper research proof. It does not change the release
package boundary and does not permit bundling NVIDIA SDK-wrapper binaries or
`nvngx_dlss.dll` in the public mod package.
