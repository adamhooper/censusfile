#= requie app
#= require models/indicator

$ = jQuery

Indicator = window.OpenCensus.models.Indicator

class IndicatorDb
  constructor: (@indicators) ->
    indicator.key = key for key, indicator of @indicators
    @indicators_by_name = {}
    (@indicators_by_name[indicator.name] = indicator) for __, indicator of @indicators
    undefined

  findByKey: (key) ->
    @indicators[key]

  findByName: (name) ->
    @indicators_by_name[name]

  findMapIndicatorForTextIndicator: (text_indicator) ->
    key = {
      population: 'population_density'
    }[text_indicator.key]

    key? && @indicators[key] || text_indicator

window.OpenCensus.models.IndicatorDb = IndicatorDb
