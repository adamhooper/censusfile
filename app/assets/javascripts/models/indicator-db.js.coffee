#= requie app
#= require models/map-indicator
#= require models/text-indicator

MapIndicator = window.CensusFile.models.MapIndicator
TextIndicator = window.CensusFile.models.TextIndicator

sum = (array) ->
  ret = 0
  ret += val for val in array
  ret

TEXT_INDICATORS = {
  population: {
    name: 'Population'
    value_function: (s) -> s['2011']?.p
  }

  'text-growth': {
    name: 'Growth'
    unit: '%'
    value_function: (s) -> s['2011']?.g
  }

  'text-fraction-male': {
    name: 'Sexes'
    unit: '%'
    value_function: (statistics) ->
      all_m = statistics['2011']?.a?.m
      all_t = statistics['2011']?.a?.t

      m = sum(all_m || [])
      t = sum(all_t || [])

      m && t && m / t || undefined
  }

  ages: {
    name: 'Ages'
    value_function: (s) -> s['2011']?.a
  }
}

MAP_INDICATORS = {
  'population-density': {
    name: 'Population density'
    value_function: (s) -> s['2011']?.d
    buckets: [
      { max: 5, color: '#edf8fb', label: 'up to 5 people per km²' },
      { max: 25, color: '#b3cde3' },
      { max: 200, color: '#8c96c6' },
      { max: 1000, color: '#8856a7' },
      { color: '#810f7c' }
    ]
  }

  growth: {
    name: 'Growth'
    value_function: (s) -> s['2011']?.g
    buckets: [
      { max: -5, color: '#d7191c', label: 'shrank over 5%' },
      { max: 0, color: '#fdae61', label: 'shrank' },
      { max: 4.9999, color: '#ffffbf', label: 'grew under 5%' },
      { max: 9.9999, color: '#a6d96a', label: 'grew under 10%' },
      { color: '#1a9641', label: 'grew at least 10%' }
    ]
  }

  'fraction-male': {
    name: 'Sexes'
    value_function: (statistics) ->
      all_m = statistics['2011']?.a?.m
      all_t = statistics['2011']?.a?.t

      m = sum(all_m || [])
      t = sum(all_t || [])

      m && t && m / t * 100 || undefined
    buckets: [
      { max: 46.99999, color: '#d7191c', label: 'over 53% female' },
      { max: 48.99999, color: '#fdae61', label: 'over 51% female' },
      { max: 51, color: '#ffffbf', label: 'about even' },
      { max: 53, color: '#abd9e9', label: 'over 51% male' },
      { color: '#2c7bb6', label: 'over 53% male' }
    ]
  }

  'median-age': {
    name: 'Median age'
    value_function: (s) -> s['2011']?.ma
    buckets: [
      { max: 34.999, color: '#ffffb2', label: 'median under 35' },
      { max: 39.999, color: '#fecc5c', label: 'under 40' },
      { max: 44.999, color: '#fd8d3c', label: 'under 45' },
      { max: 49.999, color: '#f03b20', label: 'under 50' },
      { color: '#bd0026', label: '50 and over' }
    ]
  }

  'language:en-v-fr': {
    name: 'Language spoken at home: English vs French',
    value_function: (s) ->
      all = s['2011']?.lh

      if all
        en = /(?:\b|\d)en(\d+)/.exec(all)?[1]
        fr = /(?:\b|\d)fr(\d+)/.exec(all)?[1]

        en = if en then parseInt(en, 10) else 0
        fr = if fr then parseInt(fr, 10) else 0

        fr / en # may be Infinity
    buckets: [
      { max: 0.25, color: '#ca0020', label: '4x more English' },
      { max: 1/1.5, color: '#f4a582', label: '1.5x more' },
      { max: 1.5, color: '#f7f7f7', label: 'about equal' },
      { max: 4, color: '#92c5de', label: '1.5x more' },
      { color: '#0571b0', label: '4x more French' }
    ]
  }

  'official-language-minority': {
    name: 'Official language minority'
    value_function: (s) -> s['2011']?.lm
    buckets: [
      { max: 2, color: '#eff3ff', label: 'less than 2% minority'},
      { max: 10, color: '#bdd7e7', label: '< 10% minority' },
      { max: 20, color: '#6baed6', label: '< 20% minority' },
      { color: '#2171b5', label: 'larger minority' }
    ]
  }
}

class IndicatorDb
  constructor: () ->
    @indicators = {}

  lookup: (key) ->
    #key = key.split(/:/)[0]
    @indicators[key] ||= if TEXT_INDICATORS[key]?
      ind = TEXT_INDICATORS[key]
      new TextIndicator(key, ind.name, ind.unit, ind.value_function)
    else if MAP_INDICATORS[key]?
      ind = MAP_INDICATORS[key]
      new MapIndicator(key, ind.name, ind.buckets, ind.value_function)
    else
      undefined
      #throw "Could not find indicator with key '#{key}'" if !ind?

window.CensusFile.models.IndicatorDb = IndicatorDb
