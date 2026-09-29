extends Node


# Called when the node enters the scene tree for the first time.
func _ready():
	# To try SQLite instead: $GORM.Configure($GORM/SQLite, {}, templates)
	await $GORM.Configure($GORM/PostgreSQL, {
		"USER":"postgres",
		"PASSWORD":"PASSWORD",
		"HOST":"localhost",
		"PORT":5432,
		"DATABASE":"postgres",
	}, {
		"Worlds":{
			"example_default_value":0,
			"example_strict": "test",
			"example_array": ["a", 3, 4]
		}
	})

	print(await $GORM.Create("Worlds", {"example_default_value": 1}))
	print(await $GORM.Read("Worlds"))
	print(await $GORM.Update("Worlds", {"example_strict": "4"}, {"example_default_value": 1}))
	print(await $GORM.Read("Worlds", {"example_strict": "4"}))
	print(await $GORM.Delete("Worlds", {"example_default_value": 1}))
	print(await $GORM.Read("Worlds"))
