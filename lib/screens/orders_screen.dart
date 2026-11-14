import 'package:flutter/material.dart';
import '../i18n/app_i18n.dart';
import '../models/order.dart';
import '../services/dolibarr_api.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  final DolibarrApiService api;
  final int clientId;
  final List<Map<String, dynamic>>? initialOrders;
  final String? initialLocale;

  const OrdersScreen({
    super.key,
    required this.api,
    required this.clientId,
    this.initialOrders,
    this.initialLocale,
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<OrderModel> _orders = <OrderModel>[];
  bool _loading = true;
  String? _error;
  int? _statusFilter;
  late String _currentLocale;

  @override
  void initState() {
    super.initState();
    _currentLocale = widget.initialLocale ?? AppI18n.currentLocale;
    final init = widget.initialOrders;
    if (init != null) {
      final list = <OrderModel>[];
      for (final raw in init) {
        final parsed = OrderModel.tryFromMap(raw);
        if (parsed != null) {
          list.add(parsed);
        }
      }
      _orders = list;
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rawOrders = await widget.api.getClientOrders(widget.clientId);
      final list = <OrderModel>[];
      for (final raw in rawOrders) {
        final parsed = OrderModel.tryFromMap(raw);
        if (parsed != null) {
          list.add(parsed);
        }
      }
      if (!mounted) return;
      setState(() {
        _orders = list;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = AppI18n.t('orders_error_generic', locale: _currentLocale);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _changeLocale(String newLocale) {
    AppI18n.setLocale(newLocale);
    setState(() {
      _currentLocale = newLocale;
    });
  }

  List<OrderModel> get _filteredOrders {
    final filter = _statusFilter;
    if (filter == null) {
      return _orders;
    }
    final list = <OrderModel>[];
    for (final o in _orders) {
      if (o.status == filter) {
        list.add(o);
      }
    }
    return list;
  }

  int get _draftCount {
    int count = 0;
    for (final o in _orders) {
      if (o.isDraft) {
        count++;
      }
    }
    return count;
  }

  int get _validatedCount {
    int count = 0;
    for (final o in _orders) {
      if (o.status == 1) {
        count++;
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = _currentLocale == 'ar';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppI18n.t('orders_title', locale: _currentLocale)),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.language),
              tooltip: AppI18n.t('language_tooltip', locale: _currentLocale),
              onSelected: _loading ? null : _changeLocale,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'fr',
                  child: Row(
                    children: [
                      if (_currentLocale == 'fr')
                        const Icon(Icons.check, size: 18, color: Color(0xFF1565C0))
                      else
                        const SizedBox(width: 18),
                      const SizedBox(width: 8),
                      Text(AppI18n.t('language_fr', locale: _currentLocale)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'ar',
                  child: Row(
                    children: [
                      if (_currentLocale == 'ar')
                        const Icon(Icons.check, size: 18, color: Color(0xFF1565C0))
                      else
                        const SizedBox(width: 18),
                      const SizedBox(width: 8),
                      Text(AppI18n.t('language_ar', locale: _currentLocale)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'en',
                  child: Row(
                    children: [
                      if (_currentLocale == 'en')
                        const Icon(Icons.check, size: 18, color: Color(0xFF1565C0))
                      else
                        const SizedBox(width: 18),
                      const SizedBox(width: 8),
                      Text(AppI18n.t('language_en', locale: _currentLocale)),
                    ],
                  ),
                ),
              ],
            ),
            Semantics(
              button: true,
              label: AppI18n.t('orders_refresh', locale: _currentLocale),
              child: IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: AppI18n.t('orders_refresh', locale: _currentLocale),
                onPressed: _loading ? null : _load,
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            _buildFilterChips(),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final draftCount = _draftCount;
    final draftsLabel = draftCount > 0
        ? '${AppI18n.t('orders_filter_drafts', locale: _currentLocale)} ($draftCount)'
        : AppI18n.t('orders_filter_drafts', locale: _currentLocale);

    final validatedCount = _validatedCount;
    final validatedLabel = validatedCount > 0
        ? '${AppI18n.t('orders_filter_validated', locale: _currentLocale)} ($validatedCount)'
        : AppI18n.t('orders_filter_validated', locale: _currentLocale);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: AppI18n.t(
              'orders_filter_semantics',
              locale: _currentLocale,
              params: {'filter': AppI18n.t('orders_filter_all', locale: _currentLocale)},
            ),
            child: FilterChip(
              label: Text('${AppI18n.t('orders_filter_all', locale: _currentLocale)} (${_orders.length})'),
              selected: _statusFilter == null,
              onSelected: _loading
                  ? null
                  : (selected) {
                      setState(() => _statusFilter = null);
                    },
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: AppI18n.t(
              'orders_filter_semantics',
              locale: _currentLocale,
              params: {'filter': AppI18n.t('orders_filter_drafts', locale: _currentLocale)},
            ),
            child: FilterChip(
              avatar: Icon(
                Icons.edit_note,
                size: 18,
                color: _statusFilter == 0 ? Colors.white : Colors.orange,
              ),
              label: Text(draftsLabel),
              selected: _statusFilter == 0,
              selectedColor: Colors.orange,
              onSelected: _loading
                  ? null
                  : (selected) {
                      setState(() => _statusFilter = selected ? 0 : null);
                    },
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: AppI18n.t(
              'orders_filter_semantics',
              locale: _currentLocale,
              params: {'filter': AppI18n.t('orders_filter_validated', locale: _currentLocale)},
            ),
            child: FilterChip(
              label: Text(validatedLabel),
              selected: _statusFilter == 1,
              onSelected: _loading
                  ? null
                  : (selected) {
                      setState(() => _statusFilter = selected ? 1 : null);
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              AppI18n.t('orders_loading', locale: _currentLocale),
              style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
            ),
          ],
        ),
      );
    }

    final currentError = _error;
    if (currentError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
              const SizedBox(height: 16),
              Text(
                AppI18n.t('orders_error_title', locale: _currentLocale),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                currentError,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Semantics(
                button: true,
                label: AppI18n.t('orders_retry', locale: _currentLocale),
                child: FilledButton.icon(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh),
                  label: Text(AppI18n.t('orders_retry', locale: _currentLocale)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredOrders;

    if (filtered.isEmpty) {
      final isDraftFilter = _statusFilter == 0;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isDraftFilter ? Icons.drafts_outlined : Icons.list_alt_outlined,
                size: 64,
                color: isDraftFilter ? Colors.orange.shade300 : Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                isDraftFilter
                    ? AppI18n.t('orders_empty_drafts', locale: _currentLocale)
                    : AppI18n.t('orders_empty_list', locale: _currentLocale),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                isDraftFilter
                    ? AppI18n.t('orders_empty_drafts_hint', locale: _currentLocale)
                    : AppI18n.t('orders_empty_list_hint', locale: _currentLocale),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final o = filtered[i];
          return _buildOrderCard(o);
        },
      ),
    );
  }

  Widget _buildOrderCard(OrderModel o) {
    final statusLabel = o.getStatusLabel(_currentLocale);
    final amountStr = o.totalTtc.toStringAsFixed(2);
    final currencyStr = AppI18n.t('orders_currency', locale: _currentLocale);
    final prefixStr = AppI18n.t('orders_order_prefix', locale: _currentLocale);
    final dateStr = o.formattedDate();
    final isDraft = o.isDraft;

    final semanticCardLabel = AppI18n.t(
      'orders_semantic_card',
      locale: _currentLocale,
      params: {
        'ref': o.ref,
        'amount': amountStr,
        'status': statusLabel,
        'date': dateStr.isNotEmpty ? dateStr : '-',
      },
    );

    return Semantics(
      container: true,
      label: semanticCardLabel,
      child: Card(
        elevation: isDraft ? 2 : 1,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isDraft
              ? BorderSide(color: Colors.orange.withValues(alpha: 0.5), width: 1.5)
              : BorderSide.none,
        ),
        child: ListTile(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderDetailScreen(
                  api: widget.api,
                  orderId: o.id,
                  orderRef: o.ref.isNotEmpty ? o.ref : o.id.toString(),
                ),
              ),
            );
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: o.statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isDraft ? Icons.edit_note_outlined : Icons.shopping_bag_outlined,
              color: o.statusColor,
              size: 26,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  '$prefixStr${o.ref}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDraft ? Colors.orange.shade900 : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: o.statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isDraft) ...[
                      const Icon(Icons.edit, size: 12, color: Colors.orange),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: o.statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (dateStr.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                '$amountStr $currencyStr',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDraft ? Colors.orange.shade800 : const Color(0xFF1565C0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
