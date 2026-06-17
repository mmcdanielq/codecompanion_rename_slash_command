local TTL_SECONDS = 90 * 24 * 60 * 60 -- 90 days

local data_path = vim.fs.joinpath(vim.fn.stdpath("data"), "codecompanion", "session_titles.json")

---@type table<string, {title: string, updated_at: number}>|nil
local cache = nil

---Write the in-memory cache to disk
---@return nil
local function flush()
  local dir = vim.fn.fnamemodify(data_path, ":h")
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
  local ok, encoded = pcall(vim.json.encode, cache)
  if not ok then
    return vim.notify("codecompanion-rename: failed to encode session titles JSON: " .. encoded, vim.log.levels.ERROR)
  end
  local file = io.open(data_path, "w")
  if not file then
    return vim.notify("codecompanion-rename: failed to open " .. data_path .. " for writing", vim.log.levels.ERROR)
  end
  file:write(encoded)
  file:close()
end

---Load all stored session titles, pruning expired entries
---@return table<string, {title: string, updated_at: number}>
local function load_all()
  if cache then
    return cache
  end

  local file = io.open(data_path, "r")
  if not file then
    cache = {}
    return cache
  end

  local content = file:read("*a")
  file:close()

  local ok, decoded = pcall(vim.json.decode, content)
  if not ok or type(decoded) ~= "table" then
    cache = {}
    return cache
  end

  local now = os.time()
  local pruned = false
  for session_id, entry in pairs(decoded) do
    if type(entry) ~= "table" or type(entry.title) ~= "string" or type(entry.updated_at) ~= "number" then
      decoded[session_id] = nil
      pruned = true
    elseif (now - entry.updated_at) > TTL_SECONDS then
      decoded[session_id] = nil
      pruned = true
    end
  end

  cache = decoded
  if pruned then
    flush()
  end

  return cache
end

---Get the stored title for a session
---@param session_id string
---@return string|nil
local function get(session_id)
  local titles = load_all()
  local entry = titles[session_id]
  return entry and entry.title or nil
end

---Store a title for a session
---@param session_id string
---@param title string
---@return nil
local function set(session_id, title)
  load_all()
  cache[session_id] = { title = title, updated_at = os.time() }
  flush()
end

---Remove the stored title for a session
---@param session_id string
---@return nil
local function remove(session_id)
  load_all()
  if cache[session_id] then
    cache[session_id] = nil
    flush()
  end
end

---Remove stored titles for session IDs not present in the given live list
---@param live_session_ids string[]
---@return nil
local function reconcile(live_session_ids)
  load_all()
  local live = {}
  for _, id in ipairs(live_session_ids) do
    live[id] = true
  end
  local pruned = false
  for session_id in pairs(cache) do
    if not live[session_id] then
      cache[session_id] = nil
      pruned = true
    end
  end
  if pruned then
    flush()
  end
end

return {
  load_all = load_all,
  get = get,
  set = set,
  remove = remove,
  reconcile = reconcile,
}
