-- [TODO]: extract method, Generate Class in c++, generate member function from header file in c++, ...
-- [TODO]: show separate tab in failed build.
-- [TODO]: list of classes(current file/workspace) >> tree-sitter
-- [TODO]: list of functions(current file/workspace) >> tree-sitter
-- [TODO]: list of variables(current area/function/class/file/workspace) >> tree-sitter

local project = {}

local Menu = require("nui.menu")
local event = require("nui.utils.autocmd").event

local items
local has_error = false
local spinner_frames = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" }

local app_name = "myserver"
local project_file = "project.txt"

local debug="debug"
local release="release"

local arch_type_x86="x86"
local arch_type_x64="x64"

local notif_done
local notif_in_progress
local notify_timeout = 500
local notification_data = {}

function project.show_context_menu()
	local choices = { "Rename", "Extract Variable", "Extract Method" }
	require"contextmenu".open(choices, {
		callback = function(chosen)
			print("Final choice " .. choices[chosen])
		end })
end

local function setup_keys()
  if items[2] == debug then
    vim.api.nvim_set_keymap('n', '<F5>', ':lua require\'dap\'.continue()<CR>', {noremap = true})
  else
    vim.api.nvim_set_keymap('n', '<F5>', ':lua require("project").run()<CR>', {noremap = true})
  end
  vim.api.nvim_set_keymap('n', '<A-o>', ':ClangdSwitchSourceHeader<CR>', {noremap = true})
  vim.api.nvim_set_keymap('n', '<C-b>', ':lua require("project").build()<CR>', {noremap = true, silent=true})
  vim.api.nvim_set_keymap('n', '<C-e>', ':lua require("project").clean()<CR>', {noremap = true})
  vim.api.nvim_set_keymap('n', '<F13>', ':lua require("project").show_context_menu()<CR>', {noremap = true, silent=true})
  vim.api.nvim_set_keymap('v', '<F13>', ':lua require("project").show_context_menu()<CR>', {noremap = true, silent=true})
end

local function setup_dap()
  require("user.plugins.m_dap").setup.c("lldb", string.format("${workspaceFolder}/output/%s/%s/%s", items[1], items[2], app_name))
end

function project.extract_variable()
  vim.cmd[[
    let var = input('variable name: ')
    execute "normal! \<S-^>iauto ".var." = "
  ]]
end

