#= require app
#= require state
#= require helpers/format-numbers
#= require views/age-graph-view
#= require views/region-selector-from-region-list
#= require templates/population-table

$ = jQuery

h = window.OpenCensus.helpers
state = window.OpenCensus.state
globals = window.OpenCensus.globals

AgeGraphView = window.OpenCensus.views.AgeGraphView
RegionSelectorFromRegionList = window.OpenCensus.views.RegionSelectorFromRegionList

class RegionInfoView
  constructor: (@div) ->
    $(@div).append(JST['templates/population-table']())

    $regionTh = $(@div).find('th.region:eq(0)')
    $regionTh.append('<div></div>')
    new RegionSelectorFromRegionList($regionTh.find('div'), 1)

    $regionCompareTh = $(@div).find('th.compare-region:eq(0)')
    $regionCompareTh.append('<div></div>')
    new RegionSelectorFromRegionList($regionCompareTh.find('div'), 2)

    this.refresh()
    state.onRegion1Changed 'region-info-view', () => this.refresh()
    state.onRegion2Changed 'region-info-view', () => this.refresh()

  refresh: () ->
    region1 = state.region1
    region2 = state.region2

    region1Data = this.regionToData(region1)
    region2Data = this.regionToData(region2)

    indicators = this.visibleIndicators(region1Data, region2Data)

    this.refreshVisibleRows(indicators)

    this.fillTableData(indicators, region1Data, region2Data)
    this.refreshUrls(region1, region2)

  _fillThUrl: ($th, url) ->
    $th.empty()

    if url
      $a = $('<a target="_blank" title="opens in new window">Statistics Canada profile</a>')
      $a.attr('href', url)
      $th.append($a)

  refreshUrls: (region, compareRegion) ->
    $tr = $(@div).find('tbody.links tr')
    $th1 = $tr.find('td.region')
    $th2 = $tr.find('td.compare-region')

    this._fillThUrl($th1, region?.url())
    this._fillThUrl($th2, compareRegion?.url())

  formatters: {
    population: (datum, normalized_value) ->
      if !normalized_value? || normalized_value < 0.1
        normalized_value = 0.1
      bar_width = normalized_value * 100 # max: 100px
      "<div class=\"population\"><span class=\"bar\" width=\"#{bar_width}px\" /> <span class=\"value\">#{h.format_integer(datum.value)}</span></div>"
    growth: (datum, normalized_value) ->
      if datum.value?
        s = h.format_float(datum.value)
        positive = s.charAt(0) != '-'
        s = "+#{s}" if positive
        "<div class=\"growth\"><span class=\"value #{positive && 'positive' || 'negative'}\">#{s}</span><span class=\"unit\">%</span></div>" # not HTML-safe
    fraction_male: (datum, normalized_value) ->
      if datum.value?
        f = 100 * datum.value
        m = 100 - f

        """
          <div class=\"sex-f\"><span class=\"value\">#{h.format_float(f)}</span><span class=\"unit\">%</span></div>
          <div class=\"sex-m\"><span class=\"value\">#{h.format_float(m)}</span><span class=\"unit\">%</span></div>
        """
    ages: (datum, normalized_value) ->
      new AgeGraphView(datum.value)
    population_density: () ->
  }

  appendDatumToContainer: ($container, indicator, datum, normalized_value) ->
    $container.empty()
    output = @formatters[indicator.key](datum, normalized_value)
    if output?
      if output.appendFragmentToContainer?
        output.appendFragmentToContainer($container)
      else
        # output is HTML
        $container.append(output)

  regionToData: (region, indicators) ->
    ret = {}
    for __, indicator of globals.indicators.indicators
      ret[indicator.key] = region?.getDatum(indicator)

    ret

  visibleIndicators: (region1Data, region2Data) ->
    ret = {}
    ret[key] = indicator for key, indicator of globals.indicators.indicators when region1Data[key]? || region2Data[key]
    ret

  refreshVisibleRows: (visibleIndicators) ->
    $tbodies = $(@div).find('thead, tbody')
    $tbodies.filter(':not(.regions):not(.links)').hide()
    for key, __ of visibleIndicators
      $tbodies.filter(".#{key}").show()
    undefined

  fillTableData: (indicators, region1Data, region2Data) ->
    $region1Tds = $('td.region', @div)
    $region2Tds = $('td.compare-region', @div)

    for key, indicator of indicators
      datum1 = region1Data?[key]
      datum2 = region2Data?[key]

      normalized1 = this._normalize(datum1?.value, datum2?.value)
      normalized2 = this._normalize(datum2?.value, datum1?.value)

      $td1 = $("tbody.#{key} td.region", @div)
      $td2 = $("tbody.#{key} td.compare-region", @div)

      $td1.empty()
      if datum1?.value?
        this.appendDatumToContainer($td1, indicator, datum1, normalized1)

      $td2.empty()
      if datum2?.value?
        this.appendDatumToContainer($td2, indicator, datum2, normalized2)

  # Returns this value, normalized so the larger is 1.
  # Returns undefined when it wouldn't make sense (e.g., there's no second
  # value).
  _normalize: (value, other_value) ->
    if value? && other_value? && value instanceof Number && value > 0 && other_value > 0
      value / Math.max(value, other_value)
    else
      undefined

$ ->
  $div = $('#opencensus-wrapper div.region-info')
  new RegionInfoView($div[0])
