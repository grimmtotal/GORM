extends Node


var _config = {}
@onready var _plugin = null

func Configure(plugin:Node, config={}, collection_templates={}):
	_plugin = plugin
	_config = config
	
	if _plugin == $GrimmJSON:
		return plugin.Configure(config, collection_templates)
	
	return await plugin.Configure(config, collection_templates)

func CreateCollection(collection):
	if _plugin == $GrimmJSON:
		return _plugin.CreateCollection(collection)

	return await _plugin.CreateCollection(collection)
	
func DeleteCollection(collection):
	if _plugin == $GrimmJSON:
		return _plugin.DeleteCollection(collection)
	
	return await _plugin.DeleteCollection(collection)

func Create(collection, document={}, generate_defaults=true):
	if _plugin == $GrimmJSON:
		return _plugin.Create(collection, document, generate_defaults)
		
	return await _plugin.Create(collection, document, generate_defaults)

func Read(collection, filter={}, generate_defaults=true):
	if _plugin == $GrimmJSON:
		return _plugin.Read(collection, filter, generate_defaults)
	
	return await _plugin.Read(collection, filter, generate_defaults)

func Update(collection, changed_values, filter={}, generate_defaults=true):
	if _plugin == $GrimmJSON:
		return _plugin.Update(collection, changed_values, filter, generate_defaults)
		
	return await _plugin.Update(collection, changed_values, filter, generate_defaults)

func Delete(collection, filter={}):
	if _plugin == $GrimmJSON:
		return _plugin.Delete(collection, filter)
		
	return await _plugin.Delete(collection, filter)

func FindOrCreate(collection, document, filter={}, generate_defaults=true):
	if _plugin == $GrimmJSON:
		return _plugin.FindOrCreate(collection, document, filter, generate_defaults)
		
	return await _plugin.FindOrCreate(collection, document, filter, generate_defaults)

func UpdateOrCreate(collection, document, filter={}, generate_defaults=true):
	if _plugin == $GrimmJSON:
		return _plugin.UpdateOrCreate(collection, document, filter, generate_defaults)
		
	return await _plugin.UpdateOrCreate(collection, document, filter, generate_defaults)



