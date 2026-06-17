local session_titles = require("codecompanion_rename.session_titles")

---@class CodeCompanion.SlashCommand.Rename: CodeCompanion.SlashCommand
local SlashCommand = {}

---@param args CodeCompanion.SlashCommand
function SlashCommand.new(args)
  return setmetatable({
    Chat = args.Chat,
    config = args.config,
    context = args.context,
  }, { __index = SlashCommand })
end

---Execute the slash command
---@return nil
function SlashCommand:execute()
  local function apply(title)
    title = title and vim.trim(title)
    if not title or title == "" then
      return
    end
    self.Chat.title_locked = true
    self.Chat:set_title(title)
    local session_id = self.Chat.acp_connection and self.Chat.acp_connection.session_id
    if session_id then
      session_titles.set(session_id, title)
    end
  end

  if self.context and self.context.args and self.context.args ~= "" then
    return apply(self.context.args)
  end

  vim.ui.input({ prompt = "Rename chat: ", default = self.Chat.title or "" }, apply)
end

return SlashCommand
