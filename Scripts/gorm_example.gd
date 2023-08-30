extends Node


# Called when the node enters the scene tree for the first time.
func _ready():
	$GORM.Configure($GORM/MongoDBAtlas, {
		"api_key":"",
		"base_url":"https://us-west-2.aws.data.mongodb-api.com/app/data-ksjef/endpoint/data/v1",
		"data_source":"CoasterWorld",
		"database":"CoasterWorld"
	}, {
		"Worlds":{
			"example_default_value":0,
			"example_strict": 1,
		}
	})
	
#	print($GORM.UpdateOrCreate("ExampleCollection", {
#		"example_default_value":13,
#		"example_strict": 2,
#		"strict":234,
#	}, {"id":0} ))
#
	
	print(await $GORM.Read("Worlds", {"worldname":"TEST"}))
