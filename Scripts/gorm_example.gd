extends Node


# Called when the node enters the scene tree for the first time.
func _ready():
	$GORM.Configure($GORM/GrimmJSON, {}, {
		"ExampleCollection":{
			"example_default_value":0,
			"example_strict": 1,
		}
	})
	
	print($GORM.UpdateOrCreate("ExampleCollection", {
		"example_default_value":13,
		"example_strict": 2,
		"strict":234,
	}, {"id":0} ))
	
	
	print($GORM.Read("ExampleCollection"))
