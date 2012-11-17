#= require app
#= require globals

$ = jQuery

region_types = window.OpenCensus.globals.region_types

class Region
  constructor: (@id, @name, @parent_ids, @statistics) ->
    [@type, @uid] = @id.split(/-/)

  equals: (rhs) ->
    @id == rhs.id

  compareTo: (rhs) ->
    return 1 if !rhs?
    v1 = this.statistics?.pop?.value || -region_types.indexOfName(@type)
    v2 = rhs?.statistics?.pop?.value || -region_types.indexOfName(rhs.type)
    v1 - v2

  getValue: (indicator) ->
    indicator.valueForStatistics(@statistics)

  getDatum: (indicator) ->
    value = this.getValue(indicator)
    value? && {
      value: value,
      z: @statistics.z
    } || undefined

  getBucket: (indicator) ->
    indicator.bucketForStatistics(@statistics)

  human_name: () ->
    region_type = region_types.findByName(@type)

    if region_type == 'DisseminationBlock' || region_type == 'DisseminationArea'
      region_type.human_name()
    else
      human_type = region_type.human_name()
      if human_type?
        "#{human_type} #{@name}"
      else
        @name

  url: () ->
    region_type = region_types.findByName(@type)
    region_type.url_for_region(this)

window.OpenCensus.models.Region = Region
