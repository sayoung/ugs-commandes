import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ugs_commandes/i18n/app_i18n.dart';
import 'package:ugs_commandes/models/order.dart';

void main() {
  setUp(() {
    AppI18n.setLocale('fr');
  });

  group('OrderModel parsing and attributes', () {
    test('correctly parses a draft order with statut 0', () {
      final data = <String, dynamic>{
        'id': 22,
        'ref': '(PROV22)',
        'date_commande': 1791417600,
        'total_ttc': 13464.00,
        'statut': 0,
      };

      final order = OrderModel.tryFromMap(data);
      expect(order, isNotNull);
      expect(order?.id, 22);
      expect(order?.ref, '(PROV22)');
      expect(order?.status, 0);
      expect(order?.isDraft, isTrue);
      expect(order?.totalTtc, 13464.00);
      expect(order?.date, isNotNull);
      expect(order?.statusColor, Colors.orange);
      expect(order?.getStatusLabel('fr'), 'Brouillon');
      expect(order?.getStatusLabel('ar'), 'مسودة');
      expect(order?.getStatusLabel('en'), 'Draft');
    });

    test('correctly parses a draft order with string statut "0"', () {
      final data = <String, dynamic>{
        'id': '15',
        'ref': '(PROV15)',
        'date': '1776297600',
        'total_ttc': '8400.00',
        'statut': '0',
      };

      final order = OrderModel.tryFromMap(data);
      expect(order, isNotNull);
      expect(order?.id, 15);
      expect(order?.ref, '(PROV15)');
      expect(order?.status, 0);
      expect(order?.isDraft, isTrue);
      expect(order?.totalTtc, 8400.00);
    });

    test('correctly parses a validated order with status 1', () {
      final data = <String, dynamic>{
        'id': 1,
        'ref': 'SO2509-0001',
        'date_commande': 1757548800,
        'total_ttc': 13920.00,
        'statut': 1,
      };

      final order = OrderModel.tryFromMap(data);
      expect(order, isNotNull);
      expect(order?.id, 1);
      expect(order?.ref, 'SO2509-0001');
      expect(order?.status, 1);
      expect(order?.isDraft, isFalse);
      expect(order?.statusColor, Colors.blue);
      expect(order?.getStatusLabel('fr'), 'Validée');
      expect(order?.getStatusLabel('ar'), 'مؤكدة');
      expect(order?.getStatusLabel('en'), 'Validated');
    });

    test('fallback to date_creation when date_commande and date are null', () {
      final data = <String, dynamic>{
        'id': 35,
        'ref': '(PROV35)',
        'date_creation': 1760000000,
        'total_ttc': 500.0,
        'statut': 0,
      };

      final order = OrderModel.tryFromMap(data);
      expect(order, isNotNull);
      expect(order?.date, isNotNull);
      expect(order?.isDraft, isTrue);
    });

    test('handles null dates gracefully without error', () {
      final data = <String, dynamic>{
        'id': 40,
        'ref': '(PROV40)',
        'total_ttc': 0.0,
        'statut': 0,
      };

      final order = OrderModel.tryFromMap(data);
      expect(order, isNotNull);
      expect(order?.date, isNull);
      expect(order?.formattedDate(), '');
    });

    test('returns null for non-map input safely', () {
      expect(OrderModel.tryFromMap(null), isNull);
      expect(OrderModel.tryFromMap('invalid string'), isNull);
      expect(OrderModel.tryFromMap(123), isNull);
      expect(OrderModel.tryFromMap(<dynamic>[]), isNull);
    });

    test('handles unknown and cancelled statuses', () {
      final cancelled = OrderModel.tryFromMap(<String, dynamic>{'id': 1, 'statut': -1});
      expect(cancelled?.statusColor, Colors.red);
      expect(cancelled?.getStatusLabel('fr'), 'Annulée');

      final shipped = OrderModel.tryFromMap(<String, dynamic>{'id': 2, 'statut': 2});
      expect(shipped?.statusColor, Colors.purple);
      expect(shipped?.getStatusLabel('fr'), 'Expédiée');

      final delivered = OrderModel.tryFromMap(<String, dynamic>{'id': 3, 'statut': 3});
      expect(delivered?.statusColor, Colors.green);
      expect(delivered?.getStatusLabel('fr'), 'Livrée');

      final unknown = OrderModel.tryFromMap(<String, dynamic>{'id': 4, 'statut': 99});
      expect(unknown?.statusColor, Colors.grey);
      expect(unknown?.getStatusLabel('fr'), 'Inconnu');
    });
  });
}
