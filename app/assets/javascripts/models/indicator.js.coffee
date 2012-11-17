#= require app

$ = jQuery

class Indicator
  constructor: (attributes) ->
    @name = attributes.name
    @unit = attributes.unit || ''
    @value_function = attributes.value_function
    @buckets = attributes.buckets

  valueForStatistics: (statistics) ->
    statistics && @value_function(statistics)

  bucketForValue: (value) ->
    return undefined if !value? || !@buckets?
    for bucket in @buckets
      return bucket if !bucket.max? || bucket.max >= value

  bucketForStatistics: (statistics) ->
    value = this.valueForStatistics(statistics)
    this.bucketForValue(value)

window.OpenCensus.models.Indicator = Indicator
