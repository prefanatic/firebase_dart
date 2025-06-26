@JS('gapi')
library gapi;

import 'dart:js_interop';

@JS()
external void load(String libraries, LoadConfig config);

@JS()
@anonymous
@staticInterop
class LoadConfig {
  external factory LoadConfig({
    JSFunction? callback,
    JSFunction? onerror,
    num? timeout,
    JSFunction? ontimeout,
  });
}

extension LoadConfigExtension on LoadConfig {
  external JSFunction? get callback;
  external set callback(JSFunction? value);

  external JSFunction? get onerror;
  external set onerror(JSFunction? value);

  external num? get timeout;
  external set timeout(num? value);

  external JSFunction? get ontimeout;
  external set ontimeout(JSFunction? value);
}
