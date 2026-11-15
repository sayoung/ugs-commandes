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

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('UGS Commandes'),
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Bonjour,', style: TextStyle(color: Colors.grey[600])),
                Text(widget.clientName,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                if (_error != null)
                  Card(
                    color: Colors.red[50],
                    child: ListTile(
                      leading: const Icon(Icons.wifi_off, color: Colors.red),
                      title: Text(_error!, style: const TextStyle(color: Colors.red)),
                      trailing: TextButton(onPressed: _load, child: const Text('Réessayer')),
                    ),
                  ),

                // ── Alerte brouillons ──
                if (_draftCount > 0)
                  Card(
                    color: Colors.orange[50],
                    child: ListTile(
                      leading: const Icon(Icons.edit_note, color: Colors.orange),
                      title: Text(_draftCount == 1
                          ? '1 commande en brouillon à valider'
                          : '$_draftCount commandes en brouillon à valider'),
                      subtitle: const Text('Vérifiez puis validez pour l\'envoyer à UGS'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _openOrders,
                    ),
                  ),

                // ── Résumé ──
                Row(children: [
                  Expanded(child: _StatCard(
                    label: 'En cours',
                    value: _loading ? '…' : '$_inProgressCount',
                    hint: 'commandes',
                    color: _blue,
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: _StatCard(
                    label: 'Brouillons',
                    value: _loading ? '…' : '$_draftCount',
                    hint: 'à valider',
                    color: Colors.orange,
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: _StatCard(
                    label: 'À payer',
                    value: _loading ? '…' : _unpaidTotal.toStringAsFixed(0),
                    hint: 'DH',
                    color: _unpaidTotal > 0 ? Colors.red : Colors.green,
                  )),
                ]),
                const SizedBox(height: 16),

                // ── Menu principal ──
                _MenuTile(
                  icon: Icons.list_alt,
                  color: _blue,
                  title: 'Mes commandes',
                  subtitle: 'Suivre, modifier et valider vos commandes',
                  badge: _draftCount,
                  onTap: _openOrders,
                ),
                _MenuTile(
                  icon: Icons.receipt_long,
                  color: Colors.green,
                  title: 'Mes factures',
                  subtitle: 'Consulter vos factures et paiements',
                  badge: _unpaidInvoices.length,
                  onTap: _openInvoices,
                ),
                _MenuTile(
                  icon: Icons.storefront,
                  color: Colors.deepPurple,
                  title: 'Catalogue',
                  subtitle: 'Parcourir les produits et commander',
                  onTap: _openCatalogue,
                ),
                _MenuTile(
                  icon: Icons.shopping_cart,
                  color: Colors.teal,
                  title: 'Mon panier',
                  subtitle: cart.itemCount == 0
                      ? 'Votre panier est vide'
                      : '${cart.itemCount} article(s) — ${cart.total.toStringAsFixed(2)} DH',
                  badge: cart.itemCount,
                  onTap: _openCart,
                ),

                // ── Dernières commandes ──
                if (_orders.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(children: [
                    const Expanded(
                      child: Text('Dernières commandes',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                    TextButton(onPressed: _openOrders, child: const Text('Tout voir')),
                  ]),
                  ..._orders.take(3).map((o) {
                    final status = _orderStatus(o);
                    final id = int.tryParse(o['id']?.toString() ?? '') ?? 0;
                    final ref = o['ref']?.toString() ?? '$id';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(ref, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            '${_orderDate(o)}  •  ${_num(o['total_ttc']).toStringAsFixed(2)} DH'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor(status).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(_statusLabel(status),
                              style: TextStyle(
                                  color: _statusColor(status),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12)),
                        ),
                        onTap: () => _open(
                            OrderDetailScreen(api: _api, orderId: id, orderRef: ref)),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.hint,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          ),
          Text(hint, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ]),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final int badge;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (badge > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$badge',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          const Icon(Icons.chevron_right),
        ]),
        onTap: onTap,
      ),
    );
  }
}
