// An implementation of the http://cr.yp.to/proto/netstrings.txt format.

var assert = require('assert');
var Buffer = require('buffer').Buffer;
var events = require('events');
var util   = require(!!process.binding('natives').util ? 'util' : 'sys');

// Get the length of the netstring payload (i.e. excluding header and footer)
// pointed to by Buffer or String 'buf'. Returns -1 if the buffer is
// incomplete (note that this happens even if we're only missing the trailing
// ',').
var nsPayloadLength = function(buf, off) {
    off = off || 0;

    var charCode = (typeof buf === 'string') ?
        function (i) { return buf[i].charCodeAt(0); } :
        function (i) { return buf[i]; }

    for (var len = 0, i = off; i < buf.length; i++) {
        var cc = charCode(i);

        if (cc == 0x3a) {
            if (i == off) {
                throw new Error('Invalid netstring with leading \':\'');
            }

            return len;
        }
        
        if (cc < 0x30 || cc > 0x39) {
            throw new Error('Unexpected character \'' + buf[i] +
                '\' found at offset ' + i
            );
        }

        if (len == 0 && i > off) {
            throw new Error('Invalid netstring with leading 0');
        }

        len = len * 10 + cc - 0x30;
    }

    assert.ok(i > off || off >= buf.length);

    // We didn't get a complete length specification
    if (i == buf.length) {
        return -1;
    }

    return len;
};
exports.nsPayloadLength = nsPayloadLength;

// Get the length of the netstring itself (i.e. including header and footer)
// pointed to by Buffer or String 'buf'. Negative return values are the same
// as length().
var nsLength = function(buf, off) {
    return nsWriteLength(nsPayloadLength(buf, off));
};
exports.nsLength = nsLength;

// Get the netstring payload pointed to by the Buffer or String 'buf'.
// Returns an object of the same type or a negative integer on exceptional
// condition (same as nsPayloadLength())
var nsPayload = function(buf, off) {
    off = off || 0;

    if (typeof buf === 'string') {
        buf = new Buffer(buf.substring(0, buf.length));
    }

    var len = nsPayloadLength(buf, off);
    if (len < 0) {
        return len;
    }

    var nsLen = nsWriteLength(len);

    // We don't have the entire buffer yet
    if (buf.length - off - nsLen < 0) {
        return -1;
    }

    var start = off + (nsLen - len - 1);

    return buf.slice(start, start + len);
};
exports.nsPayload = nsPayload;

// Get the length of teh netstring that would result if writing the given
// number of bytes.
var nsWriteLength = function(len) {
    // Negative values are special (see nsPayloadLength()); just return it
    if (len < 0) {
        return len;
    }

    // Compute the number of digits in the length specifier. Stop at
    // any value < 10 and just add 1 later (this catches the case where
    // '0' requires a digit.
    nslen = len;
    while (len >= 10) {
        nslen += 1;
        len /= 10;
    }
    
    // nslen + 1 (last digit) + 1 (:) + 1 (,)
    return nslen + 3;
};
exports.nsWriteLength = nsWriteLength;

// Write the given payload to a netstring.
//
// All parameters other than 'pay' are optional; 'pay' itself can be either a
// Buffer or a string. If 'payStart' is specified, the payload begins at this
// offset, defaulting to 0 if unspecified. If 'payEnd' is specified, this is
// offset of the first char (or byte, if 'pay' is a Buffer) that will be not
// be written, defaulting to writing the entire string from 'payOff'. If
// 'buf' is specified, the netstring is written to the given buffer, with a
// string being returned by default. If 'bufOff' is specified, we start at
// this offset in 'buf', defaulting to 0 is unspecified.
//
// If constructing a new string, the string is returned. If writing to a
// buffer, the number of bytes consumed is returned, or -1 if there was not
// enough space remaining in the buffer.
var nsWrite = function(pay, payStart, payEnd, buf, bufOff) {
    payStart = payStart || 0;
    payEnd = (payEnd === undefined) ? pay.length : payEnd;
    bufOff = bufOff || 0;

    if (payStart < 0 || payStart > pay.length) {
        throw new Error('payStart is out of bounds');
    }

    if (payEnd > pay.length || payEnd < payStart) {
        throw new Error('payEnd is out of bounds');
    }

    // Normalize our input into a UTF-8 encoded buffer
    //
    // XXX: Submit patch for new Buffer('');
    if (typeof pay === 'string') {
        pay = (payStart == payEnd) ?
            new Buffer(0) :
            new Buffer(pay.substring(payStart, payEnd));
        payStart = 0;
        payEnd = pay.length;
    }

    assert.equal(typeof pay, 'object');

    if (buf) {
        if (typeof buf !== 'object') {
            throw new Error('The \'buf\' parameter must be a Buffer');
        }

        var len = payEnd - payStart;
        var nsLen = nsWriteLength(len);
        var hdrLen = nsLen - len - 1;

        if (buf.length - bufOff < nsLen) {
            throw new Error('Target buffer does not have enough space');
        }

        buf.write(len + ':', bufOff);
        pay.copy(buf, bufOff + hdrLen, payStart, payEnd);
        buf.write(',', bufOff + nsLen - 1);

        return nsLen;
    } else {
        return (payEnd - payStart) + ':' +
            pay.slice(payStart, payEnd).toString() +
            ',';
    }
};
exports.nsWrite = nsWrite;

var Stream = function(s) {
    var self = this;

    events.EventEmitter.call(self);

    self.buf = null;

    s.addListener('data', function(d) {
        if (self.buf) {
            var b = new Buffer(self.buf.length + d.length);
            self.buf.copy(b, 0, 0, self.buf.length);
            d.copy(b, self.buf.length, 0, d.length);

            self.buf = b;
        } else {
            self.buf = d;
        }

        while (self.buf && self.buf.length > 0) {
            try {
                pay = nsPayload(self.buf);

                if (pay == -1) {
                    break;
                }

                var nsLen = nsWriteLength(pay.length);
                self.buf = self.buf.slice(nsLen, self.buf.length);

                self.emit('data', pay);
            } catch (exception) {
                self.emit('error', exception);
                break;
            }
        }
    });
}

util.inherits(Stream, events.EventEmitter);
exports.Stream = Stream;
