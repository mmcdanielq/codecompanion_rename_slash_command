local session_titles = require("codecompanion_rename.session_titles")
local utils = require("codecompanion.utils")

---Parse an ISO 8601 timestamp string into a Unix timestamp
---@param iso string
---@return number|nil
local function timestamp_from_iso(iso)
  local pattern = "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)"
  local year, month, day, hour, min, sec = iso:match(pattern)
  if not year then
    return nil
  end
  local date = {
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = tonumber(hour),
    min = tonumber(min),
    sec = tonumber(sec),
  }
  -- os.time() treats the table as local time; add the UTC offset to correct for this
  local now = os.time()
  local utc = os.date("!*t", now)
  local utc_offset = os.difftime(now, os.time(utc))
  return os.time(date) + utc_offset
end

---Format a Unix timestamp as a short relative string (e.g. "5m", "2h", "3d")
---@param timestamp number
---@return string
local function make_relative(timestamp)
  local diff = os.time() - timestamp
  if diff < 60 then
    return diff .. "s"
  elseif diff < 3600 then
    return math.floor(diff / 60) .. "m"
  elseif diff < 86400 then
    return math.floor(diff / 3600) .. "h"
  else
    return math.floor(diff / 86400) .. "d"
  end
end

---@class CodeCompanion.SlashCommand.Resume: CodeCompanion.SlashCommand
local SlashCommand = {}

---@param args CodeCompanion.SlashCommand
function SlashCommand.new(args)
  local self = setmetatable({
    Chat = args.Chat,
    config = args.config,
    context = args.context,
  }, { __index = SlashCommand })

  return self
end

---Is the slash command enabled?
---@param chat CodeCompanion.Chat
---@return boolean,string
function SlashCommand.enabled(chat)
  if not chat.acp_connection then
    return false, "The resume slash command requires an ACP connection"
  end

  if not chat.acp_connection:can_list_sessions() then
    return false, "This agent does not support listing sessions"
  end

  if not chat.acp_connection:can_load_session() then
    return false, "This agent does not support loading sessions"
  end

  return true, ""
end

---Format a session for display in the picker
---@param session table SessionInfo
---@param custom_title? string User-assigned title stored locally
---@return string
local function format_session(session, custom_title)
  local parts = {}

  if session.updatedAt then
    local ts = timestamp_from_iso(session.updatedAt)
    if ts then
      table.insert(parts, "(" .. make_relative(ts) .. ")")
    end
  end

  local display_title = custom_title or session.title or session.sessionId
  table.insert(parts, display_title)

  return table.concat(parts, " ")
end

---Execute the slash command
---@return nil
function SlashCommand:execute()
  local Chat = self.Chat

  if Chat.cycle > 1 then
    return utils.notify(
      "The /resume command must be called before submitting any messages",
      vim.log.levels.WARN
    )
  end

  if not Chat.acp_connection then
    return utils.notify("No ACP connection available", vim.log.levels.WARN)
  end

  local sessions = Chat.acp_connection:session_list({
    max_sessions = (self.config.opts and self.config.opts.max_sessions) or 500,
  })

  if #sessions == 0 then
    return utils.notify("No previous sessions found", vim.log.levels.INFO)
  end

  local live_ids = vim.tbl_map(function(s)
    return s.sessionId
  end, sessions)
  session_titles.reconcile(live_ids)

  local stored_titles = session_titles.load_all()

  local choices = {}
  local session_map = {}
  for i, session in ipairs(sessions) do
    local custom_title = stored_titles[session.sessionId]
      and stored_titles[session.sessionId].title
    table.insert(choices, format_session(session, custom_title))
    session_map[i] = session
  end

  vim.ui.select(choices, {
    prompt = "Resume Session",
    kind = "codecompanion.nvim",
  }, function(_, idx)
    if not idx then
      return
    end

    local selected = session_map[idx]

    local updates = {}
    local ok = Chat.acp_connection:load_session(selected.sessionId, {
      on_session_update = function(update)
        table.insert(updates, update)
      end,
    })

    if ok then
      local acp_commands =
        require("codecompanion.interactions.chat.acp.commands")
      acp_commands.link_buffer_to_session(
        Chat.bufnr,
        Chat.acp_connection.session_id
      )

      require("codecompanion.interactions.chat.acp.render").restore_session(
        Chat,
        updates
      )

      local custom_title = session_titles.get(Chat.acp_connection.session_id)
      if custom_title then
        Chat.title_locked = true
        Chat:set_title(custom_title)
      elseif selected.title then
        Chat:set_title(selected.title)
      end

      utils.fire("ACPChatRestored", {
        bufnr = Chat.bufnr,
        id = Chat.id,
        session_id = Chat.acp_connection.session_id,
        title = Chat.title,
      })

      utils.notify(
        "Resumed session: " .. (Chat.title or selected.sessionId),
        vim.log.levels.INFO
      )
    else
      utils.notify("Failed to load session", vim.log.levels.ERROR)
    end
  end)
end

return SlashCommand
