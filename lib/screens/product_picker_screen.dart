import 'dart:async';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/dolibarr_api.dart';

/// Résultat renvoyé par [ProductPickerScreen] : le produit choisi et la quantité.
class ProductPickerResult {
  final Product product;
  final double qty;
  const ProductPickerResult(this.product, this.qty);
}

/// Sélecteur de produit (recherche + quantité) utilisé pour ajouter
/// une ligne à une commande brouillon existante.
class ProductPickerScreen extends StatefulWidget {
  final DolibarrApiService api;
  const ProductPickerScreen({super.key, required this.api});

  @override
  State<ProductPickerScreen> createState() => _ProductPickerScreenState();
}

class _ProductPickerScreenState extends State<ProductPickerScreen> {
  List<Product> _products = [];
  bool _loading = true;
  String? _error;
  Timer? _debounce;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load({String? search}) async {
    final current = ++_requestId;
    setState(() { _loading = true; _error = null; });
    try {
      final products = await widget.api.getProducts(limit: 100, search: search);
      if (!mounted || current != _requestId) return;
      setState(() => _products = products);
    } on ApiException catch (e) {
      if (mounted && current == _requestId) setState(() => _error = e.message);
    } catch (_) {
      if (mounted && current == _requestId) {
        setState(() => _error = 'Connexion impossible. Vérifiez votre réseau.');
      }
    } finally {
      if (mounted && current == _requestId) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _load(search: value.trim()));
  }

  Future<void> _pick(Product product) async {
    int qty = 1;
    final result = await showDialog<int>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(product.label),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${product.price.toStringAsFixed(2)} DH HT / unité',
                style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton.filledTonal(
                icon: const Icon(Icons.remove),
                onPressed: qty > 1 ? () => setDialogState(() => qty--) : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text('$qty',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.add),
                onPressed: () => setDialogState(() => qty++),
              ),
            ]),
            const SizedBox(height: 12),
            Text('Total HT : ${(product.price * qty).toStringAsFixed(2)} DH',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, qty), child: const Text('Ajouter')),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    Navigator.pop(context, ProductPickerResult(product, result.toDouble()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajouter un produit')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SearchBar(
            hintText: 'Rechercher un produit...',
            leading: const Icon(Icons.search),
            onChanged: _onSearchChanged,
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Réessayer'),
                        ),
                      ]),
                    )
                  : _products.isEmpty
                      ? const Center(child: Text('Aucun produit'))
                      : ListView.separated(
                          itemCount: _products.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final p = _products[i];
                            return ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.inventory_2_outlined),
                              ),
                              title: Text(p.label,
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                              subtitle: Text(p.ref),
                              trailing: Text('${p.price.toStringAsFixed(2)} DH',
                                  style: const TextStyle(
                                      color: Color(0xFF1565C0), fontWeight: FontWeight.bold)),
                              onTap: () => _pick(p),
                            );
                          },
                        ),
        ),
      ]),
    );
  }
}
