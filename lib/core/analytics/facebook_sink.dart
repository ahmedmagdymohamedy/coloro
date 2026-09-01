import 'dart:io';

import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/foundation.dart';

import 'meta_events.dart';

/// Sends [MetaEvents] to Meta through the Facebook SDK.
///
/// **Android only, deliberately.** [isSupported] gates it, and the native
/// credentials only exist on the Android side —
/// `android/app/src/main/res/values/strings.xml` plus two `meta-data`
/// entries in the manifest, with no matching keys in `ios/Runner/Info.plist`.
/// With no app id to read, the SDK never initialises on iOS.
///
/// That is not an oversight. `ios/Runner/Info.plist` records that App Store
/// Connect **already refused a submission of this app** over tracking
/// signals, and the fix was removing `NSUserTrackingUsageDescription`
/// entirely. The Facebook SDK reintroduces exactly that class of signal, so
/// switching it on for iOS needs a real ATT + UMP consent flow and its own
/// submission — not a quiet dependency bump.
class FacebookSink implements MetaEventSink {
  FacebookSink._(this._fb);

  final FacebookAppEvents _fb;

  /// Whether this build should talk to Meta at all.
  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  /// Returns null on any platform that must not initialise the SDK, so
  /// callers can wire this up unconditionally.
  static FacebookSink? createIfSupported() {
    if (!isSupported) return null;
    try {
      return FacebookSink._(FacebookAppEvents());
    } catch (e) {
      debugPrint('Facebook SDK unavailable: $e');
      return null;
    }
  }

  @override
  void logEvent(String name, Map<String, Object> parameters) {
    _fb.logEvent(name: name, parameters: parameters);
  }
}
