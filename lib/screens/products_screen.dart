import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/dolibarr_api.dart';
import '../services/auth_service.dart';
import '../config/api_config.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import 'cart_screen.dart';
import 'orders_screen.dart';
import 'invoices_screen.dart';

class ProductsScreen extends StatefulWidget {
  final int clientId;
  final String clientName;
  final VoidCallback? onLogout;

  const ProductsScreen({
    super.key,
    required this.clientId,
    required this.clientName,
    this.onLogout,
  });

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  late final DolibarrApiService _api;
  List<Product> _products = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _api = DolibarrApiService(apiKey: ApiConfig.apiKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartProvider>().setClient(widget.clientId, widget.clientName);
    });
    _load();
  }

  Future<void> _load({String? search}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final products = await _api.getProducts(limit: 100, search: search);
      setState(() => _products = products);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    widget.onLogout?.call();
    Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
  }

  void _openCart() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CartScreen(api: _api)),
      );

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Catalogue produits'),
            Text(
              widget.clientName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: _openCart,
              ),
              if (cart.itemCount > 0)
                Positioned(
                  right: 8, top: 8,
                  child: CircleAvatar(
                    radius: 8,
                    backgroundColor: Colors.red,
                    child: Text('${cart.itemCount}',
                        style: const TextStyle(fontSize: 10, color: Colors.white)),
                  ),
                ),
            ],
          ),
          PopupMenuButton(
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'orders',
                child: Row(children: [
                  Icon(Icons.list_alt, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Mes commandes'),
                ]),
              ),
              const PopupMenuItem(
                value: 'invoices',
                child: Row(children: [
                  Icon(Icons.receipt_long, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Mes factures'),
                ]),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(children: [
                  Icon(Icons.logout, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Déconnexion', style: TextStyle(color: Colors.red)),
                ]),
              ),
            ],
            onSelected: (v) {
              if (v == 'logout') {
                _logout();
              } else if (v == 'orders') {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => OrdersScreen(api: _api, clientId: widget.clientId)));
              } else if (v == 'invoices') {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => InvoicesScreen(api: _api, clientId: widget.clientId)));
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: cart.itemCount == 0
          ? null
          : Material(
              color: const Color(0xFF1565C0),
              child: SafeArea(
                top: false,
                child: InkWell(
                  onTap: _openCart,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                        child: Text('${cart.itemCount}',
                            style: const TextStyle(
                                color: Color(0xFF1565C0), fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              cart.itemCount == 1 ? '1 article dans le panier' : '${cart.itemCount} articles dans le panier',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            Text('${cart.total.toStringAsFixed(2)} DH HT',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const Text('Voir le panier',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                    ]),
                  ),
                ),
              ),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SearchBar(
              controller: _searchCtrl,
              hintText: 'Rechercher un produit...',
              onChanged: (v) => _load(search: v),
              leading: const Icon(Icons.search),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                    : _products.isEmpty
                        ? const Center(child: Text('Aucun produit'))
                        : GridView.builder(
                            padding: const EdgeInsets.all(12),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 240,
                              mainAxisExtent: 268,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: _products.length,
                            itemBuilder: (_, i) {
                              final p = _products[i];
                              final qty = cart.items[p.id]?.quantity ?? 0;
                              return _ProductCard(
                                product: p,
                                quantity: qty,
                                onAdd: () => context.read<CartProvider>().addProduct(p),
                                onRemove: () =>
                                    context.read<CartProvider>().updateQuantity(p.id, qty - 1),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  static const _blue = Color(0xFF1565C0);

  final Product product;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _ProductCard({
    required this.product,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final inCart = quantity > 0;
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: inCart ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: inCart ? _blue : Colors.transparent, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(children: [
              Container(
                color: inCart ? const Color(0xFFE3F2FD) : Colors.grey[100],
                width: double.infinity,
                height: double.infinity,
                child: Icon(Icons.inventory_2_outlined,
                    size: 48, color: inCart ? _blue : Colors.grey),
              ),
              if (inCart)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[600],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.check, color: Colors.white, size: 14),
                      const SizedBox(width: 2),
                      Text('× $quantity',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 38,
                  child: Text(product.label,
                      style: const TextStyle(fontWeight: FontWeight.w600, height: 1.2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
                Text(product.ref,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                const SizedBox(height: 4),
                Text('${product.price.toStringAsFixed(2)} DH',
                    style: const TextStyle(
                        color: _blue, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 6),
                SizedBox(
                  height: 38,
                  width: double.infinity,
                  child: inCart
                      ? Container(
                          decoration: BoxDecoration(
                            color: _blue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                onPressed: onRemove,
                                tooltip: 'Retirer',
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                    quantity == 1 ? Icons.delete_outline : Icons.remove,
                                    color: Colors.white,
                                    size: 20),
                              ),
                              Text('$quantity',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              IconButton(
                                onPressed: onAdd,
                                tooltip: 'Ajouter',
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.add, color: Colors.white, size: 20),
                              ),
                            ],
                          ),
                        )
                      : OutlinedButton.icon(
                          onPressed: onAdd,
                          icon: const Icon(Icons.add_shopping_cart, size: 18),
                          label: const Text('Ajouter'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            foregroundColor: _blue,
                            side: const BorderSide(color: _blue),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
