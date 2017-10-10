local parser = require('argparse')() {
    name = "APIcast",
    description = "APIcast - 3scale API Management Platform Gateway."
}
local command_target = '_cmd'
parser:command_target(command_target)

local _M = { }

local mt = {}

local function load_commands(commands, argparse)
    for i=1, #commands do
        commands[commands[i]] = require('apicast.cli.' .. commands[i]):new(argparse)
    end
    return commands
end

_M.commands = load_commands({ 'start' }, parser)

function mt.__call(self, arg)
    -- now we parse the options like usual:
    local ok, ret = self.parse(arg)
    local cmd = ok and ret[command_target]

    if ok and cmd then
        self.commands[cmd](ret)
    elseif ok then
        self.commands.install(ret)
    else
        print(ret)
        os.exit(1)
    end
end

function _M.parse(arg)
    return parser:pparse(arg)
end

return setmetatable(_M, mt)
