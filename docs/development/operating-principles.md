# Operating Principles - 2026-06-05

These are project rules for the V Rising DLSS MVP work.

## Persistent Local Records

Keep durable local records for the important state of the project, including:

- MVP definition and changes to the MVP scope.
- Search findings, source links, and authority level.
- Technical route decisions and rejected alternatives.
- Runtime test intent, setup, logs, screenshots, performance captures, and cleanup notes.
- User-stated requirements that affect the project direction.

Use public-safe docs for distilled decisions and ignored local paths such as `artifacts/`, `dist/`, and `ref/` for generated output or third-party research material. Do not commit private chat logs, game files, NVIDIA runtime/SDK files, PureDark files, or generated local runtime artifacts.

## No Blind Testing

Do not launch or ask the user to run game tests just to see what happens. Before a test, write down the question being tested, the expected evidence, the pass/fail signal, and the cleanup path.

When a problem appears, first look for authoritative sources or comparable implementations:

- NVIDIA documentation/blogs/SDK guidance for DLSS behavior and parameters.
- Unity/HDRP/Core RP documentation or public source for render-pipeline behavior.
- Local V Rising interop/source-derived evidence for the exact runtime shape.
- Ignored third-party reference implementations in `ref/` when legally and ethically useful for ideas, not for copying proprietary code.

Game tests should come after that research, and should be as narrow as possible.
