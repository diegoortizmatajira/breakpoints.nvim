-- storage_spec.lua: Tests for breakpoints.storage module
local storage = require("breakpoints.storage")
local config = require("breakpoints.config")

describe("breakpoints.storage", function()
  local test_dir

  before_each(function()
    test_dir = vim.fn.tempname() .. "_bp_test"
    vim.fn.mkdir(test_dir, "p")
    config.apply({ storage_dir = test_dir })
  end)

  after_each(function()
    vim.fn.delete(test_dir, "rf")
  end)

  it("storage_dir returns configured path", function()
    assert.equals(test_dir, storage.storage_dir())
  end)

  it("data_dir creates directory if missing", function()
    vim.fn.delete(test_dir, "rf")
    local dir = storage.data_dir()
    assert.equals(test_dir, dir)
    assert.equals(1, vim.fn.isdirectory(dir))
  end)

  it("project_key produces stable 12-char hash", function()
    local key = storage.project_key()
    assert.equals(12, #key)
    assert.equals(key, storage.project_key())
  end)

  it("project_key differs for different roots", function()
    local key1 = storage.project_key("/tmp/project_a")
    local key2 = storage.project_key("/tmp/project_b")
    assert.are_not.equals(key1, key2)
  end)

  it("bp_path includes key in filename", function()
    local key = "abc123def456"
    local path = storage.bp_path(key)
    assert.truthy(path:find(key .. "%.json$"))
  end)

  it("meta_path includes key in filename", function()
    local key = "abc123def456"
    local path = storage.meta_path(key)
    assert.truthy(path:find(key .. "%.meta%.json$"))
  end)

  it("bp_key concatenates path and line", function()
    assert.equals("/src/main.lua:42", storage.bp_key("/src/main.lua", 42))
  end)

  it("has_saved_project returns false when no file", function()
    assert.is_false(storage.has_saved_project())
  end)

  it("has_saved_project returns true when json exists", function()
    local key = storage.project_key()
    local file = io.open(test_dir .. "/" .. key .. ".json", "w")
    file:write("{}")
    file:close()
    assert.is_true(storage.has_saved_project())
  end)

  it("load_meta returns empty table when no file", function()
    local meta = storage.load_meta("nonexistent")
    assert.same({}, meta)
  end)

  it("save_meta and load_meta round-trip", function()
    local key = "test_meta_key"
    local meta = { ["/src/a.lua:10"] = "API", ["/src/b.lua:20"] = "DB" }
    storage.save_meta(meta, key)
    local loaded = storage.load_meta(key)
    assert.same(meta, loaded)
  end)

  it("load_meta handles corrupted json gracefully", function()
    local key = "corrupt_key"
    local file = io.open(storage.meta_path(key), "w")
    file:write("not json{{{")
    file:close()
    local meta = storage.load_meta(key)
    assert.same({}, meta)
  end)
end)
