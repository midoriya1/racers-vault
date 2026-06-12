import 'package:car_vault/app.dart';
import 'package:car_vault/services/vault_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Racers Vault feed shows sample spots', (tester) async {
    await tester.pumpWidget(
      RacersVaultApp(repository: InMemoryVaultRepository()),
    );
    await enterPrototypeApp(tester);

    expect(find.text('Racers Vault'), findsOneWidget);
    expect(find.text('Ferrari 812 Superfast'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Porsche 911 GT3 RS'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Porsche 911 GT3 RS'), findsOneWidget);
  });

  testWidgets('add spot requires a verified photo before posting', (
    tester,
  ) async {
    await tester.pumpWidget(
      RacersVaultApp(repository: InMemoryVaultRepository()),
    );
    await enterPrototypeApp(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('AI Scanner'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Vault note'),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Vault note'),
      'Saw it near the cafe.',
    );
    final claimButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Claim 75 XP'),
    );

    expect(claimButton.onPressed, isNull);
    expect(find.text('AI Scanner'), findsOneWidget);
  });

  testWidgets('editing profile keeps moderator tools visible', (tester) async {
    await tester.pumpWidget(
      RacersVaultApp(repository: InMemoryVaultRepository()),
    );
    await enterPrototypeApp(tester);

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    expect(find.text('Open mod console'), findsOneWidget);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Bio'),
      'Weekend garage hunter',
    );
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -320));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save profile'));
    await tester.pumpAndSettle();

    expect(find.text('Open mod console'), findsOneWidget);
    expect(find.text('Weekend garage hunter'), findsOneWidget);
  });
}

Future<void> enterPrototypeApp(WidgetTester tester) async {
  await tester.pumpAndSettle();
  expect(find.text('Create your spotter profile'), findsOneWidget);

  await tester.enterText(
    find.widgetWithText(TextFormField, 'Username'),
    'Riya',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Country'),
    'India',
  );
  await tester.enterText(find.widgetWithText(TextFormField, 'City'), 'Mumbai');
  await tester.drag(find.byType(Scrollable).first, const Offset(0, -260));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Enter Racers Vault'));
  await tester.pumpAndSettle();
}
