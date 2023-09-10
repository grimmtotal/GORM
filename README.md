# Godot4.0 ORM


<details>
  <summary>GrimmJSON Plugin (Local data management, good for local save systems)</summary>

- Configuration:
```gdscript
  $GORM.Configure($GORM/GrimmJSON, {}, {
    "ExampleCollection":{
      "example_default_value":0,
    }
  })
```
</details>

<details>
  <summary>(WIP) MongoDBAtlas DataAPI Plugin (https://cloud.mongodb.com/)</summary>
** Disclaimer, you have to manage your collections via Atlas as the API restricts this action

** Disclaimer, this plugin is a WIP and not done yet.

- Base URL:
![image](https://github.com/grimmtotal/GORM/assets/83027121/315390e3-f9e5-4abc-bd4a-0287748c6a71)


- Data Source:
![image](https://github.com/grimmtotal/GORM/assets/83027121/e608447e-5e22-4dec-8fe3-f82146453991)


- Configuration:
```gdscript
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
</details>


# GORM Filter Types

## Table of Contents
- [Exact Match (`exact`) [`default behavior`]](#exact)
- [Case-Insensitive Exact Match (`iexact`)](#iexact)
- [Contains String (`contains`)](#contains)
- [Case-Insensitive Contains String (`icontains`)](#icontains)
- [Greater Than (`gt`)](#gt)
- [Greater Than or Equal To (`gte`)](#gte)
- [Less Than (`lt`)](#lt)
- [Less Than or Equal To (`lte`)](#lte)
- [In List (`in`)](#in)
- [Within Range (`range`)](#range)
- [Is Null (`isnull`)](#isnull)
- [Regular Expression Match (`regex`)](#regex)
- [Case-Insensitive Regular Expression Match (`iregex`)](#iregex)
- [Starts With (`startswith`)](#startswith)
- [Case-Insensitive Starts With (`istartswith`)](#istartswith)
- [Ends With (`endswith`)](#endswith)
- [Case-Insensitive Ends With (`iendswith`)](#iendswith)


### `exact`

Checks for an exact match.

**Example:**
```gdscript
$GORM.Read("ExampleCollection", {"name__exact": "John"})
```

### `iexact`

Case-insensitive exact match.

**Example:**
```gdscript
$GORM.Read("ExampleCollection", {"name__iexact": "john"})
```

### `contains`

Checks if the field contains the given string.

**Example:**
```gdscript
$GORM.Read("ExampleCollection", {"name__contains": "oh"})
```

### `icontains`

Case-insensitive containment check.

**Example:**
```gdscript
$GORM.Read("ExampleCollection", {"name__icontains": "oh"})
```

### `gt`

Greater than; works with numbers.

**Example:**
```gdscript
$GORM.Read("ExampleCollection", {"age__gt": 30})
```

### `gte`

Greater than or equal to; works with numbers.

**Example:**
```gdscript
$GORM.Read("ExampleCollection", {"age__gte": 30})
```

### `lt`

Less than; works with numbers.

**Example:**
```gdscript
$GORM.Read("ExampleCollection", {"age__lt": 30})
```

### `lte`

Less than or equal to; works with numbers.

**Example:**
```gdscript
$GORM.Read("ExampleCollection", {"age__lte": 30})
```

### `in`

Checks if the field value is in the given list.

**Example:**
```gdscript
$GORM.Read("ExampleCollection", {"is_alive__in": [true]})
```

### `range`

Checks if the field value falls within a given range.

**Example:**
```gdscript
$GORM.Read("ExampleCollection", {"age__range": [30, 40]})
```

### `isnull`

Checks if the field value is null or not.

**Example:**
```gdscript
$GORM.Read("ExampleCollection", {"email__isnull": true})
```

### `regex`

Checks if the field value matches the regular expression.

**Example:**
```gdscript
$GORM.Read("ExampleCollection", {"name__regex": "^Jo"})
```

### `iregex`

Case-insensitive regular expression match.

**Example:**
```gdscript
$GORM.Read("ExampleCollection", {"name__iregex": "^jo"})
```

### `startswith`

Checks if the field value starts with the given string.

**Example:**
```gdscript
$GORM.Read("ExampleCollection", {"name__startswith": "Jo"})
```

### `istartswith`

Case-insensitive check if the field value starts with the given string.

**Example:**
```gdscript
$GORM.Read("ExampleCollection", {"name__istartswith": "jo"})
```

### `endswith`

Checks if the field value ends with the given string.

**Example:**
```gdscript
$GORM.Read("ExampleCollection", {"name__endswith": "n"})
```

### `iendswith`

Case-insensitive check if the field value ends with the given string.

**Example:**
```gdscript
$GORM.Read("ExampleCollection", {"name__iendswith": "N"})
```

