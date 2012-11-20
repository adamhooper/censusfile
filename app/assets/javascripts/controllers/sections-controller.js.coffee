#= require app
#= require state
#= require views/sections-view

$ = jQuery

state = window.CensusFile.state
SectionsView = window.CensusFile.views.SectionsView

sections_controller = (div) ->
  new SectionsView(div)

  $(div).on 'click', 'a', (e) ->
    e.preventDefault()
    $a = $(e.target)
    indicator_key = $a.attr('href').substring(1)
    state.setIndicator(indicator_key)

$ ->
  $div = $('#opencensus-wrapper div.nav div.sections')
  sections_controller($div[0])
