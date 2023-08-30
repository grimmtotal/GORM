# Godot4.0 ORM

### GrimmJSON Plugin (Local data management, good for local save systems)
- Configuration: 
```go

	$GORM.Configure($GORM/GrimmJSON, {}, {
		"ExampleCollection":{
			"example_default_value":0,
		}
	})

```

### MongoDBAtlas DataAPI Plugin (https://cloud.mongodb.com/)
** Disclaimer, you have to manage your collections via Atlas as the API restricts this action
- Base URL:
![image](https://github.com/grimmtotal/GORM/assets/83027121/673ec14a-2c07-42b3-af8b-ec1cbac09127)

- Data Source:
![image](https://github.com/grimmtotal/GORM/assets/83027121/9ccf28df-e7e1-4d12-aa9b-90d8a31e3d58)


- Configuration: 
```go

	$GORM.Configure($GORM/GrimmJSON,
	{
      		"api_key":"your_api_key",
		"base_url":"your_base_url",
		"data_source": "your_data_source",
		"database": "your_database",
	},
    	{
		"ExampleCollection":{
			"example_default_value":0,
		}
	})

```
