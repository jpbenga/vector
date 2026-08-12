import 'package:flutter/widgets.dart';

class LocalizedLabel {
  const LocalizedLabel({required this.fr, required this.en});

  final String fr;
  final String en;

  String resolve(Locale locale) {
    return locale.languageCode == 'en' ? en : fr;
  }
}
