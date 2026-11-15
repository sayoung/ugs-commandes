import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import 'dolibarr_api.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();

  static String hashPassword(String password) {
    final bytes = utf8.encode(password + 'ugs_salt_2024');
    return sha256.convert(bytes).toString();
  }

  static Future<int> register({
    required String denomination,
    required String ice,
    required String address,
    required String email,
    required String password,
    String? phone,
  }) async {
    final api = DolibarrApiService(apiKey: ApiConfig.apiKey);
    // Empêcher les doublons : un seul tiers par email
    final existing = await api.findThirdPartyByEmail(email);
    if (existing != null) {
      throw ApiException(
          'Un compte existe déjà avec cet email. Connectez-vous avec votre mot de passe.', 409);
    }
    final id = await api.createThirdParty(
      denomination: denomination,
      ice: ice,
      address: address,
      email: email.toLowerCase().trim(),
      passwordHash: hashPassword(password),
      phone: phone,
    );
    await _saveSession(clientId: id, clientName: denomination, email: email);
    return id;
  }

  static Future<Map<String, dynamic>?> login(String email, String password) async {
    final api = DolibarrApiService(apiKey: ApiConfig.apiKey);
    final tiers = await api.verifyCredentials(
      email.toLowerCase().trim(),
      hashPassword(password),
    );
    if (tiers == null) return null;
    final id = int.parse(tiers['id'].toString());
    final name = tiers['name']?.toString() ?? email;
    await _saveSession(clientId: id, clientName: name, email: email);
    return tiers;
  }

  static Future<void> _saveSession({
    required int clientId,
    required String clientName,
    required String email,
  }) async {
    await _storage.write(key: 'session_active', value: '1');
    await _storage.write(key: 'client_id', value: clientId.toString());
    await _storage.write(key: 'client_name', value: clientName);
    await _storage.write(key: 'client_email', value: email.toLowerCase().trim());
  }

  static Future<Map<String, String?>> getSession() async {
    final active = await _storage.read(key: 'session_active');
    if (active != '1') return {};
    final clientId = await _storage.read(key: 'client_id');
    final clientName = await _storage.read(key: 'client_name');
    final clientEmail = await _storage.read(key: 'client_email');
    if (clientId == null) return {};
    return {
      'client_id': clientId,
      'client_name': clientName,
      'client_email': clientEmail,
    };
  }

  static Future<void> logout() async {
    await _storage.write(key: 'session_active', value: '0');
  }
}
