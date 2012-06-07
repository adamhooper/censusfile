#= require app
#= require state

$ = jQuery

state = window.OpenCensus.state

window.OpenCensus.controllers.zoom_controller = (map_view) ->
  # We zoom in when somebody types in an address
  zoom = (latlng) ->
    if state.point2?
      bounds = map_view.map.getBounds()
      if !bounds.contains(latlng)
        bounds.extend(latlng)
        map_view.map.fitBounds(bounds)
    else
      map_view.map.setCenter(latlng)
      map_view.map.setZoom(15)

  $(document).on 'opencensus:choose_latlng.zoom_controller', (e, latlng) ->
    zoom(latlng)

  region_to_bounds = (region) ->
    value = region.statistics?.bounds?.value
    return if !value?

    numbers = value.split(/,/g)
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
