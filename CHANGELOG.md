# Changelog

## Unreleased

### New Features

- feat: Add `animation` attribute with `none`, `fast`, `normal`, and `slow` presets driving `--bs-offcanvas-transition-duration`.
- feat: Add `auto-dismiss` attribute (milliseconds) that closes the panel after a delay, with a small JS helper that cancels the timer on early dismissal.
- feat: Add `.offcanvas-trigger` child div to supply custom markdown as the trigger content, replacing `trigger-text`/`trigger-icon` for that panel.
- feat: Add `trigger-style` attribute for inline CSS on the trigger element.

### Bug Fixes

- fix: Merge user-supplied trigger styles with the built-in `cursor: pointer;` hint on text triggers instead of dropping them.
- fix: Reset per-document state (offcanvas ID counter and JS helper flag) in the `Meta` pass to prevent leakage across batch renders.
- fix: Warn on invalid `backdrop`, `trigger-type`, `animation`, and `auto-dismiss` values instead of passing them through silently.

### Documentation

- docs: Document Bootstrap version assumptions (5.0+ for offcanvas, 5.2+ for `.offcanvas-{sm,...}`, 5.3+ for the CSS custom property used by `animation`).
- docs: Cover the new attributes (`animation`, `auto-dismiss`, `trigger-style`) and the `.offcanvas-trigger` child div in README, schema, and example.

### Refactoring

- refactor: Synchronise shared modules with canonical versions.

## 1.2.1 (2026-04-15)

### Refactoring

- refactor: Synchronise shared module (`logging.lua`) with canonical version.

### Documentation

- docs: Remove version pinning from GitHub URL in example.

## 1.2.0 (2026-03-23)

### Refactoring

- refactor: Replace monolithic `utils.lua` with focused modules (`string.lua`, `logging.lua`, `metadata.lua`, `pandoc-helpers.lua`, `html.lua`, `paths.lua`, `colour.lua`).

## 1.1.1 (2026-02-21)

### New Features

- feat: Rename element-attributes to attributes and add classes section (#18).

## 1.1.0 (2026-02-21)

### New Features

- feat: Add extension-provided code snippets (#16).
- feat: Add _schema.yml for configuration validation and IDE support (#13).

### Style

- style: Three colons by default.

## 1.0.2 (2026-02-11)

### Bug Fixes

- fix: Update copyright year.

## 1.0.1 (2025-12-03)

### Bug Fixes

- fix: Set footer padding in offcanvas component (#10).

## 1.0.0 (2025-12-03)

### New Features

- feat: Initialise quarto-offcanvas extension repository.
