# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [v0.4.0](https://github.com/nolleh/warp.nvim/releases/tag/v0.4.0) - 2026-02-27

### Added

- Buffer-relative path fallback: when a relative path is not found under `cwd`, warp now resolves it relative to the current buffer's file directory before giving up.

## [v0.3.0](https://github.com/nolleh/warp.nvim/releases/tag/v0.3.0) - 2026-02-04

### Added

- Column support: detects `file:line:col` patterns and jumps to the exact column position (e.g. `src/main.rs:42:15`).

## [v0.2.0](https://github.com/nolleh/warp.nvim/releases/tag/v0.2.0) - 2026-02-03

### Added

- Markdown link support: detects `[text](target)` links in `.md` files.
- Anchor links (`[text](#heading)`) jump to the matching heading in the same file.
- URL links in markdown format open in the browser.

### Fixed

- Overlapping matches no longer produce duplicate hints; matched ranges are tracked to show only one hint per link.
- Extmark position corrected for markdown links.

## [v0.1.0](https://github.com/nolleh/warp.nvim/releases/tag/v0.1.0) - 2026-01-29

### Added

- URL support: detects `https://` links and opens them in the default browser (green hints).

### Fixed

- Extmark position off-by-one error corrected.

## [v0.0.2](https://github.com/nolleh/warp.nvim/releases/tag/v0.0.2) - 2026-01-27

### Added

- Split / Vsplit support: prefix hint with `S` or `V` to open in split windows.

## [v0.0.1](https://github.com/nolleh/warp.nvim/releases/tag/v0.0.1) - 2026-01-22

### Added

- Initial release of warp.nvim.
- File path detection in visible buffer area (`file`, `file:line` patterns).
- Hint-based navigation to jump to detected paths.
- Smart window targeting (opens files in editor window, not terminal).
- Wrapped path support (handles paths broken across lines by terminal width).
- Lazy loading support with configurable keymap.
