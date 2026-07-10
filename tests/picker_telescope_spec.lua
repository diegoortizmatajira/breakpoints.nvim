-- picker_telescope_spec.lua: Tests for the telescope.nvim picker backend
-- and backend resolution/selection logic.
local picker_mod = require("breakpoints.picker")
local storage = require("breakpoints.storage")
local config = require("breakpoints.config")
local state = require("breakpoints.state")
local dap_bp = _G._test_dap_breakpoints

local function make_bp(line)
  local buf = vim.api.nvim_create_buf(true, false)
  local tmp = vim.fn.tempname() .. ".lua"
  vim.fn.writefile({ "a", "b", "c" }, tmp)
  vim.api.nvim_buf_set_name(buf, tmp)
  vim.fn.bufload(buf)
  dap_bp.set({}, buf, line)
  state.active_project_key = storage.project_key()
  return buf, tmp
end

describe("breakpoints.picker (telescope backend)", function()
  local test_dir

  before_each(function()
    test_dir = vim.fn.tempname() .. "_bp_telescope_test"
    vim.fn.mkdir(test_dir, "p")
    config.apply({ storage_dir = test_dir, picker = "telescope" })
    state.dirty = false
    state.setup_done = false
    state.dap_mutators_patched = false
    state.active_project_key = storage.project_key()
    dap_bp.clear()
    _G._test_picker_calls = {}
    _G._test_telescope_calls = {}
    _G._test_telescope_selected_entry = nil
  end)

  after_each(function()
    vim.fn.delete(test_dir, "rf")
  end)

  it("opens telescope with a finder over the collected items", function()
    local buf, tmp = make_bp(1)

    picker_mod.open()

    assert.equals(1, #_G._test_telescope_calls)
    assert.equals(0, #_G._test_picker_calls)
    local call = _G._test_telescope_calls[1]
    assert.equals("Breakpoints", call.opts.prompt_title)
    assert.equals(1, #call.opts.finder.results)
    assert.truthy(call.mappings.d)
    assert.truthy(call.mappings.c)
    assert.truthy(call.mappings.l)
    assert.truthy(call.mappings.h)
    assert.truthy(call.mappings.G)
    assert.truthy(call.mappings.s)
    assert.truthy(call.mappings.n)
    assert.is_true(call.found)

    vim.api.nvim_buf_delete(buf, { force = true })
    vim.fn.delete(tmp)
  end)

  it("entry_maker exposes filename/lnum for the previewer", function()
    local buf, tmp = make_bp(2)

    picker_mod.open()

    local call = _G._test_telescope_calls[1]
    local item = call.opts.finder.results[1]
    local entry = call.opts.finder.entry_maker(item)
    assert.equals(vim.fn.fnamemodify(tmp, ":p"), entry.filename)
    assert.equals(2, entry.lnum)
    assert.equals(item.label, entry.display)

    vim.api.nvim_buf_delete(buf, { force = true })
    vim.fn.delete(tmp)
  end)

  it("delete mapping removes the breakpoint via shared actions", function()
    local buf, tmp = make_bp(1)

    picker_mod.open()
    local call = _G._test_telescope_calls[1]
    local item = call.opts.finder.results[1]
    _G._test_telescope_selected_entry = call.opts.finder.entry_maker(item)

    call.mappings.d()

    assert.equals(0, #(dap_bp.get(buf)[buf] or {}))

    vim.api.nvim_buf_delete(buf, { force = true })
    vim.fn.delete(tmp)
  end)
end)

describe("breakpoints.picker (backend resolution)", function()
  local test_dir

  before_each(function()
    test_dir = vim.fn.tempname() .. "_bp_resolve_test"
    vim.fn.mkdir(test_dir, "p")
    state.dirty = false
    state.setup_done = false
    state.dap_mutators_patched = false
    state.active_project_key = nil
    dap_bp.clear()
    _G._test_picker_calls = {}
    _G._test_telescope_calls = {}
  end)

  after_each(function()
    vim.fn.delete(test_dir, "rf")
    config.apply({ storage_dir = test_dir, picker = "auto" })
  end)

  it("prefers picker.nvim over telescope when both are installed and picker is 'auto'", function()
    config.apply({ storage_dir = test_dir, picker = "auto" })
    local buf, tmp = make_bp(1)

    picker_mod.open()

    assert.equals(1, #_G._test_picker_calls)
    assert.equals(0, #_G._test_telescope_calls)

    vim.api.nvim_buf_delete(buf, { force = true })
    vim.fn.delete(tmp)
  end)

  it("falls back to telescope when picker.nvim is unavailable", function()
    config.apply({ storage_dir = test_dir, picker = "auto" })
    local saved_picker = package.loaded["picker"]
    package.loaded["picker"] = nil
    package.preload["picker"] = nil

    local buf, tmp = make_bp(1)
    picker_mod.open()

    assert.equals(1, #_G._test_telescope_calls)
    assert.equals(0, #_G._test_picker_calls)

    package.loaded["picker"] = saved_picker
    vim.api.nvim_buf_delete(buf, { force = true })
    vim.fn.delete(tmp)
  end)

  it("warns and does nothing when no picker is available", function()
    config.apply({ storage_dir = test_dir, picker = "auto" })
    local saved_picker = package.loaded["picker"]
    local saved_telescope = package.loaded["telescope"]
    package.loaded["picker"] = nil
    package.loaded["telescope"] = nil

    local notified = {}
    vim.notify = function(msg) notified[#notified + 1] = msg end

    local buf, tmp = make_bp(1)
    picker_mod.open()

    assert.equals(0, #_G._test_picker_calls)
    assert.equals(0, #_G._test_telescope_calls)
    assert.truthy(#notified > 0)
    assert.truthy(notified[#notified]:find("no supported picker"))

    package.loaded["picker"] = saved_picker
    package.loaded["telescope"] = saved_telescope
    vim.api.nvim_buf_delete(buf, { force = true })
    vim.fn.delete(tmp)
  end)

  it("errors when an explicit picker option names an uninstalled backend", function()
    config.apply({ storage_dir = test_dir, picker = "telescope" })
    local saved_telescope = package.loaded["telescope"]
    package.loaded["telescope"] = nil

    local notified = {}
    vim.notify = function(msg) notified[#notified + 1] = msg end

    local buf, tmp = make_bp(1)
    picker_mod.open()

    assert.truthy(#notified > 0)
    assert.truthy(notified[#notified]:find("not installed"))

    package.loaded["telescope"] = saved_telescope
    vim.api.nvim_buf_delete(buf, { force = true })
    vim.fn.delete(tmp)
  end)
end)
