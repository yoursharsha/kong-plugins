return {
	name = "kong-logger",
	fields = {
	  {
		config = {
		  type = "record",
		  fields = {
			{
			  maskRules = {
				type = "array",
				elements = {
				  type = "record",
				  required = true,
				  fields = {
					{
					  pattern = {
						type = "string",
						required = true,
					  },
					},
					{
					  replace = {
						type = "string",
						required = true,
					  },
					},
				  },
				},
			  },
			},
			{
			  request = {
				type = "record",
				fields = {
				  {payload = {type = "boolean", default = false}},
				}
			  }
  
			},
			{
			  response = {
				type = "record",
				fields = {
				  {payload = {type = "boolean", default = false}},
				}
			  }
  
			},
		  }
		}
	  }
	}
  }
  
