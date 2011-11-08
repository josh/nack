(function() {
  var LineBuffer, Stream, debug;
  var __slice = Array.prototype.slice, __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) {
    for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; }
    function ctor() { this.constructor = child; }
    ctor.prototype = parent.prototype;
    child.prototype = new ctor;
    child.__super__ = parent.prototype;
    return child;
  }, __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
  Stream = require('stream').Stream;
  if (process.env.NODE_DEBUG && /nack/.test(process.env.NODE_DEBUG)) {
    debug = exports.debug = function() {
      var args;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return console.error.apply(console, ['NACK:'].concat(__slice.call(args)));
    };
  } else {
    debug = exports.debug = function() {};
  }
  exports.isFunction = function(obj) {
    if (obj && obj.constructor && obj.call && obj.apply) {
      return true;
    } else {
      return false;
    }
  };
  exports.LineBuffer = LineBuffer = (function() {
    __extends(LineBuffer, Stream);
    function LineBuffer(stream) {
      var self;
      this.stream = stream;
      this.readable = true;
      this._buffer = "";
      self = this;
      this.stream.on('data', function() {
        var args;
        args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
        return self.write.apply(self, args);
      });
      this.stream.on('end', function() {
        var args;
        args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
        return self.end.apply(self, args);
      });
    }
    LineBuffer.prototype.write = function(chunk) {
      var index, line, _results;
      this._buffer += chunk;
      _results = [];
      while ((index = this._buffer.indexOf("\n")) !== -1) {
        line = this._buffer.slice(0, index);
        this._buffer = this._buffer.slice(index + 1, this._buffer.length);
        _results.push(this.emit('data', line));
      }
      return _results;
    };
    LineBuffer.prototype.end = function() {
      var args;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      if (args.length > 0) {
        this.write.apply(this, args);
      }
      return this.emit('end');
    };
    return LineBuffer;
  })();
  exports.BufferedPipe = (function() {
    __extends(BufferedPipe, Stream);
    function BufferedPipe() {
      this.writable = true;
      this.readable = true;
      this._queue = [];
      this._ended = false;
    }
    BufferedPipe.prototype.write = function(chunk, encoding) {
      if (this._queue) {
        debug("queueing " + chunk.length + " bytes");
        this._queue.push([chunk, encoding]);
      } else {
        debug("writing " + chunk.length + " bytes");
        this.emit('data', chunk, encoding);
      }
    };
    BufferedPipe.prototype.end = function(chunk, encoding) {
      if (chunk) {
        this.write(chunk, encoding);
      }
      if (this._queue) {
        this._ended = true;
      } else {
        debug("closing connection");
        this.emit('end');
      }
    };
    BufferedPipe.prototype.destroy = function() {
      return this.writable = false;
    };
    BufferedPipe.prototype.flush = function() {
      var chunk, encoding, _ref;
      if (!this._queue) {
        return;
      }
      while (this._queue && this._queue.length) {
        _ref = this._queue.shift(), chunk = _ref[0], encoding = _ref[1];
        debug("writing " + chunk.length + " bytes");
        this.emit('data', chunk, encoding);
      }
      if (this._ended) {
        debug("closing connection");
        this.emit('end');
      }
      this._queue = null;
    };
    return BufferedPipe;
  })();
  exports.BufferedRequest = (function() {
    __extends(BufferedRequest, exports.BufferedPipe);
    function BufferedRequest(method, url, headers, proxyMetaVariables) {
      this.method = method;
      this.url = url;
      this.headers = headers != null ? headers : {};
      this.proxyMetaVariables = proxyMetaVariables != null ? proxyMetaVariables : {};
      BufferedRequest.__super__.constructor.apply(this, arguments);
      this.once('pipe', __bind(function(src) {
        var key, value, _base, _base2, _base3, _base4, _ref, _ref10, _ref2, _ref3, _ref4, _ref5, _ref6, _ref7, _ref8, _ref9;
        if ((_ref = this.method) == null) {
          this.method = src.method;
        }
        if ((_ref2 = this.url) == null) {
          this.url = src.url;
        }
        _ref3 = src.headers;
        for (key in _ref3) {
          value = _ref3[key];
          if ((_ref4 = (_base = this.headers)[key]) == null) {
            _base[key] = value;
          }
        }
        _ref5 = src.proxyMetaVariables;
        for (key in _ref5) {
          value = _ref5[key];
          if ((_ref6 = (_base2 = this.proxyMetaVariables)[key]) == null) {
            _base2[key] = value;
          }
        }
        if ((_ref7 = (_base3 = this.proxyMetaVariables)['REMOTE_ADDR']) == null) {
          _base3['REMOTE_ADDR'] = "" + ((_ref8 = src.connection) != null ? _ref8.remoteAddress : void 0);
        }
        return (_ref9 = (_base4 = this.proxyMetaVariables)['REMOTE_PORT']) != null ? _ref9 : _base4['REMOTE_PORT'] = "" + ((_ref10 = src.connection) != null ? _ref10.remotePort : void 0);
      }, this));
    }
    return BufferedRequest;
  })();
}).call(this);
