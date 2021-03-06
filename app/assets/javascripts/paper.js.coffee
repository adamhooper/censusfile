$ = jQuery

class PaperElementSet
  constructor: (@elements) ->

  updateStyle: (attrs) ->
    (element.updateStyle(attrs) for element in @elements)

  remove: () ->
    (element.remove() for element in @elements)

  setVisibility: (visibility) ->
    (element.setVisibility(visibility) for element in @elements)

  show: () ->
    this.setVisibility(true)

  hide: () ->
    this.setVisibility(false)

  toFront: () ->
    (element.toFront() for element in @elements)

class PaperElement
  constructor: (@engine, @engineElement) ->

  updateStyle: (attrs) ->
    @engine.updateElementStyle(@engineElement, attrs)

  remove: () ->
    @engine.removeElement(@engineElement)

  setVisibility: (visibility) ->
    @engine.setElementVisibility(@engineElement, visibility)

  show: () ->
    this.setVisibility(true)

  hide: () ->
    this.setVisibility(false)

  toFront: () ->
    @engine.elementToFront(@engineElement)

class SvgEngine
  constructor: (div, attrs) ->
    @svgns = 'http://www.w3.org/2000/svg'
    @xlinkns = 'http://www.w3.org/1999/xlink'

    # Mozilla suffers from an integer overflow because it uses integers, not
    # floats, to draw SVG. Divide by 100 to stay under the limit.
    @overflowHack = false
    if navigator.userAgent.indexOf('compatible') < 0 && (m = /(mozilla)(?:.*? rv:([\w.]+))?/i.exec(navigator.userAgent))
      # TODO: when Mozilla fixes the bug (if ever), check version, m[2]
      @overflowHack = true

    @svg = this._createEngineElement('svg')
    this.updateElementStyle(@svg, {
      width: @width = attrs.width,
      height: @height = attrs.height,
      version: '1.1',
      xmlns: @svgns
    })

    if attrs.viewBox?
      @viewBox = (parseFloat(a) * (@overflowHack && 0.01 || 1.0) for a in attrs.viewBox.split(/\s/))
      @svg.setAttribute('viewBox', [ '' + f for f in @viewBox ].join(' '))
    if attrs.scaleX? || attrs.scaleY?
      @g = this._createEngineElement('g')
      @g.setAttribute('transform', "scale(#{attrs.scaleX || 1} #{attrs.scaleY || 1})")
      @svg.appendChild(@g)
    else
      @g = @svg
    @svg.style.cssText = 'overflow:hidden;position:relative'
    div.appendChild(@svg)

  _createEngineElement: (tagName) ->
    engineElement = document.createElementNS(@svgns, tagName)
    engineElement.style?.webkitTapHighlightColor = 'rgba(0,0,0,0)'
    engineElement

  _defs: () ->
    if !@defs?
      @defs = document.createElementNS(@svgns, 'defs')
      @svg.insertBefore(@defs, @g)
    @defs

  _createPattern: (url) ->
    pattern = document.createElementNS(@svgns, 'pattern')
    pattern.setAttribute('patternUnits', 'userSpaceOnUse')
    pattern.setAttribute('id', "pattern-#{SvgEngine.last_pattern_id += 1}")
    if @viewBox?
      pattern.setAttribute('x', @viewBox[0])
      pattern.setAttribute('y', @viewBox[1])
      pattern.setAttribute('width', @viewBox[2])
      pattern.setAttribute('height', @viewBox[3])
    else
      pattern.setAttribute('width', @svg.getAttribute('width'))
      pattern.setAttribute('height', @svg.getAttribute('height'))

    image = document.createElementNS(@svgns, 'image')
    image.setAttributeNS(@xlinkns, 'href', url)
    image.setAttribute('width', '100%')
    image.setAttribute('height', '100%')
    pattern.appendChild(image)

    pattern

  path: (pathString, attrs) ->
    engineElement = this._createEngineElement('path')
    #engineElement.setAttribute('fill-rule', 'evenodd')
    if @overflowHack
      # Divide numbers by 100 using a string replace
      pathString = pathString.replace(/(\d\d)\.?(\D)/g, '.$1$2')
    engineElement.setAttribute('d', pathString)
    this.updateElementStyle(engineElement, attrs)
    @g.appendChild(engineElement)

    new PaperElement(this, engineElement)

  updateElementStyle: (engineElement, attrs) ->
    skip_fill = false

    for key, val of attrs
      if key == 'pattern'
        skip_fill = true
        fill = engineElement.getAttribute('fill')
        if fill? && m = /url(#(.*))/.exec(fill)
          oldPattern = @svg.document.getElementById(m[1])
          oldPattern.parentNode.removeChild(oldParent)

        pattern = this._createPattern(val)
        this._defs().appendChild(pattern)
        engineElement.setAttribute('fill', "url(##{pattern.getAttribute('id')})")
      else if key == 'fill' && skip_fill
        # do nothing
      else
        engineElement.setAttribute(key, val)

  removeElement: (engineElement) ->
    engineElement.parentNode?.removeChild(engineElement)

  setElementVisibility: (engineElement, visibility) ->
    if visibility
      engineElement.style.display = ''
    else
      engineElement.style.display = 'none'

  elementToFront: (engineElement) ->
    engineElement.parentNode.appendChild(engineElement)

  remove: () ->
    @svg.parentNode?.removeChild(@svg)
    @svg = undefined
    @g = undefined
SvgEngine.last_pattern_id = 0
SvgEngine.PathInstructions = {
  moveto: 'M',
  lineto: 'L',
  close: 'Z',
  finish: '',
}

class VmlEngine
  constructor: (div, attrs) ->
    @vml = document.createElement('div')
    width = attrs.width || 256
    height = attrs.height || 256

    @vml.width = width
    @vml.height = height

    @_cssText = "position:absolute;left:0;top:0;width:#{width}px;height:#{height}px;"
    if attrs.viewBox?
      parts = attrs.viewBox.split(/\s/)
      originX = parseInt(parts[0], 10)
      originY = parseInt(parts[1], 10)
      if attrs.scaleX == -1
        originX = -originX - parseInt(parts[2], 10)
      if attrs.scaleY == -1
        originY = -originY - parseInt(parts[2], 10)
      @_coordorigin = "#{originX} #{originY}"
      @_coordsize = "#{parts[2]} #{parts[3]}"
    else
      @_coordorigin = "0 0"
      @_coordsize = "1000 1000"
    if attrs.scaleX == -1 || attrs.scaleY == -1
      @_cssText += "flip:#{attrs.scaleX == -1 && 'x' || ''}#{attrs.scaleY == -1 && 'y' || ''};"

    # Copied from Raphael. Don't know its purpose.
    span = document.createElement('span')
    span.style.cssText = 'position:absolute;left:-9999em;top:-9999em;padding:0;margin:0;line-height:1'
    @vml.appendChild(span)
    @vml.style.cssText = "top:0;left:0;width:#{width}px;height:#{height}px;display:inline-block;position:relative;clip:rect(0 #{width}px #{height}px 0);overflow:hidden"

    div.appendChild(@vml)

  _createEngineElement: (tagName) ->
    VmlEngine.createNode(tagName)

  path: (pathString, attrs) ->
    engineElement = this._createEngineElement('shape')
    engineElement.style.cssText = @_cssText
    engineElement.coordorigin = @_coordorigin
    engineElement.coordsize = @_coordsize
    engineElement.path = pathString
    engineElement.strokecolor = attrs.stroke || '#000000'
    engineElement.strokeweight = attrs['stroke-width'] || '1'
    if attrs.fill? && attrs.fill != 'none'
      engineElement.fillcolor = attrs.fill
    else
      engineElement.filled = false
    @vml.appendChild(engineElement)

    new PaperElement(this, engineElement)

  updateElementStyle: (engineElement, attrs) ->
    for key, val of attrs
      continue if key == 'pattern'

      key = VmlEngine.SvgAttrToVmlAttr[key]
      if key == 'fill'
        if val? && val != 'none'
          engineElement.fillcolor = val
          engineElement.filled = true
        else
          engineElement.filled = false
      else
        engineElement[key] = val

  removeElement: (engineElement) ->
    engineElement.parentNode?.removeChild(engineElement)

  setElementVisibility: (engineElement, visibility) ->
    if visibility
      engineElement.style.display = ''
    else
      engineElement.style.display = 'none'

  elementToFront: (engineElement) ->
    engineElement.parentNode.appendChild(engineElement)

  remove: () ->
    @vml.parentNode?.removeChild(@vml)
    @vml = undefined
VmlEngine.SvgAttrToVmlAttr = {
  stroke: 'strokecolor',
  'stroke-width': 'strokeweight',
  fill: 'fillcolor',
}
VmlEngine.PathInstructions = {
  moveto: ' m ',
  lineto: ' l ',
  close: ' x ',
  finish: ' e ',
}

class Paper
  constructor: (div, attrs) ->
    @engine = new Paper.Engine(div, attrs)

  setStart: () ->
    @setElements = []

  path: (pathString, attrs) ->
    element = @engine.path(pathString, attrs)
    @setElements.push(element) if @setElements?
    element

  setFinish: () ->
    element = new PaperElementSet(@setElements)
    @setElements = undefined
    element

  remove: () ->
    @engine.remove()
    @engine = undefined

getEngineName = () ->
  engineName = (window.SVGAngle || document.implementation.hasFeature("http://www.w3.org/TR/SVG11/feature#BasicStructure", "1.1")) && "SVG" || "VML"
  if engineName == 'VML'
    d = document.createElement('div')
    d.innerHTML = '<v:shape adj="1"/>'
    b = d.firstChild
    b.style.behavior = 'url(#default#VML)'
    if !(b && typeof(b.adj) == 'object')
      engineName = ''
  engineName

Paper.EngineName = getEngineName()
if Paper.EngineName == 'SVG'
  Paper.Engine = SvgEngine
else if Paper.EngineName == 'VML'
  Paper.Engine = VmlEngine

  document.createStyleSheet().addRule('.rvml', 'behavior:url(#default#VML); display:inline-block;')
  try
    document.namespaces.add('rvml', 'urn:schemas-microsoft-com:vml') if !document.namespaces.rvml?
    VmlEngine.createNode = (tagName) ->
      document.createElement("<rvml:#{tagName} class=\"rvml\">")
  catch e
    VmlEngine.createNode = (tagName) ->
      document.createElement("<#{tagName} xmlns=\"urn:schemas-microsoft-com:vml\" class=\"rvml\">")

window.Paper = Paper
