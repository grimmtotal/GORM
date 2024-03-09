extends Node


# Called when the node enters the scene tree for the first time.
func _ready():
	await $GORM.Configure($GORM/PostgreSQL, {
	"USER":"postgres",
	"PASSWORD":"PASSWORD",
	"HOST":"localhost",
	"PORT":5432,
	"DATABASE":"DATABASE",
	}, {
		"Worlds":{
			"example_default_value":0,
			"example_strict": 1,
		}
	})
	
	for i in 50:
		await get_tree().process_frame
	
	var result = await $GORM.Update("users", {"test_2": "4"}, {"test": "1"})
	print("a", result)
	
	var new_result = await $GORM.Read("users")
	print(new_result)
	
#
#	print(await $GORM.Create("Addresses", {
#		"example_default_value":13,
#		"example_strict": 2,
#		"strict":235,
#	}))
#
#	print(await $GORM.Read("Worlds", {"_id":""}))

