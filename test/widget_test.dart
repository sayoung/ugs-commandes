import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ugs_commandes/main.dart';
import 'package:ugs_commandes/providers/cart_provider.dart';

void main() {
  testWidgets('UgsApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CartProvider(),
        child: const UgsApp(),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
