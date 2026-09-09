import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Text as the screen draws it rather than as the message files hold it.
///
/// The name of a screen, of a field and of the one action a screen exists for
/// are all cased upper at the call site: upper case there is typography, not
/// wording, so the message files keep them in sentence case. These let a test
/// ask for the words as they are written and leave the casing to the drawing.
///
/// **English, and any other language with an upper case to go to.** A Chinese
/// mark is drawn exactly as it is written — `cased` in `on_screen.dart` says
/// why — so a Chinese test asks for it with a plain `find.text`. The two
/// finders agree on pure Chinese and disagree the moment a label carries the
/// app's own name.
Finder markSaying(String words) => find.text(words.toUpperCase());

/// A field reached by its own name, which is the one thing a widget type is
/// for. The name is drawn beside the input rather than inside it, and stays a
/// descendant of the field so that this still finds it.
Finder fieldCalled(String label) =>
    find.widgetWithText(TextField, label.toUpperCase());
