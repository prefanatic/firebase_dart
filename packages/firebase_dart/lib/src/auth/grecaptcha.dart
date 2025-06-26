@JS()
library grecaptcha;

import 'dart:js_interop';

@JS()
@anonymous
@staticInterop
class GRecaptcha {}

extension GRecaptchaExtension on GRecaptcha {
  /// Renders the container as a reCAPTCHA widget and returns the ID of the
  /// newly created widget..
  ///
  /// [container] is the HTML element to render the reCAPTCHA widget.
  /// Specify either the ID of the container (string) or the DOM element itself.
  external int render(JSAny container, GRecaptchaParameters options);

  /// Gets the response for the reCAPTCHA widget.
  external String getResponse([int? widgetId]);

  /// Programmatically invoke the reCAPTCHA check. Used if the invisible
  /// reCAPTCHA is on a div instead of a button.
  ///
  /// [widgetId] is optional and defaults to the first widget created if
  /// unspecified.
  external void execute([int? widgetId]);

  /// Resets the reCAPTCHA widget.
  ///
  /// [widgetId] is optional and defaults to the first widget created if
  /// unspecified.
  external void reset([int? widgetId]);
}

@JS('grecaptcha')
@staticInterop
external GRecaptcha get grecaptcha;

@JS()
@anonymous
@staticInterop
class GRecaptchaParameters {
  external factory GRecaptchaParameters({
    String? sitekey,
    String? badge,
    String? theme,
    String? size,
    int? tabindex,
    JSFunction? callback,
    @JS('expired-callback') JSFunction? expiredCallback,
    @JS('error-callback') JSFunction? errorCallback,
  });
}

extension GRecaptchaParametersExtension on GRecaptchaParameters {
  /// The sitekey of your reCAPTCHA site.
  external String get sitekey;
  external set sitekey(String value);

  /// Reposition the reCAPTCHA badge. 'inline' lets you position it with CSS.
  ///
  /// Accepted values are: 'bottomright' (default), 'bottomleft', 'inline'.
  external String? get badge;
  external set badge(String? value);

  /// The color theme of the widget.
  ///
  /// Accepted values are: 'dark', 'light' (default).
  external String? get theme;
  external set theme(String? value);

  /// The size of the widget.
  ///
  /// Accepted values are: 'normal' (default), 'compact', 'invisible'.
  external String? get size;
  external set size(String? value);

  /// The tabindex of the widget and challenge.
  ///
  /// If other elements in your page use tabindex, it should be set to make user
  /// navigation easier.
  external int? get tabindex;
  external set tabindex(int? value);

  /// The callback function, executed when the user submits a successful
  /// response.
  ///
  /// The g-recaptcha-response token is passed to your callback.
  external JSFunction? get callback;
  external set callback(JSFunction? value);

  /// The callback function, executed when the reCAPTCHA response expires and
  /// the user needs to re-verify.
  @JS('expired-callback')
  external JSFunction? get expiredCallback;
  @JS('expired-callback')
  external set expiredCallback(JSFunction? value);

  /// The callback function, executed when reCAPTCHA encounters an error
  /// (usually network connectivity) and cannot continue until connectivity is
  /// restored.
  ///
  /// If you specify a function here, you are responsible for informing the user
  /// that they should retry.
  @JS('error-callback')
  external JSFunction? get errorCallback;
  @JS('error-callback')
  external set errorCallback(JSFunction? value);
}

GRecaptchaParameters createGRecaptchaParameters({
  String? sitekey,
  String? badge,
  String? theme,
  String? size,
  int? tabindex,
  JSFunction? callback,
  JSFunction? expiredCallback,
  JSFunction? errorCallback,
}) {
  return GRecaptchaParameters(
    sitekey: sitekey,
    badge: badge,
    theme: theme,
    size: size,
    tabindex: tabindex,
    callback: callback,
    expiredCallback: expiredCallback,
    errorCallback: errorCallback,
  );
}

// Type definitions for better type safety
typedef TokenCallback = void Function(String token);

// Helper functions for converting Dart functions to JSFunction
JSFunction tokenCallbackToJS(TokenCallback callback) {
  return (String token) {
    callback(token);
  }.toJS;
}

JSFunction voidCallbackToJS(void Function() callback) {
  return callback.toJS;
}

JSFunction errorCallbackToJS(void Function(Object error) callback) {
  return (JSAny error) {
    callback(error.dartify() ?? 'Unknown error');
  }.toJS;
}
