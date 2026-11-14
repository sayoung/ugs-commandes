import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../services/dolibarr_api.dart';
import 'order_success_screen.dart';

class CartScreen extends StatefulWidget {
  final DolibarrApiService api;
  const CartScreen({super.key, required this.api});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _noteCtrl = TextEditingController();
  bool _placing = false;

  Future<void> _placeOrder(CartProvider cart) async {
    if (cart.thirdPartyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un client'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => _placing = true);
    try {
      // 1. Créer commande
      final orderId = await widget.api.createOrder(
        thirdPartyId: cart.thirdPartyId!,
        note: cart.note,
      );
      // 2. Ajouter lignes
      for (final item in cart.items.values) {
        await widget.api.addOrderLine(
          orderId: orderId,
          productId: item.product.id,
          qty: item.quantity.toDouble(),
          unitPrice: item.product.price,
        );
      }
      // 3. Commande créée en Brouillon — le client valide depuis Mes commandes
      cart.clear();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => OrderSuccessScreen(orderId: orderId)),
        );
      }
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _placing = false);
    }
  }

  Future<void> _pickClient(CartProvider cart) async {
    try {
      final clients = await widget.api.getThirdParties();
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        builder: (_) => ListView.builder(
          itemCount: clients.length,
          itemBuilder: (_, i) {
            final c = clients[i];
            return ListTile(
              title: Text(c['name']?.toString() ?? ''),
              subtitle: Text(c['code_client']?.toString() ?? ''),
              onTap: () {
                cart.setClient(
                  int.parse(c['id'].toString()),
                  c['name']?.toString() ?? '',
                );
                Navigator.pop(context);
              },
            );
          },
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Panier')),
      body: cart.items.isEmpty
          ? const Center(child: Text('Panier vide'))
          : Column(
              children: [
                // Client selector
                ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(cart.thirdPartyName ?? 'Sélectionner un client'),
                  trailing: const Icon(Icons.chevron_right),
                  tileColor: cart.thirdPartyId == null ? Colors.orange[50] : null,
                  onTap: () => _pickClient(cart),
                ),
                const Divider(height: 1),
                // Items
                Expanded(
                  child: ListView(
                    children: cart.items.values.map((item) => ListTile(
                      title: Text(item.product.label),
                      subtitle: Text('${item.product.price.toStringAsFixed(2)} DH × ${item.quantity}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${item.subtotal.toStringAsFixed(2)} DH',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => cart.updateQuantity(item.product.id, item.quantity - 1),
                          ),
                          Text('${item.quantity}'),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => cart.updateQuantity(item.product.id, item.quantity + 1),
                          ),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
                // Note
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(labelText: 'Note (optionnel)', border: OutlineInputBorder()),
                    onChanged: cart.setNote,
                    maxLines: 2,
                  ),
                ),
                const SizedBox(height: 8),
                // Total + bouton
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: const Border(top: BorderSide(color: Colors.grey, width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total', style: TextStyle(color: Colors.grey)),
                          Text('${cart.total.toStringAsFixed(2)} DH',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _placing ? null : () => _placeOrder(cart),
                        icon: _placing
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send),
                        label: const Text('Passer la commande'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
