class AppI18n {
  static String _currentLocale = 'fr';

  static const List<String> supportedLocales = <String>['fr', 'ar', 'en'];

  static String get currentLocale => _currentLocale;

  static bool get isRtl => _currentLocale == 'ar';

  static void setLocale(String locale) {
    if (supportedLocales.contains(locale)) {
      _currentLocale = locale;
    }
  }

  static const Map<String, Map<String, String>> _translations = <String, Map<String, String>>{
    'fr': <String, String>{
      'orders_title': 'Mes commandes',
      'orders_refresh': 'Actualiser la liste des commandes',
      'orders_loading': 'Chargement des commandes...',
      'orders_error_title': 'Erreur lors du chargement',
      'orders_error_generic': 'Une erreur est survenue lors du chargement des commandes.',
      'orders_retry': 'Réessayer',
      'orders_empty_list': 'Aucune commande',
      'orders_empty_list_hint': "Vous n'avez pas encore passé de commande.",
      'orders_empty_drafts': 'Aucun brouillon',
      'orders_empty_drafts_hint': "Vous n'avez aucune commande en statut brouillon.",
      'orders_filter_all': 'Toutes',
      'orders_filter_drafts': 'Brouillons',
      'orders_filter_validated': 'Validées',
      'orders_filter_shipped': 'Expédiées',
      'orders_filter_delivered': 'Livrées',
      'orders_filter_semantics': 'Filtrer les commandes par : {filter}',
      'orders_order_prefix': 'Cmd #',
      'orders_currency': 'DH TTC',
      'orders_semantic_card': 'Commande {ref}, montant {amount} DH TTC, statut {status}, date {date}',
      'status_draft': 'Brouillon',
      'status_validated': 'Validée',
      'status_shipped': 'Expédiée',
      'status_delivered': 'Livrée',
      'status_cancelled': 'Annulée',
      'status_unknown': 'Inconnu',
      'language_tooltip': 'Changer de langue',
      'language_fr': 'Français',
      'language_ar': 'العربية',
      'language_en': 'English',
      'draft_badge_label': 'Brouillon en attente',
    },
    'ar': <String, String>{
      'orders_title': 'طلباتي',
      'orders_refresh': 'تحديث قائمة الطلبات',
      'orders_loading': 'جاري تحميل الطلبات...',
      'orders_error_title': 'خطأ أثناء التحميل',
      'orders_error_generic': 'حدث خطأ أثناء تحميل الطلبات.',
      'orders_retry': 'إعادة المحاولة',
      'orders_empty_list': 'لا توجد طلبات',
      'orders_empty_list_hint': 'لم تقم بتقديم أي طلب بعد.',
      'orders_empty_drafts': 'لا توجد مسودات',
      'orders_empty_drafts_hint': 'ليس لديك أي طلب في حالة مسودة.',
      'orders_filter_all': 'الكل',
      'orders_filter_drafts': 'المسودات',
      'orders_filter_validated': 'المؤكدة',
      'orders_filter_shipped': 'المشحونة',
      'orders_filter_delivered': 'المسلمة',
      'orders_filter_semantics': 'تصفية الطلبات حسب: {filter}',
      'orders_order_prefix': 'طلب #',
      'orders_currency': 'درهم مع الرسوم',
      'orders_semantic_card': 'طلب {ref}، المبلغ {amount} درهم، الحالة {status}، التاريخ {date}',
      'status_draft': 'مسودة',
      'status_validated': 'مؤكدة',
      'status_shipped': 'مشحونة',
      'status_delivered': 'تم التوصيل',
      'status_cancelled': 'ملغاة',
      'status_unknown': 'غير معروف',
      'language_tooltip': 'تغيير اللغة',
      'language_fr': 'الفرنسية',
      'language_ar': 'العربية',
      'language_en': 'الإنجليزية',
      'draft_badge_label': 'مسودة قيد الانتظار',
    },
    'en': <String, String>{
      'orders_title': 'My orders',
      'orders_refresh': 'Refresh orders list',
      'orders_loading': 'Loading orders...',
      'orders_error_title': 'Error while loading',
      'orders_error_generic': 'An error occurred while loading orders.',
      'orders_retry': 'Retry',
      'orders_empty_list': 'No orders',
      'orders_empty_list_hint': 'You have not placed any orders yet.',
      'orders_empty_drafts': 'No draft orders',
      'orders_empty_drafts_hint': 'You have no orders in draft status.',
      'orders_filter_all': 'All',
      'orders_filter_drafts': 'Drafts',
      'orders_filter_validated': 'Validated',
      'orders_filter_shipped': 'Shipped',
      'orders_filter_delivered': 'Delivered',
      'orders_filter_semantics': 'Filter orders by: {filter}',
      'orders_order_prefix': 'Order #',
      'orders_currency': 'MAD incl. VAT',
      'orders_semantic_card': 'Order {ref}, amount {amount} MAD, status {status}, date {date}',
      'status_draft': 'Draft',
      'status_validated': 'Validated',
      'status_shipped': 'Shipped',
      'status_delivered': 'Delivered',
      'status_cancelled': 'Cancelled',
      'status_unknown': 'Unknown',
      'language_tooltip': 'Change language',
      'language_fr': 'French',
      'language_ar': 'Arabic',
      'language_en': 'English',
      'draft_badge_label': 'Pending draft',
    },
  };

  static String t(String key, {String? locale, Map<String, String>? params}) {
    final lang = locale ?? _currentLocale;
    final langMap = _translations[lang] ?? _translations['fr'] ?? <String, String>{};
    var value = langMap[key];
    if (value == null) {
      final fallbackMap = _translations['fr'] ?? <String, String>{};
      value = fallbackMap[key] ?? key;
    }

    if (params != null && params.isNotEmpty) {
      params.forEach((paramKey, paramVal) {
        value = value?.replaceAll('{$paramKey}', paramVal) ?? '';
      });
    }

    return value ?? key;
  }

  static bool hasKey(String key, {String? locale}) {
    final lang = locale ?? _currentLocale;
    final langMap = _translations[lang];
    if (langMap == null) return false;
    return langMap.containsKey(key);
  }

  static Map<String, String> getTranslationsFor(String locale) {
    return _translations[locale] ?? <String, String>{};
  }
}
