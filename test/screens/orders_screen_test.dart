import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ugs_commandes/i18n/app_i18n.dart';
import 'package:ugs_commandes/screens/orders_screen.dart';
import 'package:ugs_commandes/services/dolibarr_api.dart';

class FakeDolibarrApiService extends DolibarrApiService {
  FakeDolibarrApiService({
    this.orders = const <Map<String, dynamic>>[],
    this.shouldThrow = false,
    this.errorMessage = 'Erreur serveur API',
    this.statusCode = 500,
    this.delay = Duration.zero,
  }) : super(apiKey: 'test-key');

  List<Map<String, dynamic>> orders;
  bool shouldThrow;
  String errorMessage;
  int statusCode;
  Duration delay;
  int getOrdersCallCount = 0;

  @override
  Future<List<Map<String, dynamic>>> getClientOrders(int socid, {int? status}) async {
    getOrdersCallCount++;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (shouldThrow) {
      throw ApiException(errorMessage, statusCode);
    }
    if (status != null) {
      final filtered = <Map<String, dynamic>>[];
      for (final o in orders) {
        final s = int.tryParse(o['statut']?.toString() ?? o['status']?.toString() ?? '-99');
        if (s == status) {
          filtered.add(o);
        }
      }
      return filtered;
    }
    return orders;
  }
}

