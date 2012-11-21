#= require app
#= require state
#= require globals

$ = jQuery

h = window.CensusFile.helpers
state = window.CensusFile.state
globals = window.CensusFile.globals

class RegionLinkView
  constructor: (@div) ->
    $(@div).append('<div class="region1"></div><div class="region2"></div>')

    state.onRegion1Changed 'region-link-view', () => this.refresh()
    state.onRegion2Changed 'region-link-view', () => this.refresh()

    this.refresh()

  refresh: () ->
    $div = $(@div)
    this._refreshOne($div.children(':eq(0)'), state.region1)
    this._refreshOne($div.children(':eq(1)'), state.region2)

  _refreshOne: ($container, region) ->
    $container.empty()

    url = region?.url()

    if url
      $a = $('<a target="_blank" title="opens in new window">Statistics Canada profile</a>')
      $a.attr('href', url)
      $container.append($a)

$ ->
  $div = $('#opencensus-wrapper div.region-links')
  new RegionLinkView($div[0])
