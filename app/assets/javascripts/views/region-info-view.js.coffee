#= require underscore
#= require app
#= require state
#= require views/age-graph-view
#= require views/family-parents-graph-view
#= require views/marital-statuses-graph-view

_ = window._
$ = jQuery

h = window.CensusFile.helpers
state = window.CensusFile.state
globals = window.CensusFile.globals

AgeGraphView = window.CensusFile.views.AgeGraphView
FamilyParentsGraphView = window.CensusFile.views.FamilyParentsGraphView
MaritalStatusGraphView = window.CensusFile.views.MaritalStatusGraphView

class RegionInfoView
  constructor: (@div) ->
    state.onRegion1Changed 'region-info-view', () => this.refresh()
    state.onRegion2Changed 'region-info-view', () => this.refresh()
    state.onIndicatorChanged 'region-info-view', () => this.refresh()

    this.refresh()

  refresh: () ->
    $div = $(@div)
    $div.empty()

    region1 = state.region1
    region2 = state.region2
    section = globals.sections.lookupFromIndicator(state.indicator)

    region1Data = this.regionToData(region1, section)
    region2Data = this.regionToData(region2, section)
    data = this.formatRegionData(region1Data, region2Data)

    template = JST["templates/section-#{section.key}"]

    html = template(data)

    $div.append(html)

  formatters: {
    # PEOPLE
    population: (datum, normalized_value) ->
      if !normalized_value? || normalized_value < 0.1
        normalized_value = 0.1
      bar_width = normalized_value * 100 # max: 100px
      "<div class=\"population\"><span class=\"bar\" width=\"#{bar_width}px\" /> <span class=\"value\">#{h.format_integer(datum.value)}</span></div>"
    'text-growth': (datum, normalized_value) ->
      if datum.value?
        s = h.format_float(datum.value)
        positive = s.charAt(0) != '-'
        s = "+#{s}" if positive
        "<div class=\"growth\"><span class=\"value #{positive && 'positive' || 'negative'}\">#{s}</span><span class=\"unit\">%</span></div>" # not HTML-safe
    'text-fraction-male': (datum, normalized_value) ->
      if datum.value?
        m = 100 * datum.value
        f = 100 - m

        """
          <div class=\"sex-f\"><span class=\"value\">#{h.format_float(f)}</span><span class=\"unit\">%</span></div>
          <div class=\"sex-m\"><span class=\"value\">#{h.format_float(m)}</span><span class=\"unit\">%</span></div>
        """
    ages: (datum, normalized_value) ->
      new AgeGraphView(datum.value)

    # FAMILIES
    families: (datum) ->
      "<span class=\"value\">#{h.format_integer(datum.value)}</span> <span class=\"unit\">families</span>"

    'people-per-family': (datum) ->
      "<span class=\"value\">#{h.format_float(datum.value)}</span> <span class=\"unit\">people per family</span>"

    'children-at-home-per-family': (datum) ->
      "<span class=\"value\">#{h.format_float(datum.value)}</span> <span class=\"unit\">children at home per family</span>"

    'family-parents': (datum) ->
      new FamilyParentsGraphView(datum.value)

    'marital-statuses': (datum) ->
      new MaritalStatusGraphView(datum.value)

    # LANGUAGES
    'languages-spoken-at-home': (datum) ->
      JST['templates/cell-languages-spoken-at-home']({
        languages_and_values: datum.value
      })

    'official-language-minority-number': (datum) ->
      "<div><span class=\"value\">#{h.format_integer(datum.value)}</span> <span class=\"unit\">people in minority</span></div>"

    'official-language-minority-percentage': (datum) ->
      "<div><span class=\"value\">#{h.format_float(datum.value)}</span> <span class=\"unit\">%</span></div>"
  }

  formatDatum: (key, datum, normalized_value) ->
    output = @formatters[key](datum, normalized_value)
    if output?
      if output.appendFragmentToContainer?
        $div = $('<div></div>')
        output.appendFragmentToContainer($div)
        $div.html()
      else
        output

  regionToData: (region, section) ->
    ret = {}

    for indicator in section.text_indicators
      ret[indicator.key] = region?.getDatum(indicator)

    ret

  formatRegionData: (region1Data, region2Data) ->
    out = { region1: {}, region2: {}}

    keys = _.union(_.keys(region1Data || {}), _.keys(region2Data || {}))

    for key in keys
      datum1 = region1Data?[key]
      datum2 = region2Data?[key]

      normalized1 = this._normalize(datum1?.value, datum2?.value)
      normalized2 = this._normalize(datum2?.value, datum1?.value)

      if datum1?.value?
        out.region1[key] = this.formatDatum(key, datum1, normalized1)
      else
        out.region1[key] = ''

      if datum2?.value?
        out.region2[key] = this.formatDatum(key, datum2, normalized2)
      else
        out.region2[key] = ''

    out

  # Returns this value, normalized so the larger is 1.
  # Returns undefined when it wouldn't make sense (e.g., there's no second
  # value).
  _normalize: (value, other_value) ->
    if value? && other_value? && value instanceof Number && value > 0 && other_value > 0
      value / Math.max(value, other_value)
    else
      undefined

$ ->
  $div = $('#opencensus-wrapper div.region-info-view')
  new RegionInfoView($div[0])