function project.extract_method()
  vim.cmd [[
    let name  = inputdialog("Name of new method:")
    let rType = inputdialog("Enter Return Type:")
    let line  = inputdialog("Line to put function:")
    "     exe "normal! :".line."\<CR>"
    execute "normal! ma"
    '<
    exe "normal! O\<BS>".rType." ".name."()\<CR>{\<Esc>"
    '>
    exe "normal! oreturn ;\<CR>}\<Esc>k"
    s/return/\/\/ return/ge
    normal! j%
    normal! kf(
    "     exe "normal! yyPi// = \<Esc>wdwA;\<Esc>"
    normal! ==
    normal! j0w
    exe "normal! 'a3k0v9j\<S-$>d :".line."\<CR>p"
  ]]
end

function project.show_cmake_doc()
  vim.cmd[[
    let l:category = input('Enter category: ')
    call FTerminal("cmake --help ". l:category ." | less && exit \n")
  ]]
end

function project.show_function_doc()
  --require('ui.input').show("man ", "Please enter function name", "")
  -- show popup
end

function project.show_function_doc_cword()
  require('ui.popup').show("man " .. vim.call('expand','<cword>'))
end

local function on_menu_item_selected(item, new_title, index)
  local file = io.open(project_file, 'r')
  local content = {}
  for line in file:lines() do
      table.insert (content, line)
  end
  io.close(file)

  content[index] = item.text

  file = io.open(project_file, 'w')
  for index, value in ipairs(content) do
      file:write(value..'\n')
  end
  io.close(file)

  local notification_title =  string.format("%s selected", item.text)

  require("notify").notify(notification_title, "INFO",
    { title = new_title, timeout = notif_done })
end

function project.select_type(new_title, types, index)
  local new_lines = {}
  for i, my_type in ipairs(types) do
    new_lines[i] = Menu.item(my_type)
  end

  local menu = Menu({
    position = { row = "5%", col = "50%" },
    size = { width = 40, height = 2 },
    relative = "editor",
    border = {
      highlight = "MyHighlightGroup",
      style = "single",
      text = {
        top = new_title,
        top_align = "center",
      },
    },
    win_options = { winblend = 10, winhighlight = "Normal:Normal" },
  },
  {
    lines = new_lines,
    max_width = 20,
    keymap = {
      focus_next  = { "j", "<Down>", "<Tab>" },
      focus_prev  = { "k", "<Up>", "<S-Tab>" },
      close       = { "<Esc>", "<C-c>" },
      submit      = { "<CR>", "<Space>" },
    },
    on_submit = function(item)
      on_menu_item_selected(item, new_title, index)
    end,
  })

  menu:mount()
  menu:on(event.BufLeave, menu.menu_props.on_close, { once = true })
end

local function update_spinner(notification_data, title)
   local new_spinner = (notification_data.spinner + 1) % #spinner_frames
   notification_data.spinner = new_spinner

   notification_data.notification = require("notify").notify(title, nil, {
     hide_from_history = true,
     icon = spinner_frames[new_spinner],
     replace = notification_data.notification,
   })

   vim.defer_fn(function()
     update_spinner(notification_data, nil)
   end, 100)
end

local function on_event(job_id, data, event)
  local lines = {""}
  if event == "stderr" then
    local error_lines = ""
    vim.list_extend(lines, data)

    for i=1, #lines
    do
      error_lines = error_lines .. "\n" .. lines[i]
    end

    if(lines[3] ~= nil) then
      vim.b._cexpr_lines = error_lines
      vim.cmd [[ :cexpr b:_cexpr_lines ]]
      vim.cmd [[ :copen ]]
      has_error = true

      require("notify").dismiss(true)

      require("notify").notify("Something went wrong!", "ERROR",
        { title = notif_done, timeout = notify_timeout })
    end
  end
  if event == "exit" then
    if data then
      if(not has_error) then
        update_spinner(notification_data, "SUCCESS")

        require("notify").dismiss()

        local successfull_message =  string.format("%s was successful :)", notif_done)
        require("notify").notify(successfull_message, "INFO",
          { title = notif_done, timeout = notify_timeout })
        vim.cmd(':source $MYVIMRC')
      end
    end
    has_error = false
  end
end

function project.async_task(command)
  notification_data.notification = require("notify").notify(notif_in_progress, "info", {
    title = "",
    icon = spinner_frames[1],
    timeout = false,
    hide_from_history = false,
  })

  notification_data.spinner = 1
  update_spinner(notification_data, nil)

  vim.fn.jobstart(command,
    { on_stderr = on_event,
      on_stdout = on_event,
      on_exit = on_event,
      stdout_buffered = true,
      stderr_buffered = true,
    })
end

function project.build()
  notif_done = "Build"
  notif_in_progress = "Building..."

  local cmd_cmake = nil
  local cmd_cd = "cd output/cmake"

  if items[1] == arch_type_x86 then
    if items[2] == debug then
      cmd_cmake = string.format("%s; cmake %s -DCMAKE_BUILD_TYPE=%s ../..", cmd_cd, "-DCMAKE_CXX_FLAGS=-m32", "DEBUG")
    elseif items[2] == release then
      cmd_cmake = string.format("%s; cmake %s -DCMAKE_BUILD_TYPE=%s ../..", cmd_cd, "-DCMAKE_CXX_FLAGS=-m32", "RELEASE")
    end
  elseif items[1] == arch_type_x64 then
    if items[2] == debug then
      cmd_cmake = string.format("%s; cmake %s -DCMAKE_BUILD_TYPE=%s ../..", cmd_cd, "", "DEBUG")
    elseif items[2] == release then
      cmd_cmake = string.format("%s; cmake %s -DCMAKE_BUILD_TYPE=%s ../..", cmd_cd, "", "RELEASE")
    end
  end

  vim.cmd(string.format(":lua require('project').async_task(\"%s\")",
          string.format("%s; %s; %s; %s", "rm -rf compile_commands.json", cmd_cmake, "make -j8", "cd ../..; ln -s output/cmake/compile_commands.json .")))
end

function project.run()
  vim.cmd(string.format(":call HTerminal(0.4, 200, \"./output/%s/%s/%s\")", items[1], items[2], app_name))
end

function project.clean()
  notif_done = "Clean"
  notif_in_progress = "Cleaning..."

  vim.cmd(string.format(":silent; lua require('project').async_task(\"%s\")",
    string.format("rm -rf ./output/cmake/* compile_commands.json ./output/%s/%s/*;", items[1], items[2])))
end

items = require("user.util.file").read_file_and_return_lines_as_table(project_file);
setup_keys()
setup_dap()

table.insert(require('command_palette').CpMenu,
  {"project",
    { 'extract variable', ":lua require('project').extract_variable()" },
    { 'extract method', ":lua require('project').extract_method()" },
    { "cmake doc", ":lua require('project').show_cmake_doc()" },
    { "function doc", ":lua require('project').show_function_doc()" },
    { "function doc <cword>", ":lua require('project').show_function_doc_cword()" },
    { 'set arch type', ":lua require('project').select_type('Architecture', { 'x86', 'x64' }, 1)" },
    { 'set build type', ":lua require('project').select_type('BuildType', { 'debug', 'release' }, 2)" },
    { 'switch header/source (A-o)', ":ClangdSwitchSourceHeader" },
    { 'clean (C-e)', ":lua require('project').clean()" },
    { 'run (F5)', ":lua require('project').run()" },
    { 'build (C-b)', ":lua require('project').build()" },
  })

return project