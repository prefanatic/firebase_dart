// ignore_for_file: non_constant_identifier_names

@JS('gapi.iframes')
library gapi.iframes;

import 'dart:js_interop';

import 'package:web/web.dart';

@JS()
@staticInterop
external Context getContext();

@JS()
@staticInterop
class Iframe {}

extension IframeExtension on Iframe {
  external IThenable ping();
  external void restyle(IframeRestyleOptions parameters);
  external void send(
      String type, JSAny data, JSFunction onDone, IframesFilter filter);
  external void register(String eventName, JSFunction callback,
      [IframesFilter? filter]);
  external void unregister(String eventName, JSFunction callback);
}

@JS()
@anonymous
@staticInterop
abstract class Context {}

extension ContextExtension on Context {
  external void openChild(IframeOptions options);
  external void open(IframeOptions options, [JSFunction? onOpen]);
}

@JS()
@anonymous
@staticInterop
abstract class IframeAttributes {}

extension IframeAttributesExtension on IframeAttributes {
  external CSSStyleDeclaration? get style;
  external set style(CSSStyleDeclaration? value);
}

@JS()
@anonymous
@staticInterop
abstract class IframeRestyleOptions {}

extension IframeRestyleOptionsExtension on IframeRestyleOptions {
  external bool? get setHideOnLeave;
  external set setHideOnLeave(bool? value);
}

@JS()
@anonymous
@staticInterop
abstract class IframeEvent {}

extension IframeEventExtension on IframeEvent {
  external String get type;
  external set type(String value);
  external IframeAuthEvent? get authEvent;
  external set authEvent(IframeAuthEvent? value);
}

@JS()
@anonymous
@staticInterop
abstract class IframeEventHandlerResponse {}

extension IframeEventHandlerResponseExtension on IframeEventHandlerResponse {
  external String get status;
  external set status(String value);
}

typedef IframeEventHandler = IframeEventHandlerResponse Function(
    IframeEvent, Iframe);

@JS()
@anonymous
@staticInterop
abstract class IframeAuthEvent {}

extension IframeAuthEventExtension on IframeAuthEvent {
  external String? get eventId;
  external set eventId(String? value);
  external String? get postBody;
  external set postBody(String? value);
  external String? get sessionId;
  external set sessionId(String? value);
  external String? get providerId;
  external set providerId(String? value);
  external String? get tenantId;
  external set tenantId(String? value);
  external String get type;
  external set type(String value);
  external String? get urlResponse;
  external set urlResponse(String? value);
  external IframeError? get error;
  external set error(IframeError? value);
}

@JS()
@anonymous
@staticInterop
abstract class IframeError {}

extension IframeErrorExtension on IframeError {
  external String get code;
  external set code(String value);
  external String get message;
  external set message(String value);
}

@JS()
@anonymous
@staticInterop
abstract class IframeOptions {}

extension IframeOptionsExtension on IframeOptions {
  external String get url;
  external set url(String value);
  external HTMLElement? get where;
  external set where(HTMLElement? value);
  external IframeAttributes? get attributes;
  external set attributes(IframeAttributes? value);
  external IframesFilter? get messageHandlersFilter;
  external set messageHandlersFilter(IframesFilter? value);
  external bool? get dontclear;
  external set dontclear(bool? value);
}

@JS()
@anonymous
@staticInterop
abstract class IThenable {}

extension IThenableExtension on IThenable {
  external void then(JSFunction callback, JSFunction onError);
}

@JS()
@staticInterop
external IframesFilter get CROSS_ORIGIN_IFRAMES_FILTER;

@JS()
@staticInterop
abstract class IframesFilter {}

@JS()
@anonymous
@staticInterop
external IframeAttributes createIframeAttributes(
  CSSStyleDeclaration? style,
);

@JS()
@anonymous
@staticInterop
external IframeRestyleOptions createIframeRestyleOptions(
  bool? setHideOnLeave,
);

@JS()
@anonymous
@staticInterop
external IframeEventHandlerResponse createIframeEventHandlerResponse(
  String? status,
);

@JS()
@anonymous
@staticInterop
external IframeOptions createIframeOptions(
  String? url,
  HTMLElement? where,
  IframeAttributes? attributes,
  IframesFilter? messageHandlersFilter,
  bool? dontclear,
);
