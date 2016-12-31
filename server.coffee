alloc = require('tcp-bind')
minimist = require('minimist')

argv = minimist(process.argv.slice(2), {
  alias: { p: 'port', u: 'uid', g: 'gid' },
  default: { port: require('is-root')() ? 80 : 8000 }
})

fd = alloc(argv.port)

process.setgid(argv.gid) if (argv.gid)
process.setuid(argv.uid) if (argv.uid)

http = require('http')
ecstatic = require('ecstatic')(__dirname + '/static')
body = require('body/any')
xtend = require('xtend')
trumpet = require('trumpet')
hyperstream = require('hyperstream')
Readable = require('stream').Readable
encode = require('he').encode
fs = require('fs')
path = require('path')

readString = (string) ->
  rs = new Readable
  rs.push string
  rs.push null
  rs

read = (file) ->
  fs.createReadStream path.join(__dirname, 'static', file)

layout = (streams, res) ->
  res.setHeader('content-type', 'text/html')
  hs = hyperstream(streams)
  read('layout.html').pipe(hs).pipe(res)

form = (streams) ->
  hs = hyperstream(streams)
  read('form.html').pipe(hs)

post = (fn) ->
  (req, res, params) ->
    if (req.method != 'POST')
      res.statusCode = 400
      res.end('not a POST\n')
    body req, res, (err, pvars) ->
      fn(req, res, xtend(pvars, params))

renderHello = (req, res, params) ->
  body = readString('hello there, '+encode(params.name))
  layout({'#body': body}, res)

router = require('routes')()

router.addRoute '/', (req, res, params) ->
  layout({'#body': form({'#label': readString('Name:')})}, res)

router.addRoute '/hello/:name', renderHello

router.addRoute '/submit', post (req, res, params) ->
  if (params.name)
    renderHello(req, res, params)
  else
    console.log(params)
    body = readString('form submitted!')
    layout({'#body': body}, res)

server = http.createServer (req, res) ->
  m = router.match(req.url)
  if (m)
    m.fn(req, res, m.params)
  else
    ecstatic(req, res)

server.listen { fd: fd }, ->
  console.log('listening on :' + server.address().port)
