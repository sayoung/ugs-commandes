class Product {
  final int id;
  final String ref;
  final String label;
  final String description;
  final double price;
  final String? imageUrl;
  final double? stock;
  final String? unit;

  Product({
    required this.id,
    required this.ref,
    required this.label,
    this.description = '',
    required this.price,
    this.imageUrl,
    this.stock,
    this.unit,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: int.tryParse(json['id'].toString()) ?? 0,
      ref: json['ref']?.toString() ?? '',
      label: json['label']?.toString() ?? json['ref']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      imageUrl: json['image_url']?.toString(),
      stock: double.tryParse(json['stock_reel']?.toString() ?? '0'),
      unit: json['unit_short']?.toString(),
    );
  }
}
