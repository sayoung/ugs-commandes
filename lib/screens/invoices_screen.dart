import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/dolibarr_api.dart';

class InvoicesScreen extends StatefulWidget {
  final DolibarrApiService api;
  final int clientId;
  const InvoicesScreen({super.key, required this.api, required this.clientId});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  List<Map<String, dynamic>> _invoices = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final invoices = await widget.api.getClientInvoices(widget.clientId);
      setState(() => _invoices = invoices);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _loading = false);
    }
  }

  String _statusLabel(dynamic s) {
    switch (s?.toString()) {
      case '0': return 'Brouillon';
      case '1': return 'Non payée';
      case '2': return 'Payée';
      case '3': return 'Abandonnée';
      default: return 'Inconnu';
    }
  }

  Color _statusColor(dynamic s) {
    switch (s?.toString()) {
      case '0': return Colors.orange;
      case '1': return Colors.red;
      case '2': return Colors.green;
      case '3': return Colors.grey;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes factures'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _invoices.isEmpty
                  ? const Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Aucune facture', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _invoices.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final inv = _invoices[i];
                          final dateTs = inv['date'] ?? inv['datef'];
                          DateTime? date;
                          if (dateTs != null) {
                            date = DateTime.fromMillisecondsSinceEpoch(int.parse(dateTs.toString()) * 1000);
                          }
                          final totalTtc = double.tryParse(inv['total_ttc']?.toString() ?? '0') ?? 0;
                          final remaintopay = double.tryParse(inv['remaintopay']?.toString() ?? '0') ?? 0;
                          return Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.receipt_long, color: Colors.green),
                              ),
                              title: Row(children: [
                                Text('Fac. ${inv['ref'] ?? '#${inv['id']}'}',
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _statusColor(inv['statut']).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(_statusLabel(inv['statut']),
                                      style: TextStyle(fontSize: 11, color: _statusColor(inv['statut']),
                                          fontWeight: FontWeight.w600)),
                                ),
                              ]),
                              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                if (date != null)
                                  Text(DateFormat('dd/MM/yyyy').format(date),
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                Row(children: [
                                  Text('${totalTtc.toStringAsFixed(2)} DH TTC',
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                  if (remaintopay > 0) ...[
                                    const SizedBox(width: 8),
                                    Text('Reste: ${remaintopay.toStringAsFixed(2)} DH',
                                        style: const TextStyle(color: Colors.red, fontSize: 12)),
                                  ],
                                ]),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
