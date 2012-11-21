#= require app
#= require state

$ = jQuery

state = window.CensusFile.state

window.CensusFile.controllers.zoom_controller = (map_view) ->
  region_to_bounds = (region) ->
    numbers = region.statistics?.b
    return if !numbers

    xmin = numbers[0]
    ymin = numbers[1]
    xmax = numbers[2]
    ymax = numbers[3]

    new google.maps.LatLngBounds(
      new google.maps.LatLng(ymin, xmin),
      new google.maps.LatLng(ymax, xmax)
    )

  $(document).on 'opencensus:zoom_region.zoom_controller', (e, region) ->
    return if !region?
    bounds = region_to_bounds(region)
    return if !bounds?
    map_view.map.fitBounds(bounds)
