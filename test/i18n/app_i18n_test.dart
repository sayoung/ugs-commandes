import 'package:flutter_test/flutter_test.dart';
import 'package:ugs_commandes/i18n/app_i18n.dart';

void main() {
  setUp(() {
    AppI18n.setLocale('fr');
  });

  group('AppI18n translation coverage', () {
    const requiredKeys = <String>[
      'orders_title',
      'orders_refresh',
      'orders_loading',
      'orders_error_title',
      'orders_error_generic',
      'orders_retry',
      'orders_empty_list',
      'orders_empty_list_hint',
      'orders_empty_drafts',
      'orders_empty_drafts_hint',
      'orders_filter_all',
      'orders_filter_drafts',
      'orders_filter_validated',
      'orders_filter_shipped',
      'orders_filter_delivered',
      'orders_filter_semantics',
      'orders_order_prefix',
      'orders_currency',
      'orders_semantic_card',
      'status_draft',
      'status_validated',
      'status_shipped',
      'status_delivered',
      'status_cancelled',
      'status_unknown',
      'language_tooltip',
      'language_fr',
      'language_ar',
      'language_en',
      'draft_badge_label',
    ];

    test('all required keys exist in fr, ar and en without missing keys', () {
      for (final locale in AppI18n.supportedLocales) {
        for (final key in requiredKeys) {
          expect(
            AppI18n.hasKey(key, locale: locale),
            isTrue,
            reason: 'Key "$key" should be present in locale "$locale"',
          );
          final text = AppI18n.t(key, locale: locale);
          expect(text, isNotEmpty);
          expect(text, isNot(equals(key)));
        }
      }
    });

    test('substitutes parameters correctly in templates', () {
      final res = AppI18n.t(
        'orders_filter_semantics',
        locale: 'fr',
        params: {'filter': 'Brouillons'},
      );
      expect(res, 'Filtrer les commandes par : Brouillons');

      final cardRes = AppI18n.t(
        'orders_semantic_card',
        locale: 'fr',
        params: {
          'ref': '(PROV22)',
          'amount': '13464.00',
          'status': 'Brouillon',
          'date': '14/11/2026',
        },
      );
      expect(cardRes, contains('(PROV22)'));
      expect(cardRes, contains('13464.00'));
      expect(cardRes, contains('Brouillon'));
    });

    test('detects RTL for Arabic and LTR for French and English', () {
      AppI18n.setLocale('fr');
      expect(AppI18n.isRtl, isFalse);

      AppI18n.setLocale('ar');
      expect(AppI18n.isRtl, isTrue);

      AppI18n.setLocale('en');
      expect(AppI18n.isRtl, isFalse);
    });

    test('falls back to French when key is missing in requested locale', () {
      final text = AppI18n.t('status_draft', locale: 'unknown_locale');
      expect(text, 'Brouillon');
    });
  });
}
