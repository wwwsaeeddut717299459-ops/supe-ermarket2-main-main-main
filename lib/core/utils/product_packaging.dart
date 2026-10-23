import 'dart:convert';

/// Packaging metadata is kept in the existing unit column to remain compatible
/// with databases created by older versions of the app.
class ProductPackaging {
  final int piecesPerCarton;
  final double cartonSellingPrice;
  final String cartonBarcode;
  const ProductPackaging({required this.piecesPerCarton, required this.cartonSellingPrice, this.cartonBarcode = ''});

  static const marker = '__almajed_packaging__:';

  static ProductPackaging fromUnit(String unit, {required double piecePrice}) {
    if (unit.startsWith(marker)) {
      try {
        final map = jsonDecode(unit.substring(marker.length)) as Map<String, dynamic>;
        return ProductPackaging(
          piecesPerCarton: ((map['piecesPerCarton'] as num?)?.toInt() ?? 1).clamp(1, 100000).toInt(),
          cartonSellingPrice: (map['cartonSellingPrice'] as num?)?.toDouble() ?? piecePrice,
          cartonBarcode: (map['cartonBarcode'] as String?) ?? '',
        );
      } catch (_) {}
    }
    return ProductPackaging(piecesPerCarton: 1, cartonSellingPrice: piecePrice);
  }

  static String encode({required int piecesPerCarton, required double cartonSellingPrice, String cartonBarcode = ''}) =>
      '$marker${jsonEncode({'piecesPerCarton': piecesPerCarton, 'cartonSellingPrice': cartonSellingPrice, 'cartonBarcode': cartonBarcode.trim()})}';

  static bool isConfigured(String unit) => unit.startsWith(marker);
  static String displayUnit(String unit) => isConfigured(unit) ? 'حبة / كرتون' : unit;
}
