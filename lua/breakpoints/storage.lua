local M = {}

local config = require("breakpoints.config")

local function normalize(path)
  if type(path) ~= "string" or path == "" then return "" end
  local real = vim.uv.fs_realpath(path)
  return vim.fs.normalize(real or path)
end

local function find_project_root(start)
  return vim.fs.root(start or 0, config.current.markers) or vim.fn.getcwd()
end

function M.storage_dir()
  return config.current.storage_dir
end

function M.data_dir()
  local dir = M.storage_dir()
  vim.fn.mkdir(dir, "p")
  return dir
end

function M.project_root()
  return find_project_root(vim.fn.getcwd())
end

function M.project_key(root)
  root = normalize(root or M.project_root())
  if root == "" then root = vim.fn.getcwd() end
  return vim.fn.sha256(root):sub(1, 12)
end

function M.bp_path(key)
  return M.data_dir() .. "/" .. (key or M.project_key()) .. ".json"
end

function M.meta_path(key)
  return M.data_dir() .. "/" .. (key or M.project_key()) .. ".meta.json"
end

function M.bp_key(fname, line)
  return fname .. ":" .. tostring(line)
end

function M.has_saved_project()
  return vim.fn.filereadable(M.storage_dir() .. "/" .. M.project_key() .. ".json") == 1
end

function M.load_meta(key)
  local file = io.open(M.meta_path(key), "r")
  if not file then return {} end
  local raw = file:read("*a")
  file:close()
  local ok, decoded = pcall(vim.json.decode, raw)
  return ok and decoded or {}
end

function M.save_meta(meta, key)
  local file = io.open(M.meta_path(key), "w")
  if file then
    file:write(vim.json.encode(meta))
    file:close()
  end
end

return M
