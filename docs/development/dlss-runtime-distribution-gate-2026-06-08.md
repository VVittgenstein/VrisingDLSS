# DLSS Runtime Distribution Gate - 2026-06-08

Status: MVP blocker remains open. No V Rising runtime was launched, and no game
or package files were modified by this investigation.

This is an engineering release gate, not legal advice.

## Question

Can the playable MVP be considered ready while the package still does not bundle
or otherwise provision an approved DLSS runtime?

Answer: no. The diagnostic package may remain source-safe and no-runtime, but
the playable MVP requires a normal-user runtime plan that does not depend on an
ad hoc manual DLL download.

## Current Package State

- `scripts\check-release-boundary.ps1` forbids `nvngx_dlss.dll`, Streamline
  DLLs, PureDark binaries, game binaries, and local SDK-wrapper artifacts from
  release trees.
- `package\thunderstore\ThirdPartyNotices.md` says DLSS runtime redistribution
  has not been approved for this package.
- `docs\mvp.md` allows a fallback source-safe package path, but the active
  thread goal now requires the final playable MVP to be drag-in/installable
  without asking users to independently source a DLL.

## Official Source Snapshot

- NVIDIA's DLSS GitHub repository describes itself as the public RTX DLSS SDK
  repository and says the sample app is included only in releases:
  https://github.com/NVIDIA/DLSS
- The NVIDIA RTX SDK license permits SDK material distribution only when
  incorporated in object-code form into an application and subject to the
  license's distribution requirements; it also forbids standalone SDK
  redistribution and includes DLSS/NGX notification/marketing obligations:
  https://developer.nvidia.com/gameworks/nvidia_rtx_sdks_license_12apr2021.pdf
- NVIDIA's NGX programming guide says applications should distribute only the
  DLLs for the features they use and remove them on uninstall:
  https://docs.nvidia.com/ngx/latest/programming-guide/
- NVIDIA Streamline's programming guide says Streamline applications must ship
  mandatory Streamline modules and, for DLSS, the DLSS plugin/runtime modules;
  it also highlights signature/security requirements and release-vs-development
  binary distinctions:
  https://github.com/NVIDIA-RTX/Streamline/blob/main/docs/ProgrammingGuide.md

## Current Decision

Keep the public package no-runtime and source-safe until a separate runtime
distribution review approves one exact path. A future approval record should
name the runtime route, binary provenance, version, notices, trademark wording,
user installation behavior, and any NVIDIA notification/contact handling.

Until that exists, release readiness must keep a blocked MVP item for runtime
distribution even if the technical DLSS evaluate path and visual/performance
evidence improve.

The gate is mechanically checked by:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-dlss-runtime-distribution-gate.ps1 -Json
```

With no approval record, the validator reports `Status=Blocked`,
`RuntimeDistributionApproved=false`, `LaunchesGame=false`, and
`ModifiesGameFiles=false`. If an approval record is added later, it must pass
the validator's required-marker and placeholder checks before readiness can mark
this gate as `Pass`.

## Accepted Future Evidence

One of these would close this gate:

- an approved bundled-runtime path with exact `nvngx_dlss.dll` provenance,
  version, license/notice text, and package validation updates; or
- an approved installer/dependency path that obtains the runtime from an
  authoritative source without requiring users to manually download or copy an
  arbitrary DLL; or
- a documented non-NVIDIA-runtime route that satisfies the playable MVP
  definition and legal/release constraints.

Until then, `get-release-readiness-status.ps1` should report the runtime
distribution path as `Blocked` for MVP.
