import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ugs_commandes/widgets/network_error_view.dart';

void main() {
  testWidgets(
    'affiche le message d\'erreur, le bouton Réessayer et l\'icône wifi_off',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NetworkErrorView(
              message: 'Connexion impossible',
              onRetry: () {},
            ),
          ),
        ),
      );

      expect(find.text('Connexion impossible'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    },
  );

  testWidgets('incrémente le compteur lors du tap sur Réessayer', (
    WidgetTester tester,
  ) async {
    int retryCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NetworkErrorView(
            message: 'Connexion impossible',
            onRetry: () {
              retryCount++;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Réessayer'));
    await tester.pump();

    expect(retryCount, 1);
  });
}
