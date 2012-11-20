#= require app
#= require state
#= require views/section-view

$ = jQuery

state = window.CensusFile.state
SectionView = window.CensusFile.views.SectionView

section_controller = (div) ->
  new SectionView(div)

  $(div).on 'click', 'a', (e) ->
    e.preventDefault()
    $a = $(e.target)
    indicator_key = $a.attr('href').substring(1)
    state.setIndicator(indicator_key)

$ ->
  $div = $('#opencensus-wrapper div.section')
  section_controller($div[0])
