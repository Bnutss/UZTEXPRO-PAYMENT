import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

/// The system spell check of iOS (UITextChecker) for the message field.
///
/// Flutter's own iOS spell check uses the language of the app, which has no
/// dictionary for e.g. Uzbek, so nothing was underlined. This one finds out the
/// language of what is written and checks with that dictionary; words in a
/// language the system does not know are left alone.
class IosSpellCheckService implements SpellCheckService {
  static const _channel = MethodChannel('uztexpro/spellcheck');

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(
    Locale locale,
    String text,
  ) async {
    try {
      final raw = await _channel.invokeListMethod<Map>('check', text);
      return [
        for (final m in raw ?? const <Map>[])
          SuggestionSpan(
            TextRange(
              start: (m['start'] as num).toInt(),
              end: (m['end'] as num).toInt(),
            ),
            ((m['suggestions'] as List?) ?? const []).cast<String>(),
          ),
      ];
    } catch (e) {
      // Visible in the console when the native side is missing (not rebuilt).
      debugPrint('spellcheck: $e');
      return const [];
    }
  }
}

/// The configuration for the field: red dotted underline and the iOS
/// suggestions menu on a tap. Null off iOS.
SpellCheckConfiguration? chatSpellCheck() {
  if (!Platform.isIOS) return null;
  return CupertinoTextField.inferIOSSpellCheckConfiguration(
    SpellCheckConfiguration(spellCheckService: IosSpellCheckService()),
  );
}
