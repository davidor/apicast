local configuration = require 'configuration'
local env = require 'resty.env'

describe('Configuration object', function()

  describe('provides information from the config file', function()
    local config = configuration.new({services = { 'a' }})

    it('returns services', function()
      assert.truthy(config.services)
      assert.equals(1, #config.services)
    end)
  end)

  describe('.parse_service', function()
    it('ignores empty hostname_rewrite', function()
      local config = configuration.parse_service({ proxy = { hostname_rewrite = '' }})

      assert.same(false, config.hostname_rewrite)
    end)

    it('populates hostname_rewrite', function()
      local config = configuration.parse_service({ proxy = { hostname_rewrite = 'example.com' }})

      assert.same('example.com', config.hostname_rewrite)
    end)

    it('overrides backend endpoint from ENV', function()
      env.set('BACKEND_ENDPOINT_OVERRIDE', 'https://backend.example.com')

      local config = configuration.parse_service({ proxy = {
        backend = { endpoint = 'http://example.com', host = 'foo.example.com' }
      }})

      assert.same('https://backend.example.com', config.backend.endpoint)
      assert.same('backend.example.com', config.backend.host)
    end)
  end)

  describe('.filter_services', function()
    local filter_services = configuration.filter_services

    it('works with nil', function()
      local services = { { id = '42' } }
      assert.equal(services, filter_services(services))
    end)

    it('works with table with ids', function()
      local services = { { id = '42' } }

      assert.same(services, filter_services(services, { '42' }))
      assert.same({}, filter_services(services, { '21' }))
    end)
  end)

  insulate('.services_limit', function()
    local services_limit = configuration.services_limit

    it('reads from environment', function()
      env.set('APICAST_SERVICES', '42,21')

      local services = services_limit()

      assert.same({ ['42'] = true, ['21'] = true }, services)
    end)

    it('reads from environment', function()
      env.set('APICAST_SERVICES', '')

      local services = services_limit()

      assert.same({}, services)
    end)
  end)

  describe('.get_rewrite_url', function()
    local get_rewrite_url = configuration.get_rewrite_url

    it('fills in wildcard values', function()
      local rule = { redirect_url = 'http://foo.bar/api/collection/{id}/item/{code}'}
      local params = { id = 'one', code = 'two' }
      ngx.var = { args = nil }
      assert.equal('http://foo.bar/api/collection/one/item/two', get_rewrite_url(rule, params))
    end)

    it('merges the query parameters when rewrite_url has query parameters', function()
      local rule = { redirect_url = 'http://foo.bar/api/collection/id?q=query'}
      local params = {}
      ngx.var = { args = 'param1=value1&param2=value2' }
      assert.equal('http://foo.bar/api/collection/id?q=query&param1=value1&param2=value2', get_rewrite_url(rule, params))
    end)

    it('merges the query parameters when rewrite_url has no query parameters', function()
      local rule = { redirect_url = 'http://foo.bar/api/collection/id'}
      local params = {}
      ngx.var = { args = 'param1=value1&param2=value2' }
      assert.equal('http://foo.bar/api/collection/id?param1=value1&param2=value2', get_rewrite_url(rule, params))
    end)

    it('merges the query parameters when there are no params in the request', function()
      local rule = { redirect_url = 'http://foo.bar/api/collection/id?q=query'}
      local params = {}
      ngx.var = { args = nil }
      assert.equal('http://foo.bar/api/collection/id?q=query', get_rewrite_url(rule, params))
    end)
  end)

end)
