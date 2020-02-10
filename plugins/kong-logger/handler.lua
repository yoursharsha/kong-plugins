local cjson = require "cjson.safe"
local BasePlugin = require "kong.plugins.base_plugin"
local q = require "kong.plugins.kong-logger.inspect"
local basic_serializer = require "kong.plugins.kong-logger.basic"
local cjson = require "cjson"
local json = require "kong.plugins.kong-logger.libcjson"
local KongLoggerHandler = BasePlugin:extend()

local response = kong.response
local request = kong.request
local lower = string.lower
local find = string.find
local log = kong.log

local JSON_TYPE = "application/json"

local function try(f, catch_f)
    local status, exception = pcall(f)
    if not status then
        catch_f(exception)
    else
        return exception
    end
end

local function catch_f(exception)
    kong.log.debug("Suppressed exception - " .. q(exception))
end

local function serialize_log_data(ngx)
    return cjson.encode(basic_serializer.serialize(ngx))
end

local function calc_payload(raw_payload, content_type)
    if raw_payload == nil or #raw_payload == 0 then return "(nil)" end

    local content_type_lower = lower(content_type)

    if find(content_type_lower, JSON_TYPE, nil, true) then

        cjson.decode_array_with_array_mt(true)
        local decoded_payload, err = cjson.decode(raw_payload)
        cjson.decode_array_with_array_mt(false)

        if err then return "(payload encoded, or invalid)" end
        return decoded_payload
    end

    return raw_payload
end

function KongLoggerHandler:new() KongLoggerHandler.super
    .new(self, "kong-logger") end

function KongLoggerHandler:access(conf)
    KongLoggerHandler.super.access(self)

    local ctx = kong.ctx.plugin
    ctx.request_data = {}
    ctx.response_data = {}
    
    local req = {}
    req['headers_incoming'] = try(kong.request.get_headers, catch_f)

    req['path'] = request.get_path()
    req['port'] = request.get_port()
    req['scheme'] = request.get_scheme()
    req['method'] = request.get_method()
    req['headers'] = request.get_headers()
    req['http-version'] = request.get_http_version()

    if conf.request.payload == true then
        req['payload'] = request.get_raw_body()
    end

    ctx.request_data = req
    ctx.response_payload = ""
end

function KongLoggerHandler:body_filter(conf)
    KongLoggerHandler.super.body_filter(self)

    if conf.response.payload == true then
        local ctx = kong.ctx.plugin
        local chunk = ngx.arg[1]
        local payload = (ctx.response_payload or "") .. (chunk or "")
        ctx.response_payload = payload
    end

end

function KongLoggerHandler:rewrite(conf)
    KongLoggerHandler.super.rewrite(self)
    kong.ctx.plugin.request_data = {}
    kong.ctx.plugin.response_data = {}
    kong.ctx.plugin.request_data['headers_incoming'] =
        try(kong.request.get_headers, catch_f)

end

function KongLoggerHandler:header_filter(conf)
    KongLoggerHandler.super.header_filter(self)

    kong.ctx.plugin.request_data['headers_outgoing'] =
        try(kong.request.get_headers, catch_f)
    kong.ctx.plugin.response_data['headers_incoming'] =
        try(kong.response.get_headers, catch_f)
end

function KongLoggerHandler:log(conf)
    KongLoggerHandler.super.log(self)

    kong.ctx.plugin.response_data['headers_outgoing'] =
        try(kong.response.get_headers, catch_f)
    -- local log_data = serialize_log_data(ngx)
    local log_data = basic_serializer.serialize(ngx)

    local ctx = kong.ctx.plugin
    local tx = {
        request = ctx.request_data,
        response = {headers = response.get_headers()}
    }

    if conf.request.payload == true then
        log_data['request_payload'] = calc_payload(ctx.request_data.payload,
                                                   tx.request.headers['content-type'])
    end

    if conf.response.payload == true then
        log_data['response_payload'] = calc_payload(ctx.response_payload,
                                                    tx.response.headers['content-type'])
    end

    local jsonLog = json.encode(log_data)
    if conf.maskRules then
        for i, rule in pairs(conf.maskRules) do
            kong.log.debug('Mask Rule: '..rule["pattern"]..' Mask Replace: '..rule["replace"])
            jsonLog = string.gsub(jsonLog, rule["pattern"], rule["replace"])
            kong.log.debug(jsonlog)
        end
    end
    kong.log.info("[Request lifecycle log]" .. jsonLog)
end

KongLoggerHandler.PRIORITY = 1001
return KongLoggerHandler
