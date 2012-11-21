#= require app
#= require models/section

Section = window.CensusFile.models.Section

SECTIONS = [
  {
    key: 'people'
    name: 'People'
    map_indicators: [ 'population-density', 'growth', 'fraction-male', 'median-age' ]
    text_indicators: [ 'population', 'text-growth', 'text-fraction-male', 'ages' ]
  }

  {
    key: 'families'
    name: 'Families'
    map_indicators: [ 'parents:mother' ]#, 'marital-status:married', 'children-at-home-per-family' ]
    text_indicators: [ 'families', 'people-per-family', 'children-at-home-per-family', 'family-parents', 'marital-statuses' ]
  }

  {
    key: 'languages'
    name: 'Languages'
    map_indicators: [ 'language:en-v-fr', 'official-language-minority' ]
    text_indicators: [ 'languages-spoken-at-home', 'official-language-minority-number', 'official-language-minority-percentage' ]
  }
]

class SectionDb
  constructor: (indicator_db) ->
    @sections = []
    @sections_by_key = {}
    @sections_by_indicator_key = {}

    for plain_section in SECTIONS
      section = new Section(
        plain_section.key,
        plain_section.name,
        indicator_db.lookup(i) for i in plain_section.map_indicators,
        indicator_db.lookup(i) for i in plain_section.text_indicators
      )
      @sections.push(section)
      @sections_by_key[section.key] = section

      for indicator in section.map_indicators when indicator?
        @sections_by_indicator_key[indicator.key.split(/:/)[0]] = section
      for indicator in section.text_indicators when indicator?
        @sections_by_indicator_key[indicator.key.split(/:/)[0]] = section

    undefined

  lookup: (key) ->
    @sections_by_key[key]

  lookupFromIndicator: (indicator) ->
    raw_key = indicator.key.split(/:/)[0]
    @sections_by_indicator_key[raw_key]

window.CensusFile.models.SectionDb = SectionDb
