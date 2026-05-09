import 'package:flutter/material.dart';
import 'lib/widgets/assistant_text_helpers.dart';

void main() {
  final ejercicios = ['4 series de 10 reps'];
  final w = <Widget>[];
  for (final raw in expandItemLines(ejercicios)) {
    print('raw: $raw');
    if (isAssistantSubheader(raw)) {
      print('is subheader');
      w.add(Container());
    } else {
      print('is bullet');
      w.add(Container());
    }
  }
  print('w.isNotEmpty: ${w.isNotEmpty}');
}
