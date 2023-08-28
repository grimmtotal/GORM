extends Node


# Called when the node enters the scene tree for the first time.
func _ready():
	$GORM.Configure($GORM/GrimmJSON, {}, {
		"ExampleCollection":{
			"example_default_value":0,
			"example_default_string":"example_string",
		}
	})
	
	$GORM.UpdateOrCreate("ExampleCollection", {
		"example_default_value":1
	}, {"id":0} )
	
	print($GORM.Read("ExampleCollection"))
