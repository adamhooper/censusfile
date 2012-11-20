#= require app
#= require globals
#= require state
#= require views/legend-view

$ = jQuery

globals = window.CensusFile.globals
state = window.CensusFile.state

LegendView = window.CensusFile.views.LegendView

class SectionView
  constructor: (@div) ->
    state.onIndicatorChanged('section-view', this.refresh, this)
    this.refresh()

  _redrawWithSection: (section) ->
    $div = $(@div)
    $div.html('<div class="focus"></div><ul class="headings"></ul><ul class="legends"></ul>')
    $headings = $div.children('.headings')
    $legends = $div.children('.legends')

    for indicator in section.map_indicators
      $heading = $('<li><h4><a></a></h4></li>')
      $heading.attr('data-indicator-key', indicator.key)
      $a = $heading.find('a')
      $a.attr('href', "##{indicator.key}")
      $a.text(indicator.name)
      $headings.append($heading)

      legendView = new LegendView(indicator)
      $legend = $('<li></li>')
      $legend.attr('data-indicator-key', indicator.key)
      legendView.appendFragmentToContainer($legend)
      $legends.append($legend)

    undefined

  _resetFocus: () ->
    $div = $(@div)
    width = $div.width()
    height = $div.height()
    $focus = $('.focus')

    $focus.css({
      top: 0
      left: 0
      width: width
      height: height
    })

  _setFocus: (indicator) ->
    $headings = $('.headings li', @div)
    $heading = $headings.filter("[data-indicator-key=#{indicator.key}]")
    $headings.removeClass('selected')
    $heading.addClass('selected')

    position = $heading.position()
    width = $heading.width()
    height = $heading.height()

    $focus = $('.focus', @div)
    $focus.animate({
      left: position.left + parseInt($heading.css('margin-left'), 10) - 2
      top: position.top - 2
      width: width
      height: height
    })

    # Scroll to legend
    $legends = $('.legends', @div)
    $legend = $legends.children("[data-indicator-key=#{indicator.key}]")
    left = $legend.position().left
    $legends.animate({ left: -left })

  refresh: () ->
    indicator = state.indicator
    section = globals.sections.lookupFromIndicator(indicator)

    if !@section || @section isnt section
      @section = section
      this._redrawWithSection(section)
      this._resetFocus()

    this._setFocus(indicator)

window.CensusFile.views.SectionView = SectionView
