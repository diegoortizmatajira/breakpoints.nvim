-- picker_spec.lua: Tests for breakpoints.picker module
local picker_mod = require("breakpoints.picker")
local storage = require("breakpoints.storage")
local config = require("breakpoints.config")
local state = require("breakpoints.state")

describe("breakpoints.picker", function()
  local test_dir
  local dap_bp = _G._test_dap_breakpoints

  before_each(function()
    test_dir = vim.fn.tempname() .. "_bp_picker_test"
    vim.fn.mkdir(test_dir, "p")
    config.apply({ storage_dir = test_dir })
    state.dirty = false
    state.setup_done = false
    state.dap_mutators_patched = false
    state.active_project_key = storage.project_key()
    dap_bp.clear()
    _G._test_picker_calls = {}
  end)

  after_each(function()
    vim.fn.delete(test_dir, "rf")
  end)

  it("notifies when no breakpoints exist", function()
    local notified = {}
    vim.notify = function(msg) notified[#notified + 1] = msg end
    picker_mod.open()
    assert.truthy(#notified > 0)
    assert.truthy(notified[1]:find("No breakpoints"))
  end)

  it("opens picker.nvim with correct opts when breakpoints exist", function()
    local buf = vim.api.nvim_create_buf(true, false)
    local tmp = vim.fn.tempname() .. ".lua"
    vim.fn.writefile({ "line1", "line2" }, tmp)
    vim.api.nvim_buf_set_name(buf, tmp)
    vim.fn.bufload(buf)
    dap_bp.set({}, buf, 1)
    state.active_project_key = storage.project_key()

    picker_mod.open()

    assert.equals(1, #_G._test_picker_calls)
    local call = _G._test_picker_calls[1]
    assert.equals(1, #call.items)
    assert.equals("Breakpoints", call.opts.prompt)
    assert.equals("intellij_grep", call.opts.layout)
    assert.is_true(call.opts.preview_open)
    assert.truthy(call.opts.actions.d)
    assert.truthy(call.opts.actions.c)
    assert.truthy(call.opts.actions.l)
    assert.truthy(call.opts.actions.h)
    assert.truthy(call.opts.actions.G)
    assert.truthy(call.opts.actions.s)
    assert.truthy(call.opts.actions.n)

    vim.api.nvim_buf_delete(buf, { force = true })
    vim.fn.delete(tmp)
  end)

  it("preview returns file path from item", function()
    local buf = vim.api.nvim_create_buf(true, false)
    local tmp = vim.fn.tempname() .. ".lua"
    vim.fn.writefile({ "x" }, tmp)
    vim.api.nvim_buf_set_name(buf, tmp)
    vim.fn.bufload(buf)
    dap_bp.set({}, buf, 1)
    state.active_project_key = storage.project_key()

    picker_mod.open()

    local call = _G._test_picker_calls[1]
    local item = call.items[1]
    local preview_path = call.opts.preview(item)
    assert.equals(vim.fn.fnamemodify(tmp, ":p"), preview_path)

    vim.api.nvim_buf_delete(buf, { force = true })
    vim.fn.delete(tmp)
  end)

  it("preview_lnum returns line number from item", function()
    local buf = vim.api.nvim_create_buf(true, false)
    local tmp = vim.fn.tempname() .. ".lua"
    vim.fn.writefile({ "x", "y" }, tmp)
    vim.api.nvim_buf_set_name(buf, tmp)
    vim.fn.bufload(buf)
    dap_bp.set({}, buf, 2)
    state.active_project_key = storage.project_key()

    picker_mod.open()

    local call = _G._test_picker_calls[1]
    local item = call.items[1]
    assert.equals(2, call.opts.preview_lnum(item))

    vim.api.nvim_buf_delete(buf, { force = true })
    vim.fn.delete(tmp)
  end)

  it("on_choice jumps to breakpoint location", function()
    local buf = vim.api.nvim_create_buf(true, false)
    local tmp = vim.fn.tempname() .. ".lua"
    vim.fn.writefile({ "line1", "target", "line3" }, tmp)
    vim.api.nvim_buf_set_name(buf, tmp)
    vim.fn.bufload(buf)
    dap_bp.set({}, buf, 2)
    state.active_project_key = storage.project_key()

    picker_mod.open()

    local call = _G._test_picker_calls[1]
    call.on_choice(call.items[1])

    local cursor = vim.api.nvim_win_get_cursor(0)
    assert.equals(2, cursor[1])

    vim.api.nvim_buf_delete(buf, { force = true })
    vim.fn.delete(tmp)
  end)

  it("items are sorted by group then file then line", function()
    local buf = vim.api.nvim_create_buf(true, false)
    local tmp = vim.fn.tempname() .. ".lua"
    vim.fn.writefile({ "a", "b", "c" }, tmp)
    vim.api.nvim_buf_set_name(buf, tmp)
    vim.fn.bufload(buf)
    dap_bp.set({}, buf, 3)
    dap_bp.set({}, buf, 1)
    state.active_project_key = storage.project_key()

    picker_mod.open()

    local call = _G._test_picker_calls[1]
    assert.equals(2, #call.items)
    assert.truthy(call.items[1].lnum < call.items[2].lnum)

    vim.api.nvim_buf_delete(buf, { force = true })
    vim.fn.delete(tmp)
  end)
end)
