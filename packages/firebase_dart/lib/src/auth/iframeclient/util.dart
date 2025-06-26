import 'dart:js_interop';

@JS('Reflect.get')
external JSAny? getProperty(JSObject object, String property);

@JS('globalThis')
external JSObject get globalThis;

JSAny? getObjectRef(String ref) {
  JSAny? current = globalThis;
  for (final segment in ref.split('.')) {
    if (current is! JSObject) return null;
    current = getProperty(current, segment);
  }
  return current;
}

class Delay {
  final Duration minDelay;
  final Duration maxDelay;

  Delay(this.minDelay, this.maxDelay);

  Duration get() => maxDelay;
}
