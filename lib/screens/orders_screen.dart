import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/dolibarr_api.dart';

class OrdersScreen extends StatefulWidget {
  final DolibarrApiService api;
  final int clientId;
  const OrdersScreen({super.key, required this.api, required this.clientId});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final orders = await widget.api.getClientOrders(widget.clientId);
      setState(() => _orders = orders);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _loading = false);
    }
  }

  String _statusLabel(dynamic s) {
    switch (s?.toString()) {
      case '-1': return 'Annulée';
      case '0': return 'Brouillon';
      case '1': return 'Validée';
      case '2': return 'Expédiée';
      case '3': return 'Livrée';
      default: return 'Inconnu';
    }
  }

  Color _statusColor(dynamic s) {
    switch (s?.toString()) {
      case '-1': return Colors.red;
      case '0': return Colors.orange;
      case '1': return Colors.blue;
      case '2': return Colors.purple;
      case '3': return Colors.green;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes commandes'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _orders.isEmpty
                  ? const Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.list_alt_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Aucune commande', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _orders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final o = _orders[i];
                          final dateTs = o['date_commande'] ?? o['date'];
                          DateTime? date;
                          if (dateTs != null) {
                            date = DateTime.fromMillisecondsSinceEpoch(int.parse(dateTs.toString()) * 1000);
                          }
                          final total = double.tryParse(o['total_ttc']?.toString() ?? '0') ?? 0;
                          return Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1565C0).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF1565C0)),
                              ),
                              title: Row(children: [
                                Text('Cmd #${o['ref'] ?? o['id']}',
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _statusColor(o['statut']).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(_statusLabel(o['statut']),
                                      style: TextStyle(fontSize: 11, color: _statusColor(o['statut']),
                                          fontWeight: FontWeight.w600)),
                                ),
                              ]),
                              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                if (date != null)
                                  Text(DateFormat('dd/MM/yyyy').format(date),
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                Text('${total.toStringAsFixed(2)} DH TTC',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
