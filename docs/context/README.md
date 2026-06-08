# Context Reconstruction

This directory contains durable context rebuilt from long-running Codex conversations.
It exists to make future MVP work resumable without relying on chat memory alone.

## Source Logs

- `docs/chatlog/chat-log-codex-2026-06-04-c2222419.md`
  - Long 2026-06-04/2026-06-05 implementation run.
  - Rebuilt in chunks in [chatlog-2026-06-04-reconstruction.md](chatlog-2026-06-04-reconstruction.md).
  - Coverage is checked by
    [../development/phase-0-chatlog-reconstruction-coverage-2026-06-08.md](../development/phase-0-chatlog-reconstruction-coverage-2026-06-08.md)
    and `scripts/test-chatlog-reconstruction-coverage.ps1`.
- `docs/chatlog/chat-log-codex-2026-06-05-110887f1.md`
  - Goal-shaping conversation that explained why context reconstruction and gameplay automation exploration are mandatory.
  - Distilled into [current-context.md](current-context.md).

## How To Use This Directory

Use these files as a resume map, not as implementation proof by themselves. For any code,
release, or runtime claim, re-check the current source tree, scripts, build output,
runtime logs, screenshots, performance artifacts, upstream documentation, and actual
game behavior.

The current MVP definition remains [../mvp.md](../mvp.md).
