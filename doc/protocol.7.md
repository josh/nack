nack-protocol -- node ruby IPC protocol
=======================================

## DESCRIPTION

Node communicates with its Ruby worker process over a TCP or UNIX socket. The Node half is the client of the connection while the Ruby worker is the server.

### REQUEST

First, the client MUST send the `env` hash which MUST be serialized as a single JSON netstring. The `env` has MUST include the CGI environment variables specificied by the Rack SPEC. This excludes any Rack specific variables that start with "rack.".

Next, the client MAY send the request body following the `env`. The body SHOULD NOT be encoded as JSON. Depending on the size, the body MAY be sent as a single netstring or chunk into multiple smaller parts.

Once the body parts have been sent, the client MUST close its write socket to indicate the request is finished.

Sample:

  16:{"METHOD":"GET"},4:foo=,3:bar,

### RESPONSE

To start the response, the server MUST first send a netstring with the interger status code of the response. Following this MUST be a JSON serialized netstring of the response headers hash.

Similar to the request body, the response body MAY be sent as a single netstring or chunked into multiple parts. The body parts SHOULD NOT be JSON encoded.

When the repsonse is finished, the server should close its write socket thus closing the entire connection.

Sample:

  3:200,28:{"Content-Type":"text/html"},10:<!DOCTYPE ,5:html>,

## SEE ALSO

json(3), http://cr.yp.to/proto/netstrings.txt
