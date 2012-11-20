#= require app

class TextIndicator
  constructor: (@key, @name, @unit, @value_function) ->

  valueForStatistics: (statistics) ->
    statistics && @value_function(statistics)

window.CensusFile.models.TextIndicator = TextIndicator
