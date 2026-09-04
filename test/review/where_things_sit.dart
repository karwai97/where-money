import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Where a sentence sits. Review's criteria are about position — a complaint
/// under the field it is about rather than at the top of the screen — so the
/// assertion has to be read off the rendered tree. Shared by the English and
/// the Chinese tests, which make the same claims in two languages.
Rect rectOf(WidgetTester tester, Finder finder) => tester.getRect(finder.first);

/// A field reached by its label, which is the one thing a widget type is for.
Rect fieldNamed(WidgetTester tester, String label) =>
    rectOf(tester, find.widgetWithText(TextField, label));
