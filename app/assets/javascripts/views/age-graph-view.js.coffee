#= require app
#= require state
#= require helpers/format-numbers

$ = jQuery

h = window.CensusFile.helpers

class AgeGraphView
  constructor: (@data) ->

  appendFragmentToContainer: ($container) ->
    return undefined if !@data?.t?

    categories = [ '0-4', '5-9', '10-14', '15-19', '20-24', '25-29', '30-34', '35-39', '40-44', '45-49', '50-54', '55-59', '60-64', '65-69', '70-74', '75-79', '80-84', '85+' ]
    age_counts = (@data.t[i] || 0 for __, i in categories) # ".t" = "total" (as opposed to "m" or "f")

    values = ([ categories[i], a ] for a, i in age_counts)
    values.reverse()

    # Calculate max_count and rounded_interval
    max_count = 0
    for count in age_counts
      max_count = count if count > max_count
    interval = max_count * .3
    rounded_interval = interval.toFixed(0)
    if rounded_interval.length > 1
      rounded_interval = parseInt(rounded_interval.substring(0, 1) + rounded_interval.slice(1).replace(/\d/g, '0'), 10)
    else
      rounded_interval = parseInt(rounded_interval, 10)
    if max_count / rounded_interval > 5
      rounded_interval *= 1.5
    max_count = Math.ceil(max_count / rounded_interval) * rounded_interval

    return undefined if !max_count && !rounded_interval

    html_parts = ['<div class="age-graph-view">']

    tick = 0
    html_parts.push('<div class="ticks">')
    while tick <= max_count
      html_parts.push("<div style=\"left: #{tick / max_count * 100}%\"><span>#{h.format_big_integer(tick)}</span></div>")
      tick += rounded_interval
    html_parts.push('</div>')

    for ca in values
      category = ca[0]
      age_count = ca[1]
      percent = age_count / max_count * 100

      html_parts.push("<div class=\"age-count\"><div class=\"age\">#{category}</div><div class=\"bar\" style=\"width:#{percent}%\" title=\"#{h.format_integer(age_count)} people aged #{category}\"></div></div>")

    html_parts.push('</div>')

    html = html_parts.join('')

    $container.append(html)

window.CensusFile.views.AgeGraphView = AgeGraphView
