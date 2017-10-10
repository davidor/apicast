local pl_path = require('pl.path')
local setmetatable = setmetatable
local loadfile = loadfile
local pcall = pcall
local require = require
local assert = assert
local error = error
local print = print

local _M = {
    default_environment = 'production',
    default_config = {
    }
}

local mt = { __index = _M }

function _M.new(root)
    return setmetatable({ root = root }, mt)
end

function _M:load(env)
    local environment = env or self.default_environment
    local root = self.root
    local name = ("%s.lua"):format(environment)
    local path = pl_path.join(root, 'config', name)

    print('loading config for: ', environment, ' environment from ', path)

    local config = loadfile(path, 't', {
        print = print, inspect = require('inspect'),
        pcall = pcall, require = require, assert = assert, error = error,
    })

    local default_config = {}

    if not config then
        return default_config, 'invalid config'
    end

    return config()
end

return _M
