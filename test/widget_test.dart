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

  testWidgets('add spot requires a photo before posting', (tester) async {
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
    await tester.tap(find.text('Claim 75 XP'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Add a photo before posting.'), findsOneWidget);
    expect(find.text('AI Scanner'), findsOneWidget);
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
  await tester.tap(find.text('Enter Racers Vault'));
  await tester.pumpAndSettle();
}
