#= require app
#= require views/graph-view

GraphView = window.CensusFile.views.GraphView

class FamilyParentsGraphView extends GraphView
  constructor: (@parents) ->

  implGetData: () ->
    keys = [ 'Married', 'Common-law', 'Single-father', 'Single-mother' ]

    if keys.length == @parents?.length
      [key, @parents[i]] for key, i in keys

window.CensusFile.views.FamilyParentsGraphView = FamilyParentsGraphView
