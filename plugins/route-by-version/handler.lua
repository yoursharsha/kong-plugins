local hostname_type = require"kong.tools.utils".hostname_type
local req_get_headers = ngx.req.get_headers
local q = require "kong.plugins.route-by-version.inspect"
local v_utils = require "kong.plugins.route-by-version.version"

local pairs = pairs
local ipairs = ipairs
local lower = string.lower

local BasePlugin = require "kong.plugins.base_plugin"

local RouteByHeaderHandler = BasePlugin:extend()

local conf_cache = setmetatable({}, {__mod = "k"})

function RouteByHeaderHandler:new()
    RouteByHeaderHandler.super:new(self, "route-by-version")
end

local function update_balancer_address(target, type)
    local ba = ngx.ctx.balancer_address
    ba.host = target
    ba.type = type
end

local function apply_rules(conf)
    local headers = req_get_headers()
    local min_version = headers[conf.min_header]
    local max_version = headers[conf.max_header]

    if min_version == nil then min_version = 0 end
    if max_version == nil then max_version = 20000 end

    kong.log.debug("Request version range: " .. "[" .. min_version .. "," ..
                       max_version .. "]")

    local potential_target = conf.rules[v_utils.near(max_version, conf.rules)]

    if potential_target ~= nil and
        v_utils.compare_versions(min_version, potential_target.version) then
        if potential_target.upstream.path ~= nil then
            kong.log
                .debug("Found version in range " .. potential_target.version)
            ngx.var.upstream_uri = modifyPath(kong.request.get_path(),
                                              potential_target.upstream.path
                                                  .capture_regex,
                                              potential_target.upstream.path
                                                  .replace_regex)
        end
        if potential_target.upstream.host ~= nil then
            ngx.ctx.balancer_address.host = potential_target.upstream.host
        end
        if potential_target.upstream.port ~= nil then
            ngx.ctx.balancer_address.port = potential_target.upstream.port
        end
        if potential_target.upstream.scheme ~= nil then
            ngx.var.upstream_scheme = potential_target.upstream.scheme
        end
        kong.log.debug("Routing to: " .. ngx.var.upstream_scheme .. "://" ..
                           ngx.ctx.balancer_address.host .. ":" ..
                           ngx.ctx.balancer_address.port .. ngx.var.upstream_uri)
        kong.service.request.set_header("host", ngx.ctx.balancer_address.host) 
    else
        kong.log.err("No version in range. Using default endpoint ")
        kong.response.exit(conf.error_response.status_code,
                           {message = conf.error_response.message})
    end
end

function RouteByHeaderHandler:access(conf)
    RouteByHeaderHandler.super.access(self)
    apply_rules(conf)
end

function modifyPath(in_path, capture_regex, replace_regex)
    --- local before = "/something/ob/product"
    --- local after = "/something/api/serviceA/product"
    --- local capture_regex = "(%a*)/ob/(%a*)"
    --- local replace_regex = "%1/api/serviceA/%2"
    local out_path = string.gsub(in_path, capture_regex, replace_regex)
    kong.log.debug("Re-wrote the path from : " .. in_path .. out_path)
    return out_path

end

RouteByHeaderHandler.priority = 2000
RouteByHeaderHandler.version = "0.1.0"

return RouteByHeaderHandler
