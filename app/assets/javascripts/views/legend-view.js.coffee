#= require app
#= require globals
#= require state
#= require helpers/bucket-helpers

$ = jQuery

globals = window.CensusFile.globals
state = window.CensusFile.state
h = window.CensusFile.helpers

class LegendView
  constructor: (@indicator) ->

  appendFragmentToContainer: ($container) ->
    $div = $(@div)
    $div.empty()

    $ul = $('<ul class="buckets"></ul>')
    for bucket in @indicator.buckets
      label = h.bucket_to_label(bucket)

      $li = $('<li><span class="swatch">&nbsp;</span><span class="label"></span></li>')
      $li.find('.swatch').css('background', bucket.color)
      $li.find('.label').text(label)

      $ul.append($li)

    $container.append($ul)

window.CensusFile.views.LegendView = LegendView
