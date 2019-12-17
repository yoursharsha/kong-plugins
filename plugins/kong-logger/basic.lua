local tablex = require "pl.tablex"
local q = require "kong.plugins.kong-logger.inspect"
local _M = {}
local EMPTY = tablex.readonly({})

function try(f, catch_f)
    local status, exception = pcall(f)
    if not status then
        catch_f(exception)
    else
        return exception
    end
end

function catch_f(exception)
    kong.log.debug("Suppressed exception - " .. q(exception))
end

function _M.serialize(ngx, resp_headers)
    -- Handles Nil Users
    local ConsumerUsername
    if ngx.ctx.authenticated_consumer ~= nil then
        ConsumerUsername = ngx.ctx.authenticated_consumer.username
    end

    local PathOnly
    if ngx.var.request_uri ~= nil then
        PathOnly = string.gsub(ngx.var.request_uri, "%?.*", "")
    end

    local UpstreamPathOnly
    if ngx.var.upstream_uri ~= nil then
        UpstreamPathOnly = string.gsub(ngx.var.upstream_uri, "%?.*", "")
    end

    local RouteUrl
    if ngx.ctx.balancer_data ~= nil then
        RouteUrl = ngx.ctx.balancer_data.host .. ":" ..
                       ngx.ctx.balancer_data.port .. UpstreamPathOnly
    end

    local serviceName
    -- Service Resource (Kong >= 0.13.0)
    if ngx.ctx.service ~= nil then serviceName = ngx.ctx.service.name end

    local ret = {
        source = ngx.var.hostname,
        sourcetype = "AccessLog",
        time = ngx.time(),
        event = {
            HTTPMethod = ngx.req.get_method(),
            RequestSize = ngx.var.request_length,
            RoutingURL = RouteUrl,
            HTTPStatus = ngx.status,
            ErrorMsg = kong.ctx.shared.errmsg,
            GatewayHost = ngx.var.host,
            Tries = (ngx.ctx.balancer_data or EMPTY).tries, -- contains the list of (re)tries (successes and failures) made by the load balancer for this request
            ResponseSize = ngx.var.bytes_sent,
            BackendLatency = ngx.ctx.KONG_WAITING_TIME or -1, -- is the time it took for the final service to process the request
            TotalLatency = ngx.var.request_time * 1000, --  is the time elapsed between the first bytes were read from the client and after the last bytes were sent to the client. Useful for detecting slow clients
            KongLatency = {
                AccessTime = (ngx.ctx.KONG_ACCESS_TIME or 0), -- Access phase, majority of Kong plugins
                ReceiveTime = (ngx.ctx.KONG_RECEIVE_TIME or 0), -- Time it took before Kong had fully recieved all headers and response body from backend
                RewriteTime = (ngx.ctx.KONG_REWRITE_TIME or 0), -- Rewrite phase (between Kong has response and time spent before returning it to client)
                BalancerTime = (ngx.ctx.KONG_BALANCER_TIME or 0) -- Balancer time, DNS or upstream/target logic Kong hot paths here
            },
            ClientIP = ngx.var.remote_addr,
            URI = PathOnly,
            ServiceName = serviceName,
            Request_headers_incoming = kong.ctx.plugin.request_data
                .headers_incoming,
            Request_headers_outgoing = kong.ctx.plugin.request_data
                .headers_outgoing,
            Response_headers_incoming = kong.ctx.plugin.response_data
                .headers_incoming,
            Response_headers_outgoing = kong.ctx.plugin.response_data
                .headers_outgoing,
            Request_method = try(kong.request.get_method, catch_f)
        }
    }

    return ret
end

return _M
