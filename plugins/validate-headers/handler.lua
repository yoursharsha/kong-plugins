local BasePlugin = require "kong.plugins.base_plugin"
local req_get_headers = ngx.req.get_headers
local ValidateHeaders = BasePlugin:extend()


  function ValidateHeaders:new() ValidateHeaders.super.new(self, "validate-headers") end
  function pattern_match(string, pattern)
    if not string then
       return false
    end 
    local string = string:match(pattern)
    if string then
      return true
    else
      return false
    end
  end

  function ValidateHeaders:access(config)
    ValidateHeaders.super.access(self)
    local incomingHeaders = req_get_headers()
    kong.log.debug("Validating Mandatory Headers and Header format ")
    for i, name in pairs(config.headerList) do
      local headerValue = incomingHeaders[name["headerName"]]
      if ( headerValue == nil and name["mandatory"] ) or ( name["pattern"] and not pattern_match(headerValue, name["pattern"]) )  then
        local errmessage = config.error_response.message .. " :" .. name["headerName"]
        kong.log.err("Header Validation failed " .. config.error_response.status_code .. " " .. errmessage)
        kong.response.exit(config.error_response.status_code,
        {message = errmessage})
      end
    end
  end
  ValidateHeaders.VERSION = "1.0.0"
  ValidateHeaders.PRIORITY = 11
  return ValidateHeaders
