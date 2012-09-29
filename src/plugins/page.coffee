
path = require 'path'
gm = require('gm')
async = require 'async'
underscore = require 'underscore'
moment = require 'moment'

{ContentPlugin} = require './../content'
{stripExtension, extend} = require './../common'

jsdom  = require('jsdom');
fs     = require('fs');
jquery = fs.readFileSync("./jquery-1.8.2.min.js").toString();

class Page extends ContentPlugin
  ### page content plugin, a page is a file that has
      metadata, html and a template that renders it ###

  constructor: (@_filename, @_content, @_metadata) ->

  getFilename: ->
    @_metadata.filename or stripExtension(@_filename) + '.html'

  getHtml: (base='/') ->
    @_content

  getUrl: (base) ->
    super(base).replace /index\.html$/, ''
    
  getIntro: (base) ->
    @_html ?= @getHtml(base)
    idx = ~@_html.indexOf('<span class="more') or ~@_html.indexOf('<h2') or ~@_html.indexOf('<hr')
    if idx
      @_intro = @_html.substr 0, ~idx
    else
      @_intro = @_html
    return @_intro

  render: (locals, contents, templates, callback) ->
    if @template == 'none'
      # dont render
      return callback null, null

    async.waterfall [
      (callback) =>
        template = templates[@template]
        if not template?
          callback new Error "page '#{ @filename }' specifies unknown template '#{ @template }'"
        else
          callback null, template
      (template, callback) =>
        ctx =
          page: @
          contents: contents
          _: underscore
          moment: moment
        extend ctx, locals
        template.render ctx, callback
      (result, callback) =>
        jsdom.env({
          html: result.toString()
          src: [
            jquery
          ]
          done: (errors, window) =>
            $ = window.$;
            resizecalls = []
            resizecall = (job, callback) =>
              [x, oldpath, newpath, xsiz, ysiz] = job
              # console.log 'resize called', x, oldpath, newpath
              gm('contents/' + oldpath)
              .resize(xsiz,ysiz).noProfile()
              .write ('contents/' + newpath), (err) =>
              gm('contents/' + newpath).size (err, value) =>
                console.log 'size', newpath, value
                x.src = '/' + newpath #'http://paulbohm.com' + x.src
                $(x).attr('height', value['height'])
                $(x).attr('width', value['width'])
                callback(null, value)

            for x in $('img')
              if x.src.indexOf('http://paulbohm.com/images/') == 0
                x.src = x.src[ 'http://paulbohm.com'.length .. ]
              if x.src.indexOf('/images/') == 0 or x.src.indexOf('/image/') == 0
                xsiz = parseInt($(x).attr('width'))
                ysiz = parseInt($(x).attr('height'))
                params = x.src.split('/')
                xsiz = xsiz || params[2]
                ysiz = ysiz || params[3]
                if xsiz == '0'
                  xsiz = ''
                if ysiz == '0'
                  ysiz = ''
                filename = params[4]
                oldpath =  'newimages/' + filename
                newpath = 'resized/' + xsiz + '_' + ysiz + '-' + filename
                resizecalls.push( [x, oldpath, newpath, xsiz, ysiz] )

            async.map resizecalls, resizecall, (err, results) =>
              console.log 'resize finished', err, results
              winbuf = new Buffer(window.document.innerHTML.toString())
              callback(null, winbuf)
        })
    ], callback

  @property 'metadata', ->
    @_metadata

  @property 'template', ->
    @_metadata.template or 'none'

  @property 'html', ->
    @getHtml()

  @property 'title', ->
    @_metadata.title or 'Untitled'

  @property 'date', ->
    new Date(@_metadata.date or 0)

  @property 'rfc822date', ->
    moment(@date).format('ddd, DD MMM YYYY HH:mm:ss ZZ')

  @property 'intro', ->
    @getIntro()

  @property 'hasMore', ->
    @_html ?= @getHtml()
    @_intro ?= @getIntro()
    @_hasMore ?= (@_html.length > @_intro.length)
    return @_hasMore

module.exports = Page
