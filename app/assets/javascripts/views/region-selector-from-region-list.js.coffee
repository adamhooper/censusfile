#= require app
#= require state
#= require globals
#= require helpers/region-helpers
#= require image_path

$ = jQuery

state = window.CensusFile.state
globals = window.CensusFile.globals
h = window.CensusFile.helpers

class RegionSelectorFromRegionList
  constructor: (@div, @n) ->
    @markerImageUrl = image_path("marker#{@n}.png")
    listenerKey = "region-selector-from-region-list-#{@n}"
    onRegionListChanged = "onRegionList#{@n}Changed"
    onRegionChanged = "onRegion#{@n}Changed"
    state[onRegionListChanged](listenerKey, () => this.refresh())
    state[onRegionChanged](listenerKey, () => this.refresh())

    this.refresh()

  refresh: () ->
    $div = $(@div)
    $div.empty()

    region_list = state["region_list#{@n}"]
    setter = "setRegion#{@n}"
    selected_region = state["region#{@n}"]

    $prompt = if region_list?
      $("<div class=\"prompt\"><a href=\"#\">Zoom here</a> or drag <img src=\"#{@markerImageUrl}\" alt=\"marker\" width=\"9\" height=\"21\" /> to move</div>")
    else
      $("<div class=\"prompt\">Click the map to drop a <img src=\"#{@markerImageUrl}\" alt=\"marker\" width=\"9\" height=\"21\" /></div>")
    $prompt.find('a').on 'click', (e) =>
      e.preventDefault()
      $(document).trigger('opencensus:zoom_region', [ state["region#{@n}"] ])

    $div.append($prompt)

    $selected = $('<div class="selected"></div>')
    $div.append($selected)

    if selected_region?
      $selected.attr('data-region-id', selected_region.id) # makes debugging easier
      $selected.append(h.region_to_human_html(selected_region))

    if region_list?
      populations = {}
      $ul = $('<ul class="region-select"></ul>')

      for region in region_list
        # Ignore parent regions which are duplicates
        if region.statistics?['2011']?.p?
          key = region.statistics['2011'].p
          continue if populations[key]?
          populations[key] = true

        $li = $('<li></li>')
        $li.attr('data-region-id', region.id)
        $li.append(h.region_to_human_html(region))
        $li.on 'click', (e) ->
          e.preventDefault()
          region_id = $(e.currentTarget).attr('data-region-id')
          r = globals.region_store.get(region_id)
          state[setter](r)

        $ul.append($li)

      $div.append($ul)

      $selected.append('<b class="caret"></b>')
      $selected.on('hover', (-> $selected.addClass('hover')), (-> $selected.removeClass('hover')))

      $layer = undefined

      show = () ->
        $body = $('body')
        $layer = $('<div></div>').css({
          position: 'absolute'
          zIndex: 3
          top: 0
          bottom: 0
          left: 0
          right: 0
          background: 'transparent'
        })
        $layer.css({ background: 'rgba(255, 255, 255, .3)' })
        $body.append($layer)
        $ul.show()
        ul_offset = $ul.offset()
        $layer.append($ul)
        $ul.css({
          position: 'absolute'
          left: ul_offset.left
          top: ul_offset.top
        })
        $layer.on('click', hide) # Even selection-clicks will touch the layer

      hide = () ->
        $div.append($ul)
        $ul.css({
          position: 'static'
        })
        $ul.hide()
        $layer.remove()

      $selected.on('click', show)

$ ->
  $div = $('#opencensus-wrapper div.region-selector')
  $region1 = $('<div class="wrapper"></div>')
  $region2 = $('<div class="wrapper"></div>')

  $div.append($region1)
  $div.append($region2)

  new RegionSelectorFromRegionList($region1, 1)
  new RegionSelectorFromRegionList($region2, 2)
