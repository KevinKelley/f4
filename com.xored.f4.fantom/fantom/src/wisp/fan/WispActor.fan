//
// Copyright (c) 2007, Brian Frank and Andy Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 Jun 07  Brian Frank  Creation
//

using concurrent
using inet
using web

**
** WispActor
**
internal const class WispActor : Actor
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  new make(WispService service)
    : super(service.processorPool)
  {
    this.service = service
  }

//////////////////////////////////////////////////////////////////////////
// Run
//////////////////////////////////////////////////////////////////////////

  **
  ** Process a series of HTTP requests and responses on a socket.
  **
  override Obj? receive(Obj? msg)
  {
    TcpSocket socket := ((Unsafe)msg).val
    try
    {
      // before we do anything set a receive timeout in case
      // the client fails to send us data in a timely fashion
      socket.options.receiveTimeout = 10sec

      // loop processing requests with on this socket as
      // long as a persistent connection is being used and
      // we don't have any errors
      while (process(socket)) {}
    }
    catch (Err e) { e.trace }
    finally { try { socket.close } catch {} }
    return null
  }

  **
  ** Process a single HTTP request/response.  Return true if the request
  ** was processed successfully and that a persistent connection is being
  ** used. Return false on error or if the socket should be shutdown.
  **
  Bool process(TcpSocket socket)
  {
    // allocate request, response
    res := WispRes(service, socket)
    req := WispReq(service, socket, res)

    // parse request line and headers, on error return false to
    // close socket and terminate processing on this thread and socket
    if (!parseReq(req)) return false

    // service request
    success := false
    try
    {
      // init thread locals
      Actor.locals["web.req"] = req
      Actor.locals["web.res"] = res

      // initialize the req and res
      initReqRes(req, res)

      // service which runs thru the installed web steps
      service.root.onService

      // save session if accessed
      service.sessionStore.doSave

      // assume success which allows us to re-use this connection
      success = true

      // if the weblet didn't finishing reading the content
      // stream then don't attempt to reuse this connection,
      // safest thing is to just close the socket
      try { if (req.webIn != null && req.webIn.read != null) success = false }
      catch (IOErr e) { success = false }
    }
    catch (Err e)
    {
      internalServerErr(req, res, e)
    }

    // cleanup thread locals
    Actor.locals.remove("web.req")
    Actor.locals.remove("web.res")

    // ensure response is committed and close the response
    // output stream, but don't close the underlying socket
    try { res.close } catch (Err e) { e.trace }

    // return if using persistent connections
    return success && res.isPersistent
  }

//////////////////////////////////////////////////////////////////////////
// Request
//////////////////////////////////////////////////////////////////////////

  **
  ** Parse the first request line and request headers.
  ** Return true on success, false on failure.
  **
  internal static Bool parseReq(WispReq req)
  {
    try
    {
      // skip leading CRLF (4.1)
      in := req.socket.in
      line := in.readLine
      if (line == null) return false
      while (line.isEmpty)
      {
        line = in.readLine
        if (line == null) return false
      }

      // parse request-line (5.1)
      toks   := line.split
      method := toks[0]
      uri    := toks[1]
      ver    := toks[2]

      // method
      req.method = method.upper

      // uri; immediately reject any uri which starts with ..
      req.uri = Uri.decode(uri)
      if (req.uri.path.first == "..") return false

      // version
      if (ver == "HTTP/1.1") req.version = ver11
      else if (ver == "HTTP/1.0") req.version = ver10
      else return false

      // parse headers
      req.headers = WebUtil.parseHeaders(in).ro

      // success
      return true
    }
    catch (Err e) { return false }
  }

//////////////////////////////////////////////////////////////////////////
// Response
//////////////////////////////////////////////////////////////////////////

  **
  ** Initialize the request and response.
  **
  private Void initReqRes(WispReq req, WispRes res)
  {
    // init request input stream to read content
    req.webIn = initReqInStream(req)

    // init response - set predefined headers
    res.headers["Server"] = wispVer
    res.headers["Date"] = DateTime.now.toHttpStr

    // if using HTTP 1.1 and client specified using keep-alives,
    // then setup response to be persistent for pipelining
    if (req.version === ver11 && req.isKeepAlive && !req.isUpgrade)
    {
      res.isPersistent = true
      res.headers["Connection"] = "keep-alive"
    }

    // configure Locale.cur for best match based on request
    Locale.setCur(req.locales.first)
  }

  **
  ** Map the raw HTTP input stream to handle the charset and transfer encoding
  **
  private InStream? initReqInStream(WispReq req)
  {
    // raw socket input stream
    raw := req.socket.in

    // if requesting an upgrade, then leave access to raw socket
    if (req.isUpgrade) return raw

    // init request - create content input stream wrapper
    wrap := WebUtil.makeContentInStream(req.headers, raw)

    // if the WebUtil didn't wrap the stream, then that means no
    // Content-Length or Transfer-Encoding - which in turn means we don't
    // consider this a valid request for sending a body in the request
    // according to 4.4 (since pipeling would be undefined)
    if (wrap === raw) return null
    return wrap
  }

//////////////////////////////////////////////////////////////////////////
// Error Handling
//////////////////////////////////////////////////////////////////////////

  **
  ** Send back 500 Internal server error.
  **
  private Void internalServerErr(WispReq req, WispRes res, Err err)
  {
    try
    {
      // if the error is that the socket has been disconnected
      // by the remote side, then this isn't *my* error so we don't
      // want to log spurious socket errors; we can detect
      // this by attempting to flush the socket
      if (err is IOErr)
      {
        try { req.socket.out.flush } catch { return }
      }

      // log internal error
      if (!err.msg.contains("Broken pipe"))
        WispService.log.err("Internal error processing: $req.uri", err)

      // if not committed yet, then return 400 if bad
      // client request or 500 if server error
      if (!res.isCommitted)
      {
        res.statusCode = 500
        res.headers.clear
        req.stash["err"] = err
        service.errMod.onService
      }
    }
    catch (Err e) WispService.log.err("internalServiceError res failed", e)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  static const Version ver10 := Version("1.0")
  static const Version ver11 := Version("1.1")
  static const Str wispVer   := "Wisp/" + WispActor#.pod.version

  const WispService service
}