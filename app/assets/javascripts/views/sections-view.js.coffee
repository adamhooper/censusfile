#= require app
#= require globals
#= require state

$ = jQuery

globals = window.CensusFile.globals
state = window.CensusFile.state

class SectionsView
  constructor: (@div) ->
    state.onIndicatorChanged('sections-view', this.refresh, this)
    this.refresh()

  _redrawWithSection: (section) ->
    $lis = $('li', @div)
    $lis.removeClass('selected')
    $lis.filter(".#{section.key}").addClass('selected')

  refresh: () ->
    indicator = state.indicator
    section = globals.sections.lookupFromIndicator(indicator)

    if !@section || @section isnt section
      @section = section
      this._redrawWithSection(section)

window.CensusFile.views.SectionsView = SectionsView
