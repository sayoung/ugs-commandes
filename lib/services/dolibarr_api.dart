import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/product.dart';

class DolibarrApiService {
  final String apiKey;

  DolibarrApiService({required this.apiKey});

  Map<String, String> get _headers => ApiConfig.headers;

  // ── Produits ──────────────────────────────────────────────────────────────

  Future<List<Product>> getProducts({
    int limit = 50,
    int page = 0,
    String? search,
  }) async {
    final params = {
      'limit': limit.toString(),
      'page': page.toString(),
      'sortfield': 't.label',
      'sortorder': 'ASC',
      if (search != null && search.isNotEmpty) 'sqlfilters': "(t.label:like:'%$search%')",
    };
    final uri = Uri.parse('${ApiConfig.baseUrl}/products').replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers);
    _checkResponse(res);
    final List data = json.decode(res.body);
    return data.map((e) => Product.fromJson(e)).toList();
  }

  Future<double> getProductStock(int productId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/products/$productId/stock');
    final res = await http.get(uri, headers: _headers);
    _checkResponse(res);
    final data = json.decode(res.body);
    if (data is Map) {
      return double.tryParse(data['stock_reel']?.toString() ?? '0') ?? 0;
    }
    if (data is List && data.isNotEmpty) {
      double total = 0;
      for (final w in data) {
        total += double.tryParse(w['real']?.toString() ?? '0') ?? 0;
      }
      return total;
    }
    return 0;
  }

  // ── Tiers (clients) ───────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getThirdParties({String? search}) async {
    final params = {
      'mode': '1',
      'limit': '100',
      if (search != null && search.isNotEmpty) 'sqlfilters': "(t.nom:like:'%$search%')",
    };
    final uri = Uri.parse('${ApiConfig.baseUrl}/thirdparties').replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers);
    _checkResponse(res);
    final List data = json.decode(res.body);
    return data.cast<Map<String, dynamic>>();
  }

  Future<int> createThirdParty({
    required String denomination,
    required String ice,
    required String address,
    required String email,
    required String passwordHash,
    String? phone,
  }) async {
    final authData = json.encode({'_ugs_email': email.toLowerCase().trim(), '_ugs_hash': passwordHash});
    final body = json.encode({
      'name': denomination,
      'idprof2': ice,
      'address': address,
      'email': email.toLowerCase().trim(),
      'client': 1,
      'fournisseur': 0,
      'status': 1,
      'note_private': authData,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      'country_id': 116,
    });
    final uri = Uri.parse('${ApiConfig.baseUrl}/thirdparties');
    final res = await http.post(uri, headers: _headers, body: body);
    _checkResponse(res);
    return int.parse(json.decode(res.body).toString());
  }

  Future<Map<String, dynamic>?> findThirdPartyByEmail(String email) async {
    final params = {
      'mode': '1',
      'limit': '5',
      'sqlfilters': "(t.email:=:'${email.toLowerCase().trim()}')",
    };
    final uri = Uri.parse('${ApiConfig.baseUrl}/thirdparties').replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode == 404) return null;
    _checkResponse(res);
    final List data = json.decode(res.body);
    if (data.isEmpty) return null;
    return data.first as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> verifyCredentials(String email, String passwordHash) async {
    final tiers = await findThirdPartyByEmail(email);
    if (tiers == null) return null;
    final notePrivate = tiers['note_private']?.toString() ?? '';
    try {
      final authData = json.decode(notePrivate) as Map<String, dynamic>;
      final storedHash = authData['_ugs_hash']?.toString() ?? '';
      if (storedHash == passwordHash) return tiers;
    } catch (_) {}
    return null;
  }

  // ── Commandes ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getClientOrders(int socid, {int? status}) async {
    final filters = <String>["(t.fk_soc:=:$socid)"];
    if (status != null) {
      filters.add("(t.fk_statut:=:$status)");
    }
    final params = {
      'sortfield': 't.date_commande',
      'sortorder': 'DESC',
      'limit': '50',
      'sqlfilters': filters.join(' and '),
    };
    final uri = Uri.parse('${ApiConfig.baseUrl}/orders').replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode == 404) return [];
    _checkResponse(res);
    final decoded = json.decode(res.body);
    if (decoded is List) {
      final list = <Map<String, dynamic>>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          list.add(item);
        } else if (item is Map) {
          final mapped = <String, dynamic>{};
          item.forEach((dynamic k, dynamic v) {
            if (k != null) {
              mapped[k.toString()] = v;
            }
          });
          list.add(mapped);
        }
      }
      return list;
    }
    return [];
  }

  Future<int> createOrder({required int thirdPartyId, String? note}) async {
    final body = json.encode({
      'socid': thirdPartyId,
      'date': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'note_public': note ?? '',
      'status': 0,
    });
    final uri = Uri.parse('${ApiConfig.baseUrl}/orders');
    final res = await http.post(uri, headers: _headers, body: body);
    _checkResponse(res);
    final data = json.decode(res.body);
    return int.parse(data.toString());
  }

  Future<void> addOrderLine({
    required int orderId,
    required int productId,
    required double qty,
    required double unitPrice,
    double vatRate = 20.0,
  }) async {
    final body = json.encode({
      'fk_product': productId,
      'qty': qty,
      'subprice': unitPrice,
      'tva_tx': vatRate,
      'product_type': 0,
    });
    final uri = Uri.parse('${ApiConfig.baseUrl}/orders/$orderId/lines');
    final res = await http.post(uri, headers: _headers, body: body);
    _checkResponse(res);
  }

  Future<void> validateOrder(int orderId) async {
    final body = json.encode({'idwarehouse': 0, 'notrigger': 0});
    final uri = Uri.parse('${ApiConfig.baseUrl}/orders/$orderId/validate');
    final res = await http.post(uri, headers: _headers, body: body);
    _checkResponse(res);
  }

  // ── Factures ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getClientInvoices(int socid) async {
    final params = {
      'sortfield': 't.datef',
      'sortorder': 'DESC',
      'limit': '50',
      'sqlfilters': "(t.fk_soc:=:$socid)",
    };
    final uri = Uri.parse('${ApiConfig.baseUrl}/invoices').replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode == 404) return [];
    _checkResponse(res);
    final List data = json.decode(res.body);
    return data.cast<Map<String, dynamic>>();
  }

  // ── Utilitaire ────────────────────────────────────────────────────────────

  void _checkResponse(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String msg = 'Erreur API ${res.statusCode}';
      try {
        final data = json.decode(res.body);
        if (data is Map && data['error'] != null) {
          msg = data['error']['message']?.toString() ?? msg;
        }
      } catch (_) {}
      throw ApiException(msg, res.statusCode);
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
// EXTENSION — ajoutée par Claude (phase 2)
extension OrderDetailApi on DolibarrApiService {
  Future<Map<String, dynamic>> getOrder(int orderId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/orders/$orderId');
    final res = await http.get(uri, headers: _headers);
    _checkResponse(res);
    return json.decode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getOrderLines(int orderId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/orders/$orderId/lines');
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode == 404) return [];
    _checkResponse(res);
    final List data = json.decode(res.body);
    return data.cast<Map<String, dynamic>>();
  }

  Future<void> updateOrderLine(int orderId, int lineId, double qty, {double? unitPrice, double? vatRate}) async {
    final body = json.encode({
      'qty': qty,
      if (unitPrice != null) 'subprice': unitPrice,
      if (vatRate != null) 'tva_tx': vatRate,
    });
    final uri = Uri.parse('\${ApiConfig.baseUrl}/orders/$orderId/lines/$lineId');
    final res = await http.put(uri, headers: _headers, body: body);
    _checkResponse(res);
  }

  Future<void> deleteOrderLine(int orderId, int lineId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/orders/$orderId/lines/$lineId');
    final res = await http.delete(uri, headers: _headers);
    _checkResponse(res);
  }

  Future<void> cancelOrder(int orderId) async {
    final body = json.encode({'notrigger': 0});
    final uri = Uri.parse('${ApiConfig.baseUrl}/orders/$orderId/cancel');
    final res = await http.post(uri, headers: _headers, body: body);
    _checkResponse(res);
  }
}
