local typedefs = require "kong.db.schema.typedefs"

--[[
  config schema
  "config": {
    "rules": [
      {
        "upstream_name": "json.domian.com",
        "condition": {
          "header1": "value2",
          "header2": "some_value"
        }
      },
      {
        "upstream_name": "foo.domian.com",
        "condition": {
          "header1": "some_value",
          "header2": "some_value",
          "header3": "some_value"
        }
      }
    ]
  },
]]

local default_capture_regex = "(/)(.*)"
local default_replace_regex = "/%2"

local rule = {
    type = "record",
    fields = {
        {version = {type = "string", required = true}}, {
            upstream = {
                type = "record",
                required = true,
                fields = {
                    {host = {type = "string"}}, {port = {type = "string"}},
                    {scheme = {type = "string"}}, {
                        path = {
                            type = "record",
                            fields = {
                                {
                                    capture_regex = {
                                        type = "string",
                                        default = default_capture_regex
                                    }
                                },
                                {
                                    replace_regex = {
                                        type = "string",
                                        default = default_replace_regex
                                    }
                                }
                            },
                            default = {
                                capture_regex = default_capture_regex,
                                replace_regex = default_replace_regex
                            }
                        }
                    }
                }
            }
        }
    }
}

return {
    name = "route-by-version",
    fields = {
        {run_on = typedefs.run_on_first}, {
            config = {
                type = "record",
                fields = {
                    {rules = {type = "array", default = {}, elements = rule}},
                    {min_header = {type = "string", default = "min"}},
                    {max_header = {type = "string", default = "max"}}, {
                        error_response = {
                            type = "record",
                            fields = {
                                {status_code = {type = "number", default = 412}},
                                {
                                    message = {
                                        type = "string",
                                        default = "Version precondition failed"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
