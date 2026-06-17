---@class CodeCompanion.Extension.Rename
local M = {}

---@param opts {ttl_days?: number, data_path?: string}
function M.setup(opts)
  opts = opts or {}

  require("codecompanion_rename.session_titles").init(opts)

  local config = require("codecompanion.config")
  local slash_commands = config.interactions.chat.slash_commands

  -- Add /rename slash command (not present in core)
  slash_commands["rename"] = {
    path = "codecompanion_rename.slash_command",
    description = "Rename the current chat",
    opts = {
      contains_code = false,
    },
  }

  -- Override /resume to use the custom version that shows stored titles
  if slash_commands["resume"] then
    slash_commands["resume"].path = "codecompanion_rename.resume"
  end

  -- Monkey-patch Chat.set_title to respect title_locked
  local Chat = require("codecompanion.interactions.chat")
  local original_set_title = Chat.set_title
  Chat.set_title = function(self, title, force)
    if self.title_locked and not force then
      return self
    end
    return original_set_title(self, title)
  end
end

return M
