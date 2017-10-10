local _M = {}

local setmetatable = setmetatable
local insert = table.insert
local assert = assert
local pl = { dir = require('pl.dir'), path = require('pl.path'), file = require('pl.file') }
local Liquid = require 'liquid'

local Lexer = Liquid.Lexer
local Parser = Liquid.Parser
local Interpreter = Liquid.Interpreter
local FilterSet = Liquid.FilterSet
local InterpreterContext = Liquid.InterpreterContext
local FileSystem = Liquid.FileSystem
local ResourceLimit = Liquid.ResourceLimit

local function noop(...) return ... end

function _M:new(config, dir, strict)
    local instance = setmetatable({}, { __index = self })
    local context = setmetatable({}, { __index = config })

    instance.root = pl.path.abspath(dir or pl.path.currentdir())
    instance.context = InterpreterContext:new(context)
    instance.strict = strict
    instance.filesystem = FileSystem:new(function(path)
        return instance:read(path)
    end)

    return instance
end

function _M:read(template_name)
    local root = self.root
    local check = self.strict and assert or noop

    return check(pl.file.read(pl.path.join(root, template_name)))
end

function _M:render(template_name)
    local template = self:read(template_name)
    return self:interpret(template)
end

function _M:interpret(str)
    local lexer = Lexer:new(str)
    local parser = Parser:new(lexer)
    local interpreter = Interpreter:new(parser)
    local context = self.context
    local filesystem = self.filesystem
    local filter_set = FilterSet:new()
    local resource_limit = ResourceLimit:new(nil, 1000, nil)

    filter_set:add_filter('filesystem', function(pattern)
        local files = {}

        for filename, dir in pl.dir.dirtree(self.root) do
            local file = pl.path.relpath(filename, self.root)
            if pl.dir.fnmatch(file, pattern) and not dir then
                insert(files, file)
            end
        end

        return files
    end)

    filter_set:add_filter('default', function(value, default)
        return value or default
    end)

    return interpreter:interpret(context, filter_set, resource_limit, filesystem)
end

return _M
