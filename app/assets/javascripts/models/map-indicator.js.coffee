#= require app

class MapIndicator
  constructor: (@key, @name, @buckets, @value_function) ->

  valueForStatistics: (statistics) ->
    statistics && @value_function(statistics)

  bucketForValue: (value) ->
    return undefined if !value? || !@buckets?
    for bucket in @buckets
      return bucket if !bucket.max? || bucket.max >= value

  bucketForStatistics: (statistics) ->
    value = this.valueForStatistics(statistics)
    this.bucketForValue(value)

window.CensusFile.models.MapIndicator = MapIndicator