void main() {
  setUp(() {
    AppI18n.setLocale('fr');
  });

  final date1 = DateTime(2026, 11, 14, 10, 0);
  final date2 = DateTime(2026, 11, 10, 15, 30);
  final date3 = DateTime(2026, 11, 12, 18, 45);

  final sampleOrdersWithDrafts = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 22,
      'ref': '(PROV22)',
      'date_commande': date1.millisecondsSinceEpoch ~/ 1000,
      'total_ttc': 13464.00,
      'statut': 0,
    },
    <String, dynamic>{
      'id': 15,
      'ref': '(PROV15)',
      'date_commande': date2.millisecondsSinceEpoch ~/ 1000,
      'total_ttc': 8400.00,
      'statut': 0,
    },
    <String, dynamic>{
      'id': 30,
      'ref': 'SO2611-0028',
      'date_commande': date3.millisecondsSinceEpoch ~/ 1000,
      'total_ttc': 1200.00,
      'statut': 1,
    },
  ];

  Widget buildOrdersScreen({
    required DolibarrApiService api,
    int clientId = 1,
    List<Map<String, dynamic>>? initialOrders,
    String? initialLocale,
  }) {
    return MaterialApp(
      home: OrdersScreen(
        api: api,
        clientId: clientId,
        initialOrders: initialOrders,
        initialLocale: initialLocale,
      ),
    );
  }

  group('OrdersScreen - Affichage et filtrage des brouillons', () {
    testWidgets('affiche les brouillons et les commandes validées dans la vue Toutes', (tester) async {
      final fakeApi = FakeDolibarrApiService(orders: sampleOrdersWithDrafts);
      await tester.pumpWidget(buildOrdersScreen(api: fakeApi));
      await tester.pumpAndSettle();

      // Check all 3 orders are present
      expect(find.text('Cmd #(PROV22)'), findsOneWidget);
      expect(find.text('Cmd #(PROV15)'), findsOneWidget);
      expect(find.text('Cmd #SO2611-0028'), findsOneWidget);

      // Check drafts have "Brouillon" label
      expect(find.text('Brouillon'), findsNWidgets(2));
      // Check validated has "Validée" label
      expect(find.text('Validée'), findsOneWidget);

      // Check draft amounts
      expect(find.text('13464.00 DH TTC'), findsOneWidget);
      expect(find.text('8400.00 DH TTC'), findsOneWidget);
      expect(find.text('1200.00 DH TTC'), findsOneWidget);

      // Check filter chips header
      expect(find.text('Toutes (3)'), findsOneWidget);
      expect(find.text('Brouillons (2)'), findsOneWidget);
      expect(find.text('Validées (1)'), findsOneWidget);
    });

    testWidgets('filtrer par Brouillons affiche uniquement les commandes brouillons', (tester) async {
      final fakeApi = FakeDolibarrApiService(orders: sampleOrdersWithDrafts);
      await tester.pumpWidget(buildOrdersScreen(api: fakeApi));
      await tester.pumpAndSettle();

      // Tap on Brouillons filter chip
      await tester.tap(find.text('Brouillons (2)'));
      await tester.pumpAndSettle();

      // Only draft orders are visible
      expect(find.text('Cmd #(PROV22)'), findsOneWidget);
      expect(find.text('Cmd #(PROV15)'), findsOneWidget);
      expect(find.text('Cmd #SO2611-0028'), findsNothing);

      // Tap on Toutes to restore all orders
      await tester.tap(find.text('Toutes (3)'));
      await tester.pumpAndSettle();

      expect(find.text('Cmd #(PROV22)'), findsOneWidget);
      expect(find.text('Cmd #(PROV15)'), findsOneWidget);
      expect(find.text('Cmd #SO2611-0028'), findsOneWidget);
    });

    testWidgets('affiche l’état vide "Aucun brouillon" quand il n’y a aucun brouillon', (tester) async {
      final ordersWithoutDrafts = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 30,
          'ref': 'SO2611-0028',
          'date_commande': date3.millisecondsSinceEpoch ~/ 1000,
          'total_ttc': 1200.00,
          'statut': 1,
        },
      ];

      final fakeApi = FakeDolibarrApiService(orders: ordersWithoutDrafts);
      await tester.pumpWidget(buildOrdersScreen(api: fakeApi));
      await tester.pumpAndSettle();

      expect(find.text('Toutes (1)'), findsOneWidget);
      expect(find.text('Brouillons'), findsOneWidget);

      // Filter by Brouillons
      await tester.tap(find.text('Brouillons'));
      await tester.pumpAndSettle();

      // Displays empty drafts message
      expect(find.text(AppI18n.t('orders_empty_drafts')), findsOneWidget);
      expect(find.text(AppI18n.t('orders_empty_drafts_hint')), findsOneWidget);
      expect(find.byIcon(Icons.drafts_outlined), findsOneWidget);
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('affiche l’état vide "Aucune commande" si aucune commande n’existe', (tester) async {
      final fakeApi = FakeDolibarrApiService(orders: const <Map<String, dynamic>>[]);
      await tester.pumpWidget(buildOrdersScreen(api: fakeApi));
      await tester.pumpAndSettle();

      expect(find.text(AppI18n.t('orders_empty_list')), findsOneWidget);
      expect(find.text(AppI18n.t('orders_empty_list_hint')), findsOneWidget);
      expect(find.byIcon(Icons.list_alt_outlined), findsOneWidget);
    });

    testWidgets('filtrer par Validées affiche uniquement les commandes validées', (tester) async {
      final fakeApi = FakeDolibarrApiService(orders: sampleOrdersWithDrafts);
      await tester.pumpWidget(buildOrdersScreen(api: fakeApi));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Validées (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Cmd #SO2611-0028'), findsOneWidget);
      expect(find.text('Cmd #(PROV22)'), findsNothing);
      expect(find.text('Cmd #(PROV15)'), findsNothing);
    });
  });

  group('OrdersScreen - Gestion des erreurs et réessai', () {
    testWidgets('affiche l’état d’erreur et permet de réessayer avec succès', (tester) async {
      final fakeApi = FakeDolibarrApiService(
        orders: sampleOrdersWithDrafts,
        shouldThrow: true,
        errorMessage: 'Échec de connexion réseau',
      );

      await tester.pumpWidget(buildOrdersScreen(api: fakeApi));
      await tester.pumpAndSettle();

      // Error message is displayed
      expect(find.text(AppI18n.t('orders_error_title')), findsOneWidget);
      expect(find.text('Échec de connexion réseau'), findsOneWidget);
      expect(find.byType(Card), findsNothing);

      // Retry button is available
      final retryBtn = find.widgetWithText(FilledButton, AppI18n.t('orders_retry'));
      expect(retryBtn, findsOneWidget);

      // Fix API and tap retry
      fakeApi.shouldThrow = false;
      await tester.tap(retryBtn);
      await tester.pumpAndSettle();

      // Orders are now loaded
      expect(find.text('Cmd #(PROV22)'), findsOneWidget);
      expect(find.text('Cmd #SO2611-0028'), findsOneWidget);
    });

    testWidgets('désactive les boutons d’action pendant le chargement (pas de double envoi)', (tester) async {
      final fakeApi = FakeDolibarrApiService(
        orders: sampleOrdersWithDrafts,
        delay: const Duration(seconds: 1),
      );

      await tester.pumpWidget(buildOrdersScreen(api: fakeApi));
      await tester.pump(); // Pump first frame without settling

      // Loading spinner and text are present
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(AppI18n.t('orders_loading')), findsOneWidget);

      // Refresh button in AppBar is disabled
      final refreshBtn = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.refresh),
      );
      expect(refreshBtn.onPressed, isNull);

      // Settle loading
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Cmd #(PROV22)'), findsOneWidget);
    });
  });

  group('OrdersScreen - Accessibilité et i18n', () {
    testWidgets('dispose de libellés sémantiques complets sur les cartes de brouillons', (tester) async {
      final fakeApi = FakeDolibarrApiService(orders: sampleOrdersWithDrafts);
      await tester.pumpWidget(buildOrdersScreen(api: fakeApi));
      await tester.pumpAndSettle();

      // Check semantics on card for PROV22
      final cardSemantics = find.byWidgetPredicate((w) {
        if (w is Semantics && w.properties.label != null) {
          final label = w.properties.label ?? '';
          return label.contains('(PROV22)') && label.contains('Brouillon');
        }
        return false;
      });
      expect(cardSemantics, findsOneWidget);

      // Check semantics on refresh button
      final refreshSemantics = find.byWidgetPredicate((w) {
        if (w is Semantics && w.properties.label != null) {
          return w.properties.label == AppI18n.t('orders_refresh');
        }
        return false;
      });
      expect(refreshSemantics, findsOneWidget);
    });

    testWidgets('affiche l’écran en arabe (ar) sans chaînes en dur', (tester) async {
      final fakeApi = FakeDolibarrApiService(orders: sampleOrdersWithDrafts);
      await tester.pumpWidget(buildOrdersScreen(api: fakeApi, initialLocale: 'ar'));
      await tester.pumpAndSettle();

      expect(find.text(AppI18n.t('orders_title', locale: 'ar')), findsOneWidget);
      expect(find.text('مسودة'), findsNWidgets(2));
      expect(find.text('طلب #(PROV22)'), findsOneWidget);
      expect(find.text('المسودات (2)'), findsOneWidget);
      expect(find.text('الكل (3)'), findsOneWidget);
    });

    testWidgets('affiche l’écran en anglais (en) sans chaînes en dur', (tester) async {
      final fakeApi = FakeDolibarrApiService(orders: sampleOrdersWithDrafts);
      await tester.pumpWidget(buildOrdersScreen(api: fakeApi, initialLocale: 'en'));
      await tester.pumpAndSettle();

      expect(find.text(AppI18n.t('orders_title', locale: 'en')), findsOneWidget);
      expect(find.text('Draft'), findsNWidgets(2));
      expect(find.text('Order #(PROV22)'), findsOneWidget);
      expect(find.text('Drafts (2)'), findsOneWidget);
      expect(find.text('All (3)'), findsOneWidget);
    });
  });
}
