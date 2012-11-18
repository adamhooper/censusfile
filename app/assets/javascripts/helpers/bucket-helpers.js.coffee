#= require app
#= require helpers/format-numbers.js.coffee

$ = jQuery

window.CensusFile.helpers.bucket_to_label = (bucket) ->
  return bucket.label if bucket.label?
  return 'more' if !bucket.max?

  formatter = window.CensusFile.helpers.get_formatter_for_numbers(bucket.max)
  return "up to #{formatter(bucket.max)}"
