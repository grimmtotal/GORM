extends Node


# Called when the node enters the scene tree for the first time.
func _ready():
	$GORM.Configure($GORM/MongoDBAtlas, {
		"api_key":"",
		"base_url":"mongodb-endpoint",
		"data_source":"DataSource",
		"database":"DataBase"
	}, {
		"Worlds":{
			"example_default_value":0,
			"example_strict": 1,
		}
	})
	
#
#	print(await $GORM.Create("Addresses", {
#		"example_default_value":13,
#		"example_strict": 2,
#		"strict":235,
#	}))
#
#	print(await $GORM.Read("Worlds", {"_id":""}))
