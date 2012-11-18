#= require paper

$ = jQuery

geometry_string_to_path = (geometry_json) ->
  moveto = Paper.Engine.PathInstructions.moveto
  lineto = Paper.Engine.PathInstructions.lineto
  close = Paper.Engine.PathInstructions.close
  finish = Paper.Engine.PathInstructions.finish

  arr = []

  polygon_regexp = /\[\[\[([^\[].*?)\]\]\]/g
  while (polygon_match = polygon_regexp.exec(geometry_json))?
    arr.push(moveto)
    arr.push(polygon_match[1].replace(/\]\],\[\[/g, close + moveto).replace(/\],\[/g, lineto))
    arr.push(close)

  arr.push(finish)

  arr.join('')

string_to_utfgrids = (s) ->
  key = '"utfgrids":'
  index = s.indexOf(key)
  if index > -1
    json_string = get_substring_with_matched_brackets(s, index + key.length)
    $.parseJSON(json_string)

string_to_feature_strings = (s) ->
  ret = []
  key = '"features":['

  i = s.indexOf(key)
  if i > -1
    i += key.length

    while s.charAt(i) == '{'
      next = get_substring_with_matched_brackets(s, i)
      ret.push(next)
      i = i + next.length + 1 # 1 is for ","

  ret

feature_string_to_geometry_string = (s) ->
  key = '"geometry":'
  end_key = ']]}' # We know "properties" does NOT contain nested Arrays.
  index = s.indexOf(key)
  end = s.lastIndexOf(end_key)
  if index > -1 && end > index
    s.substring(index + key.length, end + end_key.length)

feature_string_to_properties = (s) ->
  key = '"properties":'
  index = s.indexOf(key)
  if index > -1
    value = get_substring_with_matched_brackets(s, index + key.length)
    $.parseJSON(value)

feature_string_to_id = (s) ->
  result = /"id":"([^"]*)"/.exec(s)
  result && result[1]

get_substring_with_matched_brackets = (s, index) ->
  quote = '"'
  open = s.charAt(index)
  close = switch open
    when '[' then ']'
    when '{' then '}'
    else throw "Found #{open} at string index #{index}, but expected [ or {"

  n_open = 1
  cur = index + 1

  next_open = 0
  next_close = 0
  next_quote = 0

  while n_open > 0
    next_quote = s.indexOf(quote, cur) if next_quote > -1 && next_quote < cur
    next_open = s.indexOf(open, cur) if next_open > -1 && next_open < cur
    next_close = s.indexOf(close, cur) if next_close > -1 && next_close < cur

    if next_quote > -1 && next_quote < next_close && (next_quote < next_open || next_open == -1)
      # Skip entire string
      cur = next_quote + 1
      next_quote = s.indexOf(quote, cur)
      throw "Unmatched quote starting at index #{cur}" if next_quote == -1
      cur = next_quote + 1
    else if next_close < next_open || next_open == -1
      # Assume input is matched, so next_close > -1
      cur = next_close + 1
      n_open -= 1
    else if next_open > -1
      cur = next_open + 1
      n_open += 1
    else
      throw "Parse error on string, at index #{cur}"

  s.substring(index, cur)

feature_string_to_feature = (s) ->
  id = feature_string_to_id(s)
  properties = feature_string_to_properties(s)
  geometry_string = feature_string_to_geometry_string(s)
  geometry = geometry_string_to_path(geometry_string)
  {
    id: id
    geometry: geometry
    properties: properties
  }

# Returns a JSON-like object, except every "geometry" is an SVG-like string.
# This makes some assumptions about the GeoJSON data from CensusFile's backend:
#
# * There are no extraneous spaces in the JSON
# * All features have:
# ** "type":"Feature"
# ** "id", a string that can be used as an XML ID
# ** "properties", a JSON Object which does NOT include "geometry" or "features"
#    or "utfgrids" or "id" keys and which does NOT contain nested Arrays.
# ** "geometry", and all geometries are of type GeometryCollection,
#    MultiPolygon and Polygon.
# * There is a root "utfgrids" value, an array of UTFGrid elements
# * There are no escaped quotes (\") in the entire input
#
# Why use this instead of parseJSON? Because IE is so incredibly slow at
# parsing JSON. We can transform GeoJSON's "geometry" values into SVG strings
# using string manipulation, without ever parsing them.
window.parse_opencensus_geojson = (text) ->
  utfgrids = string_to_utfgrids(text)
  return undefined if !utfgrids?

  feature_strings = string_to_feature_strings(text)
  features = (feature_string_to_feature(s) for s in feature_strings)

  { features: features, utfgrids: utfgrids }
