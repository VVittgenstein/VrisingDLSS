# DLSS Runtime Distribution Approval

This template is for a future playable-MVP release review. Do not rename or copy
it to `docs/release/dlss-runtime-distribution-approval.md` until every field is
resolved and the approval is intentional.

Runtime Route: TBD

Runtime Source: TBD

Source Evidence URLs: TBD

Runtime Version: TBD

Runtime Files: TBD

Checksums: TBD

License Notices: TBD

Trademark Wording: TBD

User Installation Behavior: TBD

NVIDIA Notification Handling: TBD

Package Validation Updates: TBD

Release Boundary Decision: TBD

Reviewer: TBD

Approval Date: TBD

## Notes

- The approval record must not contain `TBD`, `TODO`, `UNKNOWN`, unresolved
  angle-bracket placeholders, or empty marker values.
- The approval record must identify the exact binary provenance and version, not
  a generic web search or user-supplied DLL.
- The approval record must include source evidence URLs for the selected route.
- `Runtime Route:` must be exactly one of:
  `Bundled NVIDIA DLSS SDK runtime`,
  `Authoritative NVIDIA installer or dependency`, or
  `Documented non-NVIDIA-runtime route`.
- Third-party mirrors, DLSS Swapper, arbitrary/user-supplied DLLs, and manual DLL
  download instructions are not approvable MVP runtime routes.
- If `Runtime Route:` is `Bundled NVIDIA DLSS SDK runtime`, `Runtime Files:` must
  name `nvngx_dlss.dll` and `Checksums:` must include a SHA256 value.
- If `Runtime Route:` is `Bundled NVIDIA DLSS SDK runtime`, the approval must
  identify an official NVIDIA/DLSS source URL, state that the runtime is
  production/release and non-watermarked, record a valid NVIDIA signature check,
  name the NVIDIA RTX SDKs license/`LICENSE.txt`, include NVIDIA/DLSS trademark
  wording, explicitly address https://developer.nvidia.com/sw-notification, and
  name the updates to `check-release-boundary.ps1`,
  `validate-thunderstore-package.ps1`, and `ThirdPartyNotices`.
- If the selected path bundles runtime files, update release-boundary and package
  validation before approving.
- If the selected path uses an installer or dependency, describe the exact
  source and why it does not require ad hoc manual DLL downloads.
