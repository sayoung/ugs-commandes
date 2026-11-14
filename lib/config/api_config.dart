class ApiConfig {
  static const String baseUrl = 'https://gestion.ugs.ma/api/index.php';
  static const String apiKey = '4HYw6Z6Oap8DtioLz9lOR1C6Ii80lTp4';
  static const String apiKeyStorageKey = 'dolapikey';

  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'DOLAPIKEY': apiKey,
      };
}
