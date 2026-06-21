-- init_spec.lua: Integration tests for breakpoints top-level API
local bp = require("breakpoints")
local config = require("breakpoints.config")
local state = require("breakpoints.state")
local storage = require("breakpoints.storage")

describe("breakpoints (init)", function()
  local test_dir
  local dap_bp = _G._test_dap_breakpoints

  before_each(function()
    test_dir = vim.fn.tempname() .. "_bp_init_test"
    vim.fn.mkdir(test_dir, "p")
    config.apply({ storage_dir = test_dir })
    state.dirty = false
    state.setup_done = false
    state.dap_mutators_patched = false
    state.active_project_key = nil
    state.last_loaded_notice_key = nil
    dap_bp.clear()
    _G._test_picker_calls = {}
  end)

  after_each(function()
    vim.fn.delete(test_dir, "rf")
  end)

  it("setup applies config and calls on_setup", function()
    local called = false
    bp.setup({
      storage_dir = test_dir,
      markers = { ".git" },
      on_setup = function() called = true end,
    })
    assert.is_true(called)
    assert.same({ ".git" }, config.current.markers)
  end)

  it("mark_dirty + save round-trip", function()
    state.setup_done = true
    state.active_project_key = storage.project_key()

    local buf = vim.api.nvim_create_buf(true, false)
    local tmp = vim.fn.tempname() .. ".lua"
    vim.fn.writefile({ "test" }, tmp)
    vim.api.nvim_buf_set_name(buf, tmp)
    vim.fn.bufload(buf)
    dap_bp.set({ condition = "i > 5" }, buf, 1)

    bp.mark_dirty()
    bp.save()

    assert.equals(1, vim.fn.filereadable(storage.bp_path()))
    local content = vim.fn.readfile(storage.bp_path())[1]
    local data = vim.json.decode(content)
    local abs = vim.fn.fnamemodify(tmp, ":p")
    assert.truthy(data[abs])
    assert.equals(1, data[abs][1].line)
    assert.equals("i > 5", data[abs][1].condition)

    vim.api.nvim_buf_delete(buf, { force = true })
    vim.fn.delete(tmp)
  end)

  it("load restores breakpoints from disk", function()
    state.active_project_key = storage.project_key()
    local tmp = vim.fn.tempname() .. ".lua"
    vim.fn.writefile({ "a", "b" }, tmp)
    local abs = vim.fn.fnamemodify(tmp, ":p")

    local key = storage.project_key()
    local data = { [abs] = { { line = 2 } } }
    local file = io.open(storage.bp_path(key), "w")
    file:write(vim.json.encode(data))
    file:close()

    bp.load({ key = key })

    local all = dap_bp.get()
    local found = false
    for _, list in pairs(all) do
      for _, entry in ipairs(list) do
        if entry.line == 2 then found = true end
      end
    end
    assert.is_true(found)

    vim.fn.delete(tmp)
  end)

  it("icon_for returns ● for unknown", function()
    assert.equals("●", bp.icon_for("999", "missing.lua"))
  end)

  it("short_path shortens long paths", function()
    assert.equals("c/d.lua", bp.short_path("a/b/c/d.lua"))
  end)

  it("has_saved_project returns false initially", function()
    assert.is_false(bp.has_saved_project())
  end)

  it("has_saved_project returns true after save", function()
    state.active_project_key = storage.project_key()

    local buf = vim.api.nvim_create_buf(true, false)
    local tmp = vim.fn.tempname() .. ".lua"
    vim.fn.writefile({ "x" }, tmp)
    vim.api.nvim_buf_set_name(buf, tmp)
    vim.fn.bufload(buf)
    dap_bp.set({}, buf, 1)

    bp.mark_dirty()
    bp.save()
    assert.is_true(bp.has_saved_project())

    vim.api.nvim_buf_delete(buf, { force = true })
    vim.fn.delete(tmp)
  end)

  it("picker delegates to picker.nvim", function()
    local buf = vim.api.nvim_create_buf(true, false)
    local tmp = vim.fn.tempname() .. ".lua"
    vim.fn.writefile({ "x" }, tmp)
    vim.api.nvim_buf_set_name(buf, tmp)
    vim.fn.bufload(buf)
    dap_bp.set({}, buf, 1)
    state.active_project_key = storage.project_key()

    bp.picker()
    assert.equals(1, #_G._test_picker_calls)

    vim.api.nvim_buf_delete(buf, { force = true })
    vim.fn.delete(tmp)
  end)
end)
