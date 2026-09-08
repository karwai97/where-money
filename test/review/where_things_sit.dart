import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../as_drawn.dart';

/// Where a sentence sits. Review's criteria are about position — a complaint
/// under the field it is about rather than at the top of the screen — so the
/// assertion has to be read off the rendered tree. Shared by the English and
/// the Chinese tests, which make the same claims in two languages.
Rect rectOf(WidgetTester tester, Finder finder) => tester.getRect(finder.first);

/// Where a field sits, reached by its own name. See [fieldCalled] for why the
/// caller passes the name as it is written rather than as it is drawn.
Rect fieldNamed(WidgetTester tester, String label) =>
    rectOf(tester, fieldCalled(label));
