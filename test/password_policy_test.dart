import 'package:collab/core/password_policy.dart';
import 'package:collab/core/password_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new passwords reject short, overlong and simple repeated values', () {
    for (final value in [
      '',
      'short',
      'password123456789',
      'aaaaaaaaaaaaaaaa',
      'abcabcabcabcabcabc',
      'x' * 129,
    ]) {
      expect(PasswordPolicy.validate(value), isNotNull);
    }
  });
  test('passphrases and spaces are accepted without forced symbols', () {
    expect(PasswordPolicy.validate('planet'), isNull);
    expect(PasswordPolicy.validate('velvet lantern meadow river'), isNull);
    expect(PasswordPolicy.score('velvet lantern meadow river'), 4);
    expect(PasswordPolicy.validate('春天山川河流星空森林海洋白云花草月光'), isNull);
    expect(
      PasswordPolicy.validate('A longer unique phrase with spaces'),
      isNull,
    );
  });
  test('strength reflects empty, weak and longer passwords', () {
    expect(PasswordPolicy.score(''), 0);
    expect(PasswordPolicy.score('123'), 1);
    expect(PasswordPolicy.score('amber maple fog'), 2);
    expect(PasswordPolicy.score('silver meadow lantern'), 3);
  });
  testWidgets('bar and checklist update during typing and visibility toggles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(child: LqNewPasswordField(controller: controller)),
          ),
        ),
      ),
    );
    expect(find.text('Password strength: Not entered'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'short');
    await tester.pump();
    expect(find.text('Password strength: Weak'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField),
      'velvet lantern meadow river',
    );
    await tester.pump();
    expect(find.text('Password strength: Strong'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      1,
    );
    expect(tester.widget<TextField>(find.byType(TextField)).obscureText, true);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).obscureText, false);
    expect(tester.takeException(), isNull);
  });
}
