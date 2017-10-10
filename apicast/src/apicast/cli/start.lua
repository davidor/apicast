local setmetatable = setmetatable
local pairs = pairs

local exec = require('rover.exec')
local rover_env = require('rover.env')

local colors = require('ansicolors')
local Template = require('apicast.template')
local configuration = require('apicast.configuration')

local pl = {
    path = require('pl.path'),
    file = require('pl.file'),
}

local _M = {
    openresty = { 'openresty-debug', 'openresty', 'nginx' },
    log_levels = { 'emerg', 'alert', 'crit', 'error', 'warn', 'notice', 'info', 'debug' },
    log_level = 5, -- warn
    log_file = 'stderr',
}

local mt = { __index = _M }

local function pick_openesty(candidates)
    for i=1, #candidates do
        local ok = os.execute(('%s -V 2>/dev/null'):format(candidates[i]))

        if ok then
            return candidates[i]
        end
    end

    error("could not find openresty executable")
end

local function nginx_config(context, dir, path)
    local template = Template:new(context, dir, true)
    local tmp = pl.path.tmpname()
    pl.file.write(tmp, template:render(path))
    return tmp
end

function mt:__call(options)
    local openresty = pick_openesty(self.openresty)
    local dir = pl.path.abspath('apicast')
    local config = configuration.new(dir)
    local path = options.template
    local environment = options.dev and 'development' or options.environment
    local context = config:load(environment)
    local env = {}

    for name, value in pairs(rover_env) do
        env[name] = value
    end

    env.APICAST_CONFIGURATION = options.configuration
    env.APICAST_CONFIGURATION_LOADER = options.boot and 'boot' or 'lazy'
    env.APICAST_CONFIGURATION_CACHE = options.cache
    env.THREESCALE_DEPLOYMENT_ENV = environment

    context.worker_processes = options.workers or context.worker_processes

    if options.daemon then
        context.daemon = 'on'
    end

    context.prefix = dir

    local nginx = nginx_config(context, dir, path)

    local log_level = self.log_levels[self.log_level + options.verbose - options.quiet]
    local log_file = options.log or self.log_file
    local global = {
        ('error_log %s %s'):format(log_file, log_level)
    }

    local cmd = { '-c', nginx, '-g', table.concat(global, '; ') .. ';' }

    if options.test then
        table.insert(cmd, options.debug and '-T' or '-t')
    end

    return exec(openresty, cmd, env)
end

function _M:new(parser)
    local cmd = parser:command('start', 'Start APIcast')

    cmd:usage(colors("%{bright red}Usage: apicast-cli start [OPTIONS]"))
    cmd:option("--template", "Nginx config template.", 'nginx/main.conf.liquid')

    cmd:mutex(
        cmd:option('-e --environment', "Deployment to start.", 'production'),
        cmd:flag('--dev', 'Start in development environment')
    )

    cmd:flag("-t --test", "Test the nginx config")
    cmd:flag("--debug", "Debug mode. Prints more information.")
    cmd:option("-c --configuration", "Path to custom config file (JSON)")
    cmd:flag("-d --daemon", "Daemonize.")
    cmd:option("-w --workers", "Number of worker processes to start.")
    cmd:option("-p --pid", "Path to the PID file.")
    cmd:mutex(
        cmd:flag('-b --boot', "Load configuration on boot."),
        cmd:flag('-l --lazy', "Load configuration on demand.")
    )
    cmd:option("-i --refresh-interval", "Cache configuration for N seconds. Using 0 will reload on every request (not for production).")
    cmd:flag('-v --verbose', "Increase logging verbosity (can be repeated)."):count(("0-%s"):format(#(self.log_levels) - self.log_level))
    cmd:flag('-q --quiet', "Decrease logging verbosity."):count(("0-%s"):format(self.log_level - 1))

    cmd:epilog(colors([[
      Example: %{bright red} apicast start --dev %{reset}
        This will start APIcast in development mode.]]))

    return setmetatable({ parser = parser, cmd = cmd }, mt)
end


return setmetatable(_M, mt)
