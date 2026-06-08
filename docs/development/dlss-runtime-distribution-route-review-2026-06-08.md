# DLSS Runtime Distribution Route Review - 2026-06-08

Status: no runtime route is approved yet. This review did not launch V Rising,
modify game files, or add NVIDIA binaries to the release/package tree.

This is an engineering release review, not legal advice.

## Current Official Source Snapshot

- NVIDIA/DLSS is the public RTX DLSS SDK repository. Its README says the DLSS
  sample app is included only in releases:
  https://github.com/NVIDIA/DLSS
- The latest visible GitHub release is `DLSS 310.6.0 SDK`, released
  2026-04-21:
  https://github.com/NVIDIA/DLSS/releases/tag/v310.6.0
- The current NVIDIA/DLSS repository `LICENSE.txt` is the NVIDIA RTX SDKs
  license, version dated 2024-03-14. It permits distribution of SDK materials
  only as incorporated in object-code form into an application and subject to
  distribution requirements; it also forbids standalone SDK redistribution and
  adds notification/trademark/update obligations for DLSS/NGX integrations:
  https://github.com/NVIDIA/DLSS/blob/main/LICENSE.txt
- NVIDIA's NGX programming guide says NGX feature DLLs are distributed with the
  application, only the DLLs for used features should be included, and installers
  should remove them on uninstall:
  https://docs.nvidia.com/ngx/latest/programming-guide/
- NVIDIA Streamline's programming guide says NVIDIA-provided modules are signed,
  development/self-built modules are not for shipping, manual/custom integration
  must execute the common present path exactly once per frame, and DLSS SR builds
  include the DLSS-SR DLL option:
  https://github.com/NVIDIA-RTX/Streamline/blob/main/docs/ProgrammingGuide.md

## Local Candidate Runtime Evidence

Local research copy, not packaged:

```text
Path=ref\NVIDIA-DLSS-310.6.0\nvngx_dlss.dll
Length=58830448
FileVersion=310.6.0.0
ProductVersion=310.6.0.0
Description=NVIDIA DLSS - DVS PRODUCTION
SignatureStatus=Valid
Signer=NVIDIA Corporation
SHA256=099B3E1E3AD3F226DE621FE570B26CC554CC775E2606BE23EB222D6245674070
```

This proves a precise local candidate exists for research. It does not by itself
approve redistributing the file in the GitHub/Thunderstore package.

## Route Matrix

| Route | Current decision | Reason |
| --- | --- | --- |
| Keep package source-safe/no-runtime | Accepted for diagnostic releases only | It satisfies clean-room and release-boundary rules, but fails the playable-MVP requirement because normal users would still need an external runtime. |
| Bundle `nvngx_dlss.dll` from NVIDIA/DLSS SDK release | Candidate, not approved | It is the closest path to drag-in install UX, but needs a deliberate release approval covering SDK license terms, exact binary provenance, notices, trademark wording, NVIDIA notification handling, and package validation changes. |
| Download/install runtime from an authoritative NVIDIA source during setup | Candidate, not approved | It could avoid bundling, but needs a deterministic official source URL, checksum pinning, user-visible consent/error handling, no opaque code download behavior, and Thunderstore/mod-manager policy review. |
| Switch to Streamline distribution | Not selected for the next MVP loop | Streamline adds mandatory modules, signature/security handling, early init/present-hooking requirements, and a larger integration surface; it is not a simple distribution-only fix for the current D3D11 NGX path. |
| Use third-party DLSS DLL mirrors, DLSS Swapper, or arbitrary user downloads | Rejected for MVP | It is not an authoritative runtime route and conflicts with the user's requirement that the mod not require ad hoc manual DLL downloads. |
| Assume NVIDIA drivers provide a usable `nvngx_dlss.dll` | Rejected for now | No current authoritative evidence in this review proves a stable system-driver path that a V Rising mod can rely on without packaging or setup. |

## Required Approval Before MVP

To close the runtime-distribution blocker, create
`docs\release\dlss-runtime-distribution-approval.md` from the template only after
one exact route is chosen. The approval must include:

- route type and exact runtime source;
- source evidence URLs;
- binary version, filenames, checksums, and signature state where applicable;
- notices/license/trademark wording that will ship with the package;
- whether NVIDIA notification is required and how it is handled;
- package validation and release-boundary changes;
- reviewer and approval date.

`scripts\test-dlss-runtime-distribution-gate.ps1` now enforces more than
non-empty template fields. A live approval must:

- use exactly one approved `Runtime Route:` value:
  `Bundled NVIDIA DLSS SDK runtime`,
  `Authoritative NVIDIA installer or dependency`, or
  `Documented non-NVIDIA-runtime route`;
- include at least one `http` or `https` URL under `Source Evidence URLs:`;
- avoid third-party mirror, DLSS Swapper, arbitrary/user-supplied DLL, and
  manual DLL-download routes;
- for bundled NVIDIA DLSS SDK runtime approval, name `nvngx_dlss.dll` and include
  a SHA256 checksum.

`scripts\test-dlss-runtime-distribution-gate-contract.ps1` protects those
semantics with synthetic approval records: one bundled NVIDIA SDK approval shape
must pass, while third-party/manual, missing-URL, and missing-SHA256 shapes must
fail. The GitHub Actions package workflow now runs this no-launch/no-modify
contract guard before packaging.

Until then, `scripts\test-dlss-runtime-distribution-gate.ps1` must keep
`RuntimeDistributionApproved=false`, and release readiness must keep the runtime
distribution MVP item blocked.
