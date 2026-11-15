import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../providers/cart_provider.dart';
import '../services/auth_service.dart';
import '../services/dolibarr_api.dart';
import 'cart_screen.dart';
import 'invoices_screen.dart';
import 'order_detail_screen.dart';
import 'orders_screen.dart';
import 'products_screen.dart';

/// Écran d'accueil affiché après connexion :
/// résumé de l'activité + accès Mes commandes / Mes factures / Catalogue / Panier.
class HomeScreen extends StatefulWidget {
  final int clientId;
  final String clientName;
  final VoidCallback? onLogout;

  const HomeScreen({
    super.key,
    required this.clientId,
    required this.clientName,
    this.onLogout,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _blue = Color(0xFF1565C0);

  late final DolibarrApiService _api;
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _invoices = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = DolibarrApiService(apiKey: ApiConfig.apiKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartProvider>().setClient(widget.clientId, widget.clientName);
    });
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final orders = await _api.getClientOrders(widget.clientId);
      final invoices = await _api.getClientInvoices(widget.clientId);
      if (!mounted) return;
      setState(() { _orders = orders; _invoices = invoices; });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Connexion impossible. Vérifiez votre réseau.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Calculs du résumé ─────────────────────────────────────────────────────

  int _orderStatus(Map<String, dynamic> o) =>
      int.tryParse((o['statut'] ?? o['status'])?.toString() ?? '') ?? 0;

  double _num(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

  int get _draftCount => _orders.where((o) => _orderStatus(o) == 0).length;

  int get _inProgressCount =>
      _orders.where((o) => _orderStatus(o) == 1 || _orderStatus(o) == 2).length;

  List<Map<String, dynamic>> get _unpaidInvoices =>
      _invoices.where((i) => (i['statut'] ?? i['status'])?.toString() == '1').toList();

  double get _unpaidTotal {
    double total = 0;
    for (final inv in _unpaidInvoices) {
      final rest = inv['remaintopay'];
      total += rest != null ? _num(rest) : _num(inv['total_ttc']);
    }
    return total;
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _load();
  }

  void _openOrders() => _open(OrdersScreen(api: _api, clientId: widget.clientId));
  void _openInvoices() => _open(InvoicesScreen(api: _api, clientId: widget.clientId));
  void _openCart() => _open(CartScreen(api: _api));
  void _openCatalogue() => _open(ProductsScreen(
        clientId: widget.clientId,
        clientName: widget.clientName,
        onLogout: widget.onLogout,
      ));

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vous déconnecter ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Oui')),
        ],
      ),
    );
    if (ok != true) return;
    await AuthService.logout();
    if (!mounted) return;
    context.read<CartProvider>().clear();
    widget.onLogout?.call();
  }

  // ── Libellés ──────────────────────────────────────────────────────────────

  String _statusLabel(int s) {
    switch (s) {
      case -1: return 'Annulée';
      case 0: return 'Brouillon';
      case 1: return 'Validée';
      case 2: return 'Expédiée';
      case 3: return 'Livrée';
      default: return 'Inconnu';
    }
  }

  Color _statusColor(int s) {
    switch (s) {
      case -1: return Colors.red;
      case 0: return Colors.orange;
      case 1: return Colors.blue;
      case 2: return Colors.purple;
      case 3: return Colors.green;
      default: return Colors.grey;
    }
  }

  String _orderDate(Map<String, dynamic> o) {
    final raw = int.tryParse((o['date_commande'] ?? o['date'])?.toString() ?? '');
    if (raw == null || raw == 0) return '';
    return DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(raw * 1000));
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  Widget _header() {
    final initial = widget.clientName.trim().isEmpty
        ? '?'
        : widget.clientName.trim().substring(0, 1).toUpperCase();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D47A1), Color(0xFF1E88E5)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(children: [
            Row(children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(initial,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Bonjour,',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                  Text(widget.clientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ]),
              ),
            ]),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: _StatCard(
                icon: Icons.local_shipping_outlined,
                label: 'En cours',
                value: _loading ? '…' : '$_inProgressCount',
                hint: 'commandes',
                color: _blue,
              )),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(
                icon: Icons.edit_note,
                label: 'Brouillons',
                value: _loading ? '…' : '$_draftCount',
                hint: 'à valider',
                color: Colors.orange[800]!,
              )),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(
                icon: Icons.payments_outlined,
                label: 'À payer',
                value: _loading ? '…' : _unpaidTotal.toStringAsFixed(0),
                hint: 'DH',
                color: _unpaidTotal > 0 ? Colors.red[700]! : Colors.green[700]!,
              )),
            ]),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('UGS Commandes', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: _loading ? null : _load,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
            onPressed: _logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _header(),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (_error != null)
                      Card(
                        elevation: 0,
                        color: Colors.red[50],
                        child: ListTile(
                          leading: const Icon(Icons.wifi_off, color: Colors.red),
                          title: Text(_error!, style: const TextStyle(color: Colors.red)),
                          trailing: TextButton(onPressed: _load, child: const Text('Réessayer')),
                        ),
                      ),

                    // ── Alerte brouillons ──
                    if (_draftCount > 0) ...[
                      Material(
                        color: Colors.orange[50],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.orange[200]!),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          leading: Icon(Icons.pending_actions, color: Colors.orange[800]),
                          title: Text(
                            _draftCount == 1
                                ? '1 commande en brouillon à valider'
                                : '$_draftCount commandes en brouillon à valider',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text('Vérifiez puis validez pour l\'envoyer à UGS'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _openOrders,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Menu principal ──
                    GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisExtent: 150,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      children: [
                        _MenuCard(
                          icon: Icons.list_alt,
                          color: _blue,
                          title: 'Mes commandes',
                          subtitle: 'Suivre, modifier, valider',
                          badge: _draftCount,
                          onTap: _openOrders,
                        ),
                        _MenuCard(
                          icon: Icons.receipt_long,
                          color: Colors.green[700]!,
                          title: 'Mes factures',
                          subtitle: 'Factures et paiements',
                          badge: _unpaidInvoices.length,
                          onTap: _openInvoices,
                        ),
                        _MenuCard(
                          icon: Icons.storefront,
                          color: Colors.deepPurple,
                          title: 'Catalogue',
                          subtitle: 'Parcourir et commander',
                          onTap: _openCatalogue,
                        ),
                        _MenuCard(
                          icon: Icons.shopping_cart,
                          color: Colors.teal[700]!,
                          title: 'Mon panier',
                          subtitle: cart.itemCount == 0
                              ? 'Panier vide'
                              : '${cart.total.toStringAsFixed(2)} DH',
                          badge: cart.itemCount,
                          onTap: _openCart,
                        ),
                      ],
                    ),

                    // ── Dernières commandes ──
                    if (_orders.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Row(children: [
                        const Expanded(
                          child: Text('Dernières commandes',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        TextButton(onPressed: _openOrders, child: const Text('Tout voir')),
                      ]),
                      Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        clipBehavior: Clip.antiAlias,
                        child: Column(children: [
                          for (final entry in _orders.take(3).toList().asMap().entries) ...[
                            if (entry.key > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                            _recentOrderTile(entry.value),
                          ],
                        ]),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recentOrderTile(Map<String, dynamic> o) {
    final status = _orderStatus(o);
    final id = int.tryParse(o['id']?.toString() ?? '') ?? 0;
    final ref = o['ref']?.toString() ?? '$id';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _statusColor(status).withValues(alpha: 0.12),
        child: Icon(Icons.shopping_bag_outlined, color: _statusColor(status), size: 20),
      ),
      title: Text(ref, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${_orderDate(o)}  •  ${_num(o['total_ttc']).toStringAsFixed(2)} DH'),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _statusColor(status).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(_statusLabel(status),
            style: TextStyle(
                color: _statusColor(status), fontWeight: FontWeight.w700, fontSize: 12)),
      ),
      onTap: () => _open(OrderDetailScreen(api: _api, orderId: id, orderRef: ref)),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String hint;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.hint,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          ),
        ]),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        ),
        Text(hint, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ]),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final int badge;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const Spacer(),
              if (badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$badge',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
            ]),
            const Spacer(),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 2),
            Text(subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: Colors.grey[600])),
          ]),
        ),
      ),
    );
  }
}
