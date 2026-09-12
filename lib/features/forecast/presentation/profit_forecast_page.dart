import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/database_providers.dart';
import '../../../services/business_analytics_service.dart';

class ProfitForecastPage extends ConsumerStatefulWidget {
  const ProfitForecastPage({super.key});
  @override
  ConsumerState<ProfitForecastPage> createState() => _ProfitForecastPageState();
}

class _ProfitForecastPageState extends ConsumerState<ProfitForecastPage> {
  int _historyDays = 90;
  int _forecastDays = 30;
  late Future<ProfitForecast> _forecast;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _forecast = ref
      .read(businessAnalyticsServiceProvider)
      .forecast(historyDays: _historyDays, forecastDays: _forecastDays);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('التنبؤ بالأرباح'),
          actions: [
            IconButton(
              onPressed: () => setState(_load),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: FutureBuilder<ProfitForecast>(
          future: _forecast,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError)
              return Center(
                child: Text('تعذر إعداد التنبؤ: ${snapshot.error}'),
              );
            return _content(snapshot.data!);
          },
        ),
      ),
    );
  }

  Widget _content(ProfitForecast forecast) {
    final cards = [
      _metric(
        'المبيعات التاريخية',
        forecast.historicalSales.toStringAsFixed(2),
        Icons.point_of_sale,
        Colors.blue,
      ),
      _metric(
        'تكلفة البضاعة',
        forecast.historicalCost.toStringAsFixed(2),
        Icons.inventory_2,
        Colors.orange,
      ),
      _metric(
        'الربح التاريخي',
        forecast.historicalProfit.toStringAsFixed(2),
        Icons.trending_up,
        Colors.green,
      ),
      _metric(
        'هامش الربح',
        '${(forecast.margin * 100).toStringAsFixed(1)}%',
        Icons.percent,
        Colors.teal,
      ),
      _metric(
        'متوسط البيع اليومي',
        forecast.averageDailySales.toStringAsFixed(2),
        Icons.show_chart,
        Colors.indigo,
      ),
      _metric(
        'متوسط الربح اليومي',
        forecast.averageDailyProfit.toStringAsFixed(2),
        Icons.analytics,
        Colors.purple,
      ),
      _metric(
        'المبيعات المتوقعة',
        forecast.projectedSales.toStringAsFixed(2),
        Icons.insights,
        Colors.blueAccent,
      ),
      _metric(
        'الأرباح المتوقعة',
        forecast.projectedProfit.toStringAsFixed(2),
        Icons.account_balance,
        Colors.green,
      ),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _filters(),
          const SizedBox(height: 18),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.sizeOf(context).width > 900 ? 4 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: cards,
          ),
          const SizedBox(height: 20),
          Card(
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'التنبؤ مبني على متوسط أداء آخر ${forecast.historyDays} يومًا، ويقدّر ${forecast.forecastDays} يومًا قادمة بافتراض ثبات نمط المبيعات وتكلفة الشراء والهامش الحالي. استخدمه كمؤشر تخطيطي وليس كضمان للربح.',
                style: const TextStyle(height: 1.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String title, String value, IconData icon, Color color) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withAlpha(28),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _filters() => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 24,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('فترة التحليل:'),
          DropdownButton<int>(
            value: _historyDays,
            items: const [
              DropdownMenuItem(value: 30, child: Text('آخر 30 يومًا')),
              DropdownMenuItem(value: 60, child: Text('آخر 60 يومًا')),
              DropdownMenuItem(value: 90, child: Text('آخر 90 يومًا')),
              DropdownMenuItem(value: 180, child: Text('آخر 180 يومًا')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _historyDays = value;
                _load();
              });
            },
          ),
          const Text('فترة التنبؤ:'),
          DropdownButton<int>(
            value: _forecastDays,
            items: const [
              DropdownMenuItem(value: 30, child: Text('30 يومًا')),
              DropdownMenuItem(value: 60, child: Text('60 يومًا')),
              DropdownMenuItem(value: 90, child: Text('90 يومًا')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _forecastDays = value;
                _load();
              });
            },
          ),
        ],
      ),
    ),
  );
}
