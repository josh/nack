nack-protocol -- node ruby IPC protocol
=======================================

## DESCRIPTION

Node communicates with its Ruby worker process over a TCP or UNIX socket. The Node half is the client of the connection while the Ruby worker is the server.

### REQUEST

First, the client MUST send the `env` hash which MUST be serialized as a single JSON netstring. The `env` has MUST include the CGI environment variables specificied by the Rack SPEC. This excludes any Rack specific variables that start with "rack.".

Next, the client MAY send the request body following the `env`. The body SHOULD NOT be encoded as JSON. Depending on the size, the body MAY be sent as a single netstring or chunked into multiple smaller parts. These chunks MUST NOT be empty strings.

Once the body parts have been sent, the client MUST send an empty netstring to indicate the request is finished. Then the client MAY close its write socket.

Sample:

  16:{"METHOD":"GET"},4:foo=,3:bar,0:,

### RESPONSE

To start the response, the server MUST first send a netstring with the integer status code of the response. Following this MUST be a JSON serialized netstring of the response headers hash.

Similar to the request body, the response body MAY be sent as a single netstring or chunked into multiple parts. The body parts SHOULD NOT be JSON encoded or empty strings.

When the response is finished, the server MUST send an empty netstring to indicate the response is finished. After this finish string is sent, the server MAY close the connection.

Sample:

  3:200,28:{"Content-Type":"text/html"},10:<!DOCTYPE ,5:html>,0:,

## SEE ALSO

nack-client(3), json(7), netstrings(7)
