#= require jquery
#= require app

$ = jQuery
h = window.CensusFile.helpers

class GraphView
  # Implementing classes must implement implGetData()

  valuesToTicks: (values) ->
    max_value = Math.max(values...)

    if max_value > 0
      interval = max_value * .3
      rounded_interval = interval.toFixed(0)
      if rounded_interval.length > 1
        rounded_interval = parseInt(rounded_interval.substring(0, 1) + rounded_interval.slice(1).replace(/\d/g, '0'), 10)
      else
        rounded_interval = parseInt(rounded_interval, 10)
      if max_value / rounded_interval > 5
        rounded_interval *= 1.5
      max_value = Math.ceil(max_value / rounded_interval) * rounded_interval

      (n for n in [0..max_value] by rounded_interval)

  implGetData: () ->
    # Return a list of [key, value] pairs
    throw 'Not implemented'

  implFormatTitle: (label, value) ->
    ""

  appendFragmentToContainer: ($container) ->
    data = this.implGetData()

    if data?.length
      html_parts = ['<div class="graph-view">']

      values = (d[1] for d in data)
      ticks = this.valuesToTicks(values)
      if ticks.length
        last_tick = ticks[ticks.length-1]
        html_parts.push('<div class="ticks">')
        for tick in ticks
          html_parts.push("<div style=\"left: #{tick / last_tick * 100}%\"><span>#{h.format_big_integer(tick)}</span></div>")
        html_parts.push('</div>')

        for kv in data
          label = kv[0]
          value = kv[1]
          percent = value / last_tick * 100

          html_parts.push("<div class=\"row\"><div class=\"label\">#{label}</div><div class=\"bar\" style=\"width:#{percent}%\" title=\"#{this.implFormatTitle(label, value)}\"></div></div>")

        html_parts.push('</div>')

        html = html_parts.join('')

        $container.append(html)

window.CensusFile.views.GraphView = GraphView
