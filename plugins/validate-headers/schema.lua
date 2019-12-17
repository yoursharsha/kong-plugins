return {
  name = "validate-headers",
  fields = {
    {
      config = {
        type = "record",
        fields = {
          {
            headerList = {
              type = "array",
              required = true,
              elements = {
                type = "record",
                required = true,
                fields = {
                  {
                    headerName = {
                      type = "string",
                      required = true,
                    },
                  },
                  {
                    mandatory = {
                      type = "boolean",
                      required = false,
                      default = false,
                    },
                  },
                  {
                    pattern = {
                      type = "string",
                      required = false,
                    },
                  },
                },
              },
            },
          },
          {
            error_response = {
              type = "record",
              fields = {
                {status_code = {type = "number", default = 422}},
                {
                  message = {
                    type = "string",
                    default = "Missing Header or Invalid Pattern"
                  }
                }
              }
            }

          },
        }
      }
    }
  }
}
