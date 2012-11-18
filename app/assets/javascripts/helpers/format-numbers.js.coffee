#= require app

$ = jQuery

window.CensusFile.helpers.format_float = (n, decimals = 2) ->
  s = n.toFixed(decimals)
  if decimals > 3
    while /[.,]\d{4}/.test(s)
      s = s.replace(/([.,])(\d{3})(\d)/, '$1$2,$3')
  while /\d{4}/.test(s)
    s = s.replace(/(\d)(\d{3})\b/, '$1,$2')
  s

window.CensusFile.helpers.format_integer = (n) ->
  window.CensusFile.helpers.format_float(n, 0)

window.CensusFile.helpers.format_big_integer = (n) ->
  s = window.CensusFile.helpers.format_integer(n)
  if m = /^(.*),000,000$/.exec(s)
    "#{m[1]}M"
  else if m = /^(.*),000$/.exec(s)
    "#{m[1]}K"
  else
    s

window.CensusFile.helpers.format_percent = (n, decimals = 2) ->
  "#{window.CensusFile.helpers.format_float(n * 100, decimals)}%"

window.CensusFile.helpers.get_formatter_for_numbers = (ns) ->
  decimals = 0
  for n in ns
    s = '' + n
    i = s.indexOf('.')
    if i >= 0
      d = s.length - i - 1
      decimals = d if d > decimals

  decimals = 2 if decimals > 2

  (n) -> window.CensusFile.helpers.format_float(n, decimals)
