import 'package:flutter/foundation.dart';
import '../models/product.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get subtotal => product.price * quantity;
}

class CartProvider extends ChangeNotifier {
  final Map<int, CartItem> _items = {};
  int? _selectedThirdPartyId;
  String? _selectedThirdPartyName;
  String _note = '';

  Map<int, CartItem> get items => _items;
  int? get thirdPartyId => _selectedThirdPartyId;
  String? get thirdPartyName => _selectedThirdPartyName;
  String get note => _note;

  int get itemCount => _items.values.fold(0, (sum, i) => sum + i.quantity);

  double get total => _items.values.fold(0.0, (sum, i) => sum + i.subtotal);

  void setClient(int id, String name) {
    _selectedThirdPartyId = id;
    _selectedThirdPartyName = name;
    notifyListeners();
  }

  void setNote(String n) {
    _note = n;
    notifyListeners();
  }

  void addProduct(Product product) {
    if (_items.containsKey(product.id)) {
      _items[product.id]!.quantity++;
    } else {
      _items[product.id] = CartItem(product: product);
    }
    notifyListeners();
  }

  void removeProduct(int productId) {
    _items.remove(productId);
    notifyListeners();
  }

  void updateQuantity(int productId, int qty) {
    if (qty <= 0) {
      removeProduct(productId);
    } else if (_items.containsKey(productId)) {
      _items[productId]!.quantity = qty;
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    _selectedThirdPartyId = null;
    _selectedThirdPartyName = null;
    _note = '';
    notifyListeners();
  }
}
