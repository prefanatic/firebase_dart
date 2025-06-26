// ignore_for_file: constant_identifier_names, non_constant_identifier_names

@JS()
library iframewrapper;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math';

import 'package:web/web.dart';

import 'gapi.dart' as gapi;
import 'gapi_iframes.dart' as gapi;
import 'gapi_iframes.dart';
import 'util.dart' as util;

/// Defines the hidden iframe wrapper for cross origin communications.
class IframeWrapper {
  /// The hidden iframe URL.
  final String url;

  late gapi.Iframe _iframe;

  /// A future that resolves on iframe open.
  late final Future<void> _onIframeOpen = _open();

  IframeWrapper(this.url);

  /// The future that resolves when the iframe is ready.
  Future<void> get onReady => _onIframeOpen;

  /// Opens an iframe.
  Future<void> _open() async {
    return IframeWrapper._loadGApiJs().then((_) {
      var completer = Completer<void>();

      var container = HTMLDivElement();
      document.body!.append(container);
      gapi.getContext().open(
            createIframeOptions(
              url,
              container,
              createIframeAttributes(
                document.body!.style
                  ..position = 'absolute'
                  ..top = '-100px'
                  ..width = '1px'
                  ..height = '1px',
              ),
              gapi.CROSS_ORIGIN_IFRAMES_FILTER,
              true,
            ),
            ((gapi.Iframe iframe) {
              _iframe = iframe;
              // Prevent iframe from closing on mouse out.
              _iframe.restyle(createIframeRestyleOptions(false));

              // Set up timeout timer
              final timeoutTimer = Timer(PING_TIMEOUT_.get(), () {
                completer.completeError(Exception('Network Error'));
              });

              // Handle the IThenable directly
              iframe.ping().then(
                    ((JSAny _) {
                      timeoutTimer.cancel();
                      completer.complete();
                    }).toJS,
                    ((JSAny _) {
                      timeoutTimer.cancel();
                      completer.completeError(Exception('Network Error'));
                    }).toJS,
                  );
            }).toJS,
          );
      return completer.future.then((_) => print('completed'));
    });
  }

  Future<Map<String, dynamic>?> sendMessage(Message message) {
    return _onIframeOpen.then((_) {
      var completer = Completer<Map<String, dynamic>?>();

      // Create a JS-compatible callback function
      void jsCallback(JSAny? response) {
        try {
          if (response != null) {
            // Convert JSAny to Map<String, dynamic>
            final dartMap = _convertJSObjectToDartMap(response);
            completer.complete(dartMap);
          } else {
            completer.complete(null);
          }
        } catch (e) {
          completer.completeError(e);
        }
      }

      _iframe.send(
        message.type,
        (() {
          final obj = JSObject();
          obj.setProperty('type'.toJS, message.type.toJS);
          return obj;
        })(),
        jsCallback.toJS, // This is now JS-compatible
        gapi.CROSS_ORIGIN_IFRAMES_FILTER,
      );

      return completer.future;
    });
  }

  /// Converts JS object to Dart Map.
  Map<String, dynamic>? _convertJSObjectToDartMap(JSAny jsObject) {
    if (jsObject.isNull || jsObject.isUndefined) {
      return null;
    }

    // Convert JS object to Dart Map
    return (jsObject as JSObject).dartify() as Map<String, dynamic>?;
  }

  final Expando<JSFunction> _handlers = Expando();

  /// Registers a listener to a post message.
  void registerEvent(String eventName,
      IframeEventHandlerResponse Function(IframeEvent) handler) {
    _onIframeOpen.then((_) {
      var h = _handlers[handler] ??= ((JSAny event, JSAny iframe) {
        // Convert JS objects back to Dart types
        final dartEvent = event as IframeEvent;
        return handler(dartEvent);
      }).toJS;
      _iframe.register(eventName, h, gapi.CROSS_ORIGIN_IFRAMES_FILTER);
    });
  }

  /// Unregisters a listener to a post message.
  void unregisterEvent(String eventName, Function(dynamic) handler) {
    _onIframeOpen.then((_) {
      _iframe.unregister(eventName, _handlers[handler]!);
    });
  }

  /// The GApi loader URL.
  static const GAPI_LOADER_SRC_ = 'https://apis.google.com/js/api.js';

  /// The gapi.load network error timeout delay with units in ms.
  static final NETWORK_TIMEOUT_ =
      util.Delay(Duration(seconds: 30), Duration(seconds: 60));

  /// The iframe ping error timeout delay with units in ms.
  static final PING_TIMEOUT_ =
      util.Delay(Duration(seconds: 5), Duration(seconds: 15));

  /// The cached GApi loader promise.
  static dynamic _cachedGApiLoader;

  /// Resets the cached GApi loader.
  static void resetCachedGApiLoader() {
    IframeWrapper._cachedGApiLoader = null;
  }

  static final _random = Random();

  /// Loads the GApi client library if it is not loaded for gapi.iframes usage.
  static Future<void> _loadGApiJs() {
    return IframeWrapper._cachedGApiLoader ??= Future(() async {
      var completer = Completer<void>();

      // Function to run when gapi.load is ready.
      void onGapiLoad() {
        // The developer may have tried to previously run gapi.load and failed.
        // Run this to fix that.
        // TODO fireauth.util.resetUnloadedGapiModules();

        gapi.load(
          'gapi.iframes',
          gapi.LoadConfig(
            callback: (() {
              completer.complete();
            }).toJS,
            ontimeout: (() {
              // The above reset may be sufficient, but having this reset after
              // failure ensures that if the developer calls gapi.load after the
              // connection is re-established and before another attempt to embed
              // the iframe, it would work and would not be broken because of our
              // failed attempt.
              // Timeout when gapi.iframes.Iframe not loaded.
              // TODO: fireauth.util.resetUnloadedGapiModules();
              completer.completeError(Exception('Network Error'));
            }).toJS,
            timeout: 30000,
          ),
        );
      }

      if (util.getObjectRef('gapi.iframes.Iframe') != null) {
        // If gapi.iframes.Iframe available, resolve.
        completer.complete();
      } else if (util.getObjectRef('gapi.load') != null) {
        // Gapi loader ready, load gapi.iframes.
        onGapiLoad();
      } else {
        // Create a new iframe callback when this is called so as not to overwrite
        // any previous defined callback. This happens if this method is called
        // multiple times in parallel and could result in the later callback
        // overwriting the previous one. This would end up with a iframe
        // timeout.
        var cbName = '__iframefcb${_random.nextInt(1000000)}';
        // GApi loader not available, dynamically load platform.js.
        util.globalThis.setProperty(
          cbName.toJS,
          () {
            // GApi loader should be ready.
            if (util.getObjectRef('gapi.load') != null) {
              onGapiLoad();
            } else {
              // Gapi loader failed, throw error.
              completer.completeError(Exception('Network Error'));
            }
          }.toJS,
        );
        // Build GApi loader.
        var url = Uri.parse(IframeWrapper.GAPI_LOADER_SRC_)
            .replace(queryParameters: {'onload': cbName});
        // Load GApi loader.
        var script = HTMLScriptElement()..src = url.toString();
        document.body!.append(script);
      }

      return completer.future;
    }).catchError((error) {
      // Reset cached promise to allow for retrial.
      IframeWrapper._cachedGApiLoader = null;
      throw error;
    });
  }
}

class Message {
  final String type;

  Message({required this.type});
}
