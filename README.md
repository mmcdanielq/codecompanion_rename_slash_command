# codecompanion-rename.nvim

A [codecompanion.nvim](https://github.com/olimorris/codecompanion.nvim) extension that adds a `/rename` slash command to chat buffers. Custom names persist across ACP sessions and are shown in the `/resume` picker.

## Installation

```lua
-- lazy.nvim
{
  "yourusername/codecompanion-rename.nvim",
  dependencies = { "olimorris/codecompanion.nvim" },
}
```

Then register the extension in your codecompanion setup:

```lua
require("codecompanion").setup({
  extensions = {
    rename = { enabled = true },
  },
})
```

## Usage

**`/rename`** — rename the current chat buffer.

- With an inline argument: `/rename My project refactor`
- Without an argument: opens an input prompt pre-filled with the current title

Works with both HTTP and ACP adapters. With ACP, the name is persisted to disk and restored when the session is resumed via `/resume`.

**`/resume`** — the built-in command is overridden to show custom names in the session picker.

## How it works

- Custom titles are stored at `~/.local/share/nvim/codecompanion/session_titles.json`
- Titles expire after 90 days
- Stale entries (sessions no longer on the server) are pruned each time `/resume` is opened
- ACP `session_info_update` pushes cannot overwrite a manually set title
