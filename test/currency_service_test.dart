import 'package:flutter_test/flutter_test.dart';
import 'package:almajed_pro/services/currency_service.dart';

void main() {
  test('YER and SAR conversion is reversible', () {
    final currency = CurrencyService()..sarToYer = 410;
    expect(currency.toYer(100, currency: 'SAR'), 41000);
    expect(currency.fromYer(41000, currency: 'SAR'), 100);
    expect(currency.convert(100, from: 'SAR', to: 'YER'), 41000);
    expect(currency.convert(41000, from: 'YER', to: 'SAR'), 100);
  });

  test('same currency conversion is unchanged', () {
    final currency = CurrencyService();
    expect(currency.convert(123.45, from: 'YER', to: 'YER'), 123.45);
    expect(currency.convert(123.45, from: 'SAR', to: 'SAR'), 123.45);
  });

  test('invalid amounts and rates are rejected', () {
    final currency = CurrencyService();
    expect(() => currency.toYer(double.nan, currency: 'YER'), throwsArgumentError);
    expect(() => currency.fromYer(double.infinity, currency: 'YER'), throwsArgumentError);
    expect(() => currency.convert(10, from: 'USD', to: 'YER'), throwsArgumentError);
  });
}
