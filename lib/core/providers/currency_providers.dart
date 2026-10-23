import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:almajed_pro/core/services/currency_service.dart';

final currencyServiceProvider = Provider<CurrencyService>((ref) {
  return CurrencyService();
});
