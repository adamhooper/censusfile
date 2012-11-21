#= require app
#= require views/graph-view

h = window.CensusFile.helpers
GraphView = window.CensusFile.views.GraphView

class AgeGraphView extends GraphView
  constructor: (@ages) ->

  implGetData: () ->
    if @ages?.t? # ".t" = "total" (as opposed to "m" or "f")
      categories = [ '0-4', '5-9', '10-14', '15-19', '20-24', '25-29', '30-34', '35-39', '40-44', '45-49', '50-54', '55-59', '60-64', '65-69', '70-74', '75-79', '80-84', '85+' ]
      age_counts = (@ages.t[i] || 0 for __, i in categories) # ".t" = "total" (as opposed to "m" or "f")

      values = ([ categories[i], a ] for a, i in age_counts)
      values.reverse()
      values

  implFormatTitle: (label, value) ->
    "#{h.format_integer(value)} people aged #{label}"

window.CensusFile.views.AgeGraphView = AgeGraphView
