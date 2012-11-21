#= require app
#= require views/graph-view

GraphView = window.CensusFile.views.GraphView

class MaritalStatusGraphView extends GraphView
  constructor: (@statuses) ->

  implGetData: () ->
    keys = [ 'Single', 'Common-law', 'Married', 'Separated', 'Divorced', 'Widowed' ]

    if keys.length == @statuses?.length
      [key, @statuses[i]] for key, i in keys

window.CensusFile.views.MaritalStatusGraphView = MaritalStatusGraphView
