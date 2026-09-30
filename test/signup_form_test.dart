import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pulse_app/data/pulse_store.dart';
import 'package:pulse_app/screens/auth/auth_screens.dart';
import 'package:pulse_app/theme/pulse_theme.dart';

/// ═══════════════════════════════════════════════════════════════════
/// Sign-up form behaviour (§75 validation posture).
/// The state-matrix sweep proves screens build; it never types into
/// one. These cases drive the form the way a person does, which is how
/// the permanent spinner and the errors-before-input were missed.
/// ═══════════════════════════════════════════════════════════════════

Widget _host(PulseStore store) => PulseScope(
      store: store,
      child: MaterialApp(
        theme: PulseTheme.light(),
        home: const SignUpScreen(),
        routes: {
          '/onboarding-goals': (_) =>
              const Scaffold(body: Text('onboarding reached')),
          '/login': (_) => const Scaffold(body: Text('login reached')),
        },
      ),
    );

/// Brings the submit button into view; the form is taller than the default
/// 800x600 test surface.
Future<void> _tapCreate(WidgetTester tester) async {
  final button = find.text('Create Account');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('sign-up validation posture', () {
    testWidgets('an untouched form shows no errors', (tester) async {
      await tester.pumpWidget(_host(PulseStore()));
      await tester.pumpAndSettle();
      // Arriving at a form having done nothing wrong must not read as failure.
      expect(find.text('Enter your email address'), findsNothing);
      expect(find.text('Create a password'), findsNothing);
      expect(find.text('Please accept the Terms and Privacy Policy to continue.'),
          findsNothing);
    });

    testWidgets('submitting an empty form reveals what is missing',
        (tester) async {
      await tester.pumpWidget(_host(PulseStore()));
      await tester.pumpAndSettle();
      await _tapCreate(tester);
      expect(find.text('Enter your email address'), findsOneWidget);
      expect(find.text('Create a password'), findsOneWidget);
      expect(find.text('Please accept the Terms and Privacy Policy to continue.'),
          findsOneWidget);
    });

    testWidgets('a short password is named as the problem', (tester) async {
      await tester.pumpWidget(_host(PulseStore()));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextField).first, 'someone@example.com');
      await tester.enterText(find.byType(TextField).last, 'abc123');
      await _tapCreate(tester);
      expect(find.text('Use at least 8 characters'), findsOneWidget);
    });

    testWidgets('an invalid submit leaves no spinner running', (tester) async {
      await tester.pumpWidget(_host(PulseStore()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'abc123');
      await _tapCreate(tester);
      // The regression: _submitting doubled as "user tried", so a rejected
      // attempt span forever and the label never came back.
      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: 'a rejected attempt must not spin');
      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('errors clear as the user corrects them', (tester) async {
      await tester.pumpWidget(_host(PulseStore()));
      await tester.pumpAndSettle();
      await _tapCreate(tester);
      expect(find.text('Enter your email address'), findsOneWidget);
      await tester.enterText(
          find.byType(TextField).first, 'someone@example.com');
      await tester.pumpAndSettle();
      expect(find.text('Enter your email address'), findsNothing);
    });

    testWidgets('a complete form reaches onboarding', (tester) async {
      await tester.pumpWidget(_host(PulseStore()));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextField).first, 'someone@example.com');
      await tester.enterText(find.byType(TextField).last, 'longenough1');
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create Account'));
      await tester.pump(); // spinner frame
      expect(find.byType(CircularProgressIndicator), findsOneWidget,
          reason: 'a real submit does show progress');
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('onboarding reached'), findsOneWidget);
    });

    testWidgets('the microcopy never blames the user (§85)', (tester) async {
      await tester.pumpWidget(_host(PulseStore()));
      await tester.pumpAndSettle();
      await _tapCreate(tester);
      for (final w in tester.widgetList<Text>(find.byType(Text))) {
        final t = (w.data ?? '').toLowerCase();
        expect(t, isNot(contains('fail')));
        expect(t, isNot(contains('invalid input')));
        expect(t, isNot(contains('wrong')));
      }
    });
  });
}
