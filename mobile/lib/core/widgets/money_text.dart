import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';

String formatMoney(int priceCents, CurrencyCode currency) {
  final major = priceCents / 100.0;
  final symbol = switch (currency) {
    CurrencyCode.PHP => '₱',
    CurrencyCode.SGD => 'S\$',
    CurrencyCode.MYR => 'RM',
    CurrencyCode.IDR => 'Rp',
    CurrencyCode.USD => '\$',
    CurrencyCode.EUR => '€',
  };
  final digits = currency == CurrencyCode.IDR ? 0 : 2;
  final formatted = NumberFormat.currency(
    symbol: '',
    decimalDigits: digits,
  ).format(major);
  return '$symbol$formatted'.trim();
}

class MoneyText extends StatelessWidget {
  const MoneyText({
    super.key,
    required this.priceCents,
    required this.currency,
    this.style,
  });

  final int priceCents;
  final CurrencyCode currency;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      formatMoney(priceCents, currency),
      style: style,
    );
  }
}
