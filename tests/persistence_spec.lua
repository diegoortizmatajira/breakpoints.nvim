-- persistence_spec.lua: Tests for breakpoints.persistence module
local persistence = require("breakpoints.persistence")
local storage = require("breakpoints.storage")
local config = require("breakpoints.config")
local state = require("breakpoints.state")

describe("breakpoints.persistence", function()
  local test_dir
  local dap_bp = _G._test_dap_breakpoints

  before_each(function()
    test_dir = vim.fn.tempname() .. "_bp_persist_test"
    vim.fn.mkdir(test_dir, "p")
    config.apply({ storage_dir = test_dir })
    state.dirty = false
    state.active_project_key = storage.project_key()
    state.last_loaded_notice_key = nil
    dap_bp.clear()
  end)

  after_each(function()
    vim.fn.delete(test_dir, "rf")
  end)

  describe("iter_breakpoints", function()
    it("calls callback for flat list entries", function()
      local results = {}
      persistence.iter_breakpoints(
        { { line = 1 }, { line = 5 }, { line = 10 } },
        function(bp) results[#results + 1] = bp.line end
      )
      assert.same({ 1, 5, 10 }, results)
    end)

    it("calls callback for nested entries", function()
      local results = {}
      persistence.iter_breakpoints(
        { { { line = 3 } }, { line = 7 } },
        function(bp) results[#results + 1] = bp.line end
      )
      assert.same({ 3, 7 }, results)
    end)

    it("handles single bp object", function()
      local results = {}
      persistence.iter_breakpoints(
        { line = 42 },
        function(bp) results[#results + 1] = bp.line end
      )
      assert.same({ 42 }, results)
    end)

    it("limits recursion depth", function()
      local deep = { { { { { { line = 99 } } } } } }
      local results = {}
      persistence.iter_breakpoints(deep, function(bp) results[#results + 1] = bp.line end)
      assert.same({ 99 }, results)
    end)

    it("ignores non-table input", function()
      local results = {}
      persistence.iter_breakpoints(nil, function(bp) results[#results + 1] = bp end)
      persistence.iter_breakpoints("string", function(bp) results[#results + 1] = bp end)
      assert.same({}, results)
    end)
  end)

  describe("mark_dirty", function()
    it("sets state.dirty to true", function()
      assert.is_false(state.dirty)
      persistence.mark_dirty()
      assert.is_true(state.dirty)
    end)
  end)

  describe("save", function()
    it("does nothing when not dirty and not forced", function()
      local key = storage.project_key()
      persistence.save()
      assert.equals(0, vim.fn.filereadable(storage.bp_path(key)))
    end)

    it("saves when forced even if not dirty", function()
      local buf = vim.api.nvim_create_buf(true, false)
      local tmp = vim.fn.tempname() .. ".lua"
      vim.fn.writefile({ "line1" }, tmp)
      vim.api.nvim_buf_set_name(buf, tmp)
      vim.fn.bufload(buf)

      dap_bp.set({}, buf, 1)
      state.active_project_key = storage.project_key()
      persistence.save({ force = true })

      assert.equals(1, vim.fn.filereadable(storage.bp_path()))
      local content = vim.fn.readfile(storage.bp_path())[1]
      local data = vim.json.decode(content)
      assert.truthy(data[vim.fn.fnamemodify(tmp, ":p")])

      vim.api.nvim_buf_delete(buf, { force = true })
      vim.fn.delete(tmp)
    end)

    it("removes json file when no breakpoints remain", function()
      local key = storage.project_key()
      local file = io.open(storage.bp_path(key), "w")
      file:write("{}"); file:close()
      persistence.mark_dirty()
      persistence.save()
      assert.equals(0, vim.fn.filereadable(storage.bp_path(key)))
    end)

    it("cleans orphan meta entries", function()
      local key = storage.project_key()
      state.active_project_key = key
      storage.save_meta({ ["/gone.lua:1"] = "OldGroup" }, key)
      persistence.mark_dirty()
      persistence.save()
      local meta = storage.load_meta(key)
      assert.is_nil(meta["/gone.lua:1"])
    end)
  end)

  describe("load", function()
    it("clears breakpoints when file missing", function()
      local buf = vim.api.nvim_create_buf(true, false)
      dap_bp.set({}, buf, 1)
      persistence.load()
      local all = dap_bp.get()
      local count = 0
      for _ in pairs(all) do count = count + 1 end
      assert.equals(0, count)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("loads breakpoints from json file", function()
      local tmp = vim.fn.tempname() .. ".lua"
      vim.fn.writefile({ "line1", "line2", "line3" }, tmp)
      local abs = vim.fn.fnamemodify(tmp, ":p")

      local key = storage.project_key()
      local data = { [abs] = { { line = 2, condition = "x > 0" } } }
      local file = io.open(storage.bp_path(key), "w")
      file:write(vim.json.encode(data))
      file:close()

      persistence.load({ key = key })

      local bufnr = vim.fn.bufnr(abs)
      assert.truthy(bufnr > 0)
      local loaded = dap_bp.get()
      local found = false
      for _, list in pairs(loaded) do
        for _, bp in ipairs(list) do
          if bp.line == 2 then found = true end
        end
      end
      assert.is_true(found)

      vim.fn.delete(tmp)
    end)

    it("handles corrupted json gracefully", function()
      local key = storage.project_key()
      local file = io.open(storage.bp_path(key), "w")
      file:write("not valid json{{{")
      file:close()

      local notified = {}
      vim.notify = function(msg) notified[#notified + 1] = msg end
      persistence.load({ key = key })
      assert.truthy(#notified > 0)
      assert.truthy(notified[1]:find("Failed decoding"))
    end)

    it("sets active_project_key after load", function()
      state.active_project_key = nil
      persistence.load()
      assert.equals(storage.project_key(), state.active_project_key)
    end)
  end)
end)
