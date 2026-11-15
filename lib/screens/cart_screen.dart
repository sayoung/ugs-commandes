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
        const SnackBar(content: Text('Session expirée. Reconnectez-vous.'), backgroundColor: Colors.orange),
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

  static const _blue = Color(0xFF1565C0);
  static const double _vatRate = 20; // taux appliqué aux lignes envoyées à Dolibarr

  Widget _totalRow(String label, double amount, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: strong ? 16 : 14,
                  fontWeight: strong ? FontWeight.bold : FontWeight.normal,
                  color: strong ? Colors.black87 : Colors.grey[700])),
        ),
        Text('${amount.toStringAsFixed(2)} DH',
            style: TextStyle(
                fontSize: strong ? 20 : 14,
                fontWeight: strong ? FontWeight.bold : FontWeight.w500,
                color: strong ? _blue : Colors.black87)),
      ]),
    );
  }

  Widget _itemCard(CartProvider cart, CartItem item) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.inventory_2_outlined, color: _blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.product.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                if (item.product.ref.isNotEmpty)
                  Text(item.product.ref,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 2),
                Text('${item.product.price.toStringAsFixed(2)} DH HT / unité',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey[700])),
              ]),
            ),
            IconButton(
              tooltip: 'Retirer du panier',
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => cart.removeProduct(item.product.id),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: _blue),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: 'Diminuer',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.remove, color: _blue),
                  onPressed: () => cart.updateQuantity(item.product.id, item.quantity - 1),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 32),
                  child: Text('${item.quantity}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  tooltip: 'Augmenter',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.add, color: _blue),
                  onPressed: () => cart.updateQuantity(item.product.id, item.quantity + 1),
                ),
              ]),
            ),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Sous-total HT', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              Text('${item.subtotal.toStringAsFixed(2)} DH',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold, color: _blue)),
            ]),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final totalHt = cart.total;
    final totalVat = totalHt * _vatRate / 100;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Text(cart.itemCount == 0 ? 'Mon panier' : 'Mon panier (${cart.itemCount})'),
      ),
      body: cart.items.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.shopping_cart_outlined, size: 72, color: Colors.grey[400]),
                const SizedBox(height: 12),
                const Text('Votre panier est vide',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Ajoutez des produits depuis le catalogue',
                    style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Retour'),
                ),
              ]),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          // Client
                          Card(
                            elevation: 0,
                            color: Colors.white,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFE3F2FD),
                                child: Icon(Icons.business, color: _blue),
                              ),
                              title: Text(cart.thirdPartyName ?? '—',
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: const Text('Commande pour ce compte'),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8),
                            child: Text(
                              cart.items.length == 1
                                  ? '1 produit'
                                  : '${cart.items.length} produits',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                          ...cart.items.values.map((item) => _itemCard(cart, item)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _noteCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Note pour UGS (optionnel)',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            onChanged: cart.setNote,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                    // Récapitulatif + bouton
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, -2)),
                        ],
                      ),
                      child: SafeArea(
                        top: false,
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          _totalRow('Total HT', totalHt),
                          _totalRow('TVA (${_vatRate.toStringAsFixed(0)} %)', totalVat),
                          const Divider(height: 14),
                          _totalRow('Total TTC', totalHt + totalVat, strong: true),
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed: _placing ? null : () => _placeOrder(cart),
                            icon: _placing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.send),
                            label: const Text('Passer la commande'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              backgroundColor: _blue,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
