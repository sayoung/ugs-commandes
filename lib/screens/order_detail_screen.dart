import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/dolibarr_api.dart';
import '../widgets/order_timeline.dart';

class OrderDetailScreen extends StatefulWidget {
  final DolibarrApiService api;
  final int orderId;
  final String orderRef;

  const OrderDetailScreen({
    super.key,
    required this.api,
    required this.orderId,
    required this.orderRef,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Map<String, dynamic>? _order;
  List<Map<String, dynamic>> _lines = [];
  bool _loading = true;
  String? _error;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final order = await widget.api.getOrder(widget.orderId);
      final lines = await widget.api.getOrderLines(widget.orderId);
      setState(() { _order = order; _lines = lines; });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _loading = false);
    }
  }

  int get _status => int.tryParse(_order?['statut']?.toString() ?? '0') ?? 0;
  bool get _isDraft => _status == 0;

  Future<void> _validate() async {
    final ok = await _confirm('Valider la commande ?',
        'La commande sera envoyée à UGS. Vous ne pourrez plus la modifier.');
    if (!ok) return;
    setState(() => _actionLoading = true);
    try {
      await widget.api.validateOrder(widget.orderId);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Commande validée ✓'), backgroundColor: Colors.green));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await _confirm('Annuler la commande ?',
        'Cette action est définitive. La commande sera annulée.');
    if (!ok) return;
    setState(() => _actionLoading = true);
    try {
      await widget.api.cancelOrder(widget.orderId);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Commande annulée'), backgroundColor: Colors.orange));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _editLineQty(Map<String, dynamic> line) async {
    // DEBUG
    debugPrint("LINE KEYS: \${line.keys.toList()}");
    debugPrint("LINE id=\${line["id"]} rowid=\${line["rowid"]}");
    final lineId = int.tryParse(
      (line['rowid'] ?? line['id'])?.toString() ?? '0') ?? 0;
    final currentQty = double.tryParse(line['qty']?.toString() ?? '1') ?? 1;
    final ctrl = TextEditingController(text: currentQty.toStringAsFixed(0));
    final result = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Modifier la quantité'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Quantité', border: OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text);
              if (v != null && v > 0) Navigator.pop(context, v);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (result == null || result == currentQty) return;
    final unitPrice = double.tryParse(line['subprice']?.toString() ?? '0') ?? 0;
    final vatRate = double.tryParse(line['tva_tx']?.toString() ?? '20') ?? 20;
    setState(() => _actionLoading = true);
    try {
      await widget.api.updateOrderLine(widget.orderId, lineId, result,
          unitPrice: unitPrice, vatRate: vatRate);
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _deleteLine(Map<String, dynamic> line) async {
    final lineId = int.tryParse((line['rowid'] ?? line['id'])?.toString() ?? '0') ?? 0;
    final label = line['product_label']?.toString() ?? line['label']?.toString() ?? 'ce produit';
    final ok = await _confirm('Supprimer la ligne ?', 'Supprimer "$label" de la commande ?');
    if (!ok) return;
    setState(() => _actionLoading = true);
    try {
      await widget.api.deleteOrderLine(widget.orderId, lineId);
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<bool> _confirm(String title, String msg) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title),
            content: Text(msg),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmer')),
            ],
          ),
        ) ??
        false;
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Commande ${widget.orderRef}'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
                  ]),
                ))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // ── Infos générales ──
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(
                                child: Text('Réf : ${_order?['ref'] ?? widget.orderRef}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _statusColor(_status).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(_statusLabel(_status),
                                    style: TextStyle(
                                        color: _statusColor(_status),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12)),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            if (_order?['date_commande'] != null) ...[
                              Text(
                                'Date : ${DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(int.parse(_order!['date_commande'].toString()) * 1000))}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                            ],
                            Text(
                              'Total TTC : ${(double.tryParse(_order?['total_ttc']?.toString() ?? '0') ?? 0).toStringAsFixed(2)} DH',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1565C0), fontSize: 15),
                            ),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Timeline ──
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: OrderTimeline(status: _status),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Lignes ──
                      const Text('Articles', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      if (_lines.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Aucune ligne', style: TextStyle(color: Colors.grey)),
                          ),
                        )
                      else
                        ..._lines.map((line) {
                          final qty = double.tryParse(line['qty']?.toString() ?? '1') ?? 1;
                          final prix = double.tryParse(line['subprice']?.toString() ?? '0') ?? 0;
                          final total = double.tryParse(line['total_ttc']?.toString() ?? '0') ?? 0;
                          final label = line['product_label']?.toString() ?? line['label']?.toString() ?? '—';
                          final ref = line['product_ref']?.toString() ?? '';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(children: [
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    if (ref.isNotEmpty)
                                      Text(ref, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                    Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    Text(
                                      '${qty.toStringAsFixed(0)} × ${prix.toStringAsFixed(2)} DH HT',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                  ]),
                                ),
                                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  Text('${total.toStringAsFixed(2)} DH',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
                                  if (_isDraft) Row(children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                      color: Colors.blue,
                                      onPressed: _actionLoading ? null : () => _editLineQty(line),
                                      tooltip: 'Modifier quantité',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18),
                                      color: Colors.red,
                                      onPressed: _actionLoading ? null : () => _deleteLine(line),
                                      tooltip: 'Supprimer',
                                    ),
                                  ]),
                                ]),
                              ]),
                            ),
                          );
                        }),

                      // ── Actions brouillon ──
                      if (_isDraft) ...[
                        const SizedBox(height: 16),
                        if (_actionLoading)
                          const Center(child: CircularProgressIndicator())
                        else ...[
                          FilledButton.icon(
                            onPressed: _validate,
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Valider la commande'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              backgroundColor: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _cancel,
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text('Annuler la commande'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}
