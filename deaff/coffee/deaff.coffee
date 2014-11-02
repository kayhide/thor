links =
  'http://google.com/':
    '104,116,116,112,58,47,47,121,97,104,111,111,46,99,111,46,106,112,47'
$ ->
  setTimeout =>
    for link in document.getElementsByTagName('a')
      if obj = links[link.href]
        # console.log link.href
        # console.log obj
        $(link).data('value', obj)
        $(link).click ->
          href = @href
          setTimeout =>
            @href = href
          , 1000
          @href = eval 'String.fromCharCode(' + $(@).data('value') + ')'
          true
        link
    null
  , 1000
