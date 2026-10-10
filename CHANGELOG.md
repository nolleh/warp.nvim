# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [v0.7.0](https://github.com/nolleh/warp.nvim/releases/tag/v0.7.0) - 2026-10-10

### Added

- Visual selection browsing joins selected lines into one path when the complete selection resolves to an existing file or directory, ignoring whitespace at line boundaries. Otherwise, it keeps the existing per-line search.

## [v0.6.4](https://github.com/nolleh/warp.nvim/releases/tag/v0.6.4) - 2026-10-10

### Fixed

- Relative paths now prefer the directory of the current file, falling back to the working directory when the target is not found. This applies to files and directories in named file buffers.

## [v0.6.3](https://github.com/nolleh/warp.nvim/releases/tag/v0.6.3) - 2026-09-14

### Fixed

- Reference scanning now skips hidden interiors of closed folds while preserving visible fold headers and buffer coordinates.

## [v0.6.2](https://github.com/nolleh/warp.nvim/releases/tag/v0.6.2) - 2026-09-12

### Fixed

- Visual selection browsing now reads the active selection instead of stale selection marks.
- Markdown file links preserve `:line` and `:line:column` locations when opening their target files.
- The directory browser stays anchored to the matched buffer path across scrolling, line wrapping, and folds.

## [v0.6.1](https://github.com/nolleh/warp.nvim/releases/tag/v0.6.1) - 2026-09-10

### Fixed

- File opening skips `nofile` plugin windows.
- The selected directory path remains visible above the floating directory browser.

## [v0.6.0](https://github.com/nolleh/warp.nvim/releases/tag/v0.6.0) - 2026-07-13

### Added

- Visual selection browsing: in visual mode, the warp key now opens the first path-like target found in the selected text, and folders still open the directory browser.

## [v0.5.1](https://github.com/nolleh/warp.nvim/releases/tag/v0.5.1) - 2026-03-03

### Fixed

- Directory browser: `../` correctly navigates to the parent directory when the path has a trailing slash.

## [v0.5.0](https://github.com/nolleh/warp.nvim/releases/tag/v0.5.0) - 2026-03-03

### Added

- Directory browsing: when a path resolves to a folder, a floating directory browser opens at the hint position.
  - Navigate with `j`/`k`, `<C-n>`/`<C-p>`, open with `<CR>`, close with `q`/`<Esc>`.
  - In-place navigation into subdirectories and parent (`../`).
  - Honors the original open mode (edit / split / vsplit).
- `resolve_path` now returns a `PathType` (`"file"` | `"directory"` | `"notfound"`) as a second return value, eliminating redundant filesystem checks in callers.

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
