# breakpoints.nvim

Persistent DAP breakpoints with IntelliJ-style group support for Neovim.

Breakpoints survive across sessions — automatically saved on exit and restored on startup, scoped per project root.

## Features

- **Persistent storage** — breakpoints serialized to `stdpath("data")/breakpoints/<project_hash>.json`
- **Per-project isolation** — project root detected via configurable markers (`pom.xml`, `package.json`, `.git`, etc.)
- **Group metadata** — assign breakpoints to named groups (e.g. "Auth", "Payments") stored in companion `.meta.json`
- **Auto-save** — `VimLeave` + `DirChanged` + `SessionLoadPost` autocmds, plus hooks on `dap.toggle_breakpoint()` / `set_breakpoint()` / `clear_breakpoints()`
- **Picker UI** — browse all breakpoints with file preview, jump-to-location, inline editing (condition, log, hit count, group)
- **Type-aware icons** — `●` normal, `◆` conditional, `◉` logpoint, `◇` hit condition

## Requirements

- Neovim ≥ 0.10
- [nvim-dap](https://github.com/mfussenegger/nvim-dap)
- A picker for the picker UI — either [picker.nvim](https://github.com/lenincamp/picker.nvim) or [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim). Whichever is installed is detected automatically; if both are present, `picker.nvim` is used unless `picker` is configured explicitly (see [Configuration](#configuration)).
- Optional: [vim-obsession](https://github.com/tpope/vim-obsession) for automatic `Session.vim` restore flows.

## Installation

### lazy.nvim

```lua
{
  "lenincamp/breakpoints.nvim",
  dependencies = { "mfussenegger/nvim-dap", "lenincamp/picker.nvim" },
  event = "VeryLazy",
  opts = {},
}
```

Using Telescope instead:

```lua
{
  "lenincamp/breakpoints.nvim",
  dependencies = { "mfussenegger/nvim-dap", "nvim-telescope/telescope.nvim" },
  event = "VeryLazy",
  opts = {},
}
```

### Custom opts example

```lua
{
  "lenincamp/breakpoints.nvim",
  dependencies = { "mfussenegger/nvim-dap", "lenincamp/picker.nvim" },
  event = "VeryLazy",
  opts = {
    markers = { "pom.xml", "build.gradle", "package.json", ".git" },
    storage_dir = vim.fn.stdpath("data") .. "/breakpoints",
    picker = "auto", -- "auto" | "picker.nvim" | "telescope"
    on_setup = function()
      -- Called once after setup completes (e.g. define DAP signs)
    end,
  },
}
```

### vim.pack / packadd (manual)

```lua
vim.cmd("packadd breakpoints.nvim")
require("breakpoints").setup({})
```

## Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `markers` | `string[]` | `{"mvnw","pom.xml","build.gradle","build.gradle.kts","package.json",".git"}` | Files/dirs used to detect project root |
| `storage_dir` | `string` | `stdpath("data") .. "/breakpoints"` | Directory for JSON persistence files |
| `picker` | `"auto"\|"picker.nvim"\|"telescope"` | `"auto"` | Which picker backend to use. `"auto"` detects what's installed, preferring `picker.nvim` |
| `on_setup` | `function?` | `nil` | Callback invoked once after hooks are registered |

## API

```lua
local bp = require("breakpoints")

bp.setup(opts)            -- Initialize hooks, autocmds, load saved breakpoints
bp.save()                 -- Persist current breakpoints to disk (if dirty)
bp.save_async()           -- Schedule save on next event loop iteration
bp.load(opts)             -- Load breakpoints from disk (opts.key = project key)
bp.mark_dirty()           -- Flag state as needing save
bp.picker()               -- Open breakpoint picker with preview
bp.assign_group()         -- Assign current-line breakpoint to a named group
bp.icon_for(lnum, path)   -- Get icon string for breakpoint at lnum in path
bp.short_path(path)       -- Abbreviate path to last 2 segments
bp.has_saved_project()    -- Check if current project has a saved breakpoints file
```

## Picker Actions

When the picker is open, these keys are available in normal mode:

| Key | Action |
|-----|--------|
| `<CR>` | Jump to breakpoint location |
| `d` | Delete breakpoint |
| `n` | Convert to normal breakpoint (remove condition/log) |
| `c` | Edit condition |
| `l` | Edit log message |
| `h` | Edit hit condition |
| `G` | Move to group |
| `s` | Force save |
| `q` | Close picker |

## Breakpoint Icons

| Icon | Meaning |
|------|---------|
| `●` | Normal breakpoint |
| `◆` | Conditional breakpoint |
| `◉` | Log point |
| `◇` | Hit condition breakpoint |

## Storage Format

Each project gets two files based on a 12-char SHA-256 hash of the project root:

- `<hash>.json` — breakpoint data (file paths → line/condition/log/hit arrays)
- `<hash>.meta.json` — group assignments (file:line → group name)

## License

MIT
