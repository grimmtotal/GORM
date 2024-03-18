extends Node


# Called when the node enters the scene tree for the first time.
func _ready():
	$GORM.Configure($GORM/SQLite, {}, {
		"Worlds":{
			"example_default_value":0,
			"example_strict": 1,
		}
	})
	
	print($GORM.Create("Worlds", {"example_default_value": 1}))
	print($GORM.Read("Worlds"))
