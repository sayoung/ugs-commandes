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
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CartScreen(api: _api)),
                ),
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
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.75,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: _products.length,
                            itemBuilder: (_, i) => _ProductCard(
                              product: _products[i],
                              onAdd: () => context.read<CartProvider>().addProduct(_products[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onAdd;

  const _ProductCard({required this.product, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              color: Colors.grey[100],
              width: double.infinity,
              child: const Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                Text(product.ref, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${product.price.toStringAsFixed(2)} DH',
                        style: const TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.bold)),
                    InkWell(
                      onTap: onAdd,
                      child: const CircleAvatar(
                        radius: 14,
                        backgroundColor: Color(0xFF1565C0),
                        child: Icon(Icons.add, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
