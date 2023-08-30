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
![image](https://github.com/grimmtotal/GORM/assets/83027121/315390e3-f9e5-4abc-bd4a-0287748c6a71)


- Data Source:
![image](https://github.com/grimmtotal/GORM/assets/83027121/e608447e-5e22-4dec-8fe3-f82146453991)


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
