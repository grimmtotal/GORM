
## GrimmJSON Plugin (Local data management, good for local save systems)
- Configuration: 
```go

	$GORM.Configure($GORM/GrimmJSON, {}, {
		"ExampleCollection":{
			"example_default_value":0,
		}
	})

```

## MongoDBAtlas DataAPI Plugin (https://cloud.mongodb.com/)
- Configuration: 
```go

	$GORM.Configure($GORM/GrimmJSON, {
      "api_key":"your_api_key" 
    },
    {
		"ExampleCollection":{
			"example_default_value":0,
		}
	})

```
