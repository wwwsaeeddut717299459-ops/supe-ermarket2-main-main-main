import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/database_providers.dart';
import '../../../services/dashboard_service.dart';

// ================================================================
// Dashboard Provider
// ================================================================

final dashboardMetricsProvider =
    FutureProvider<DashboardMetrics>((ref) async {
  final service = ref.watch(dashboardServiceProvider);

  return service.load();
});

// ================================================================
// Static Metric Definitions
//
// هذه البيانات ثابتة ولا داعي لإنشائها داخل build.
// القيم نفسها يتم أخذها من DashboardMetrics عند العرض.
// ================================================================

const List<_MetricDefinition> _metricDefinitions = [
  _MetricDefinition(
    title: 'مبيعات اليوم',
    subtitle: 'الفواتير المكتملة',
    icon: Icons.point_of_sale_rounded,
    color: Colors.blue,
  ),
  _MetricDefinition(
    title: 'مشتريات اليوم',
    subtitle: 'الفواتير غير الملغاة',
    icon: Icons.shopping_cart_rounded,
    color: Colors.indigo,
  ),
  _MetricDefinition(
    title: 'أرباح اليوم',
    subtitle: 'بعد التكلفة والمصروفات',
    icon: Icons.trending_up_rounded,
    color: Colors.green,
  ),
  _MetricDefinition(
    title: 'مصروفات اليوم',
    subtitle: 'المصروفات المسجلة',
    icon: Icons.money_off_rounded,
    color: Colors.red,
  ),
  _MetricDefinition(
    title: 'عدد المنتجات',
    subtitle: 'منتجات نشطة',
    icon: Icons.inventory_2_rounded,
    color: Colors.orange,
  ),
  _MetricDefinition(
    title: 'العملاء',
    subtitle: 'عملاء نشطون',
    icon: Icons.people_alt_rounded,
    color: Colors.teal,
  ),
  _MetricDefinition(
    title: 'الموردون',
    subtitle: 'موردون نشطون',
    icon: Icons.local_shipping_rounded,
    color: Colors.purple,
  ),
  _MetricDefinition(
    title: 'رصيد الصندوق',
    subtitle: 'من دفتر الحسابات',
    icon: Icons.account_balance_wallet_rounded,
    color: Colors.amber,
  ),
];

// ================================================================
// Static Quick Access Definitions
//
// لا يتم إنشاء هذه القائمة أثناء build.
// ================================================================

const List<_QuickAccessData> _quickAccessItems = [
  _QuickAccessData(
    index: 1,
    title: 'نقطة البيع',
    icon: Icons.point_of_sale_rounded,
  ),
  _QuickAccessData(
    index: 2,
    title: 'المنتجات والتصنيفات',
    icon: Icons.inventory_2_rounded,
  ),
  _QuickAccessData(
    index: 3,
    title: 'المخزون',
    icon: Icons.warehouse_rounded,
  ),
  _QuickAccessData(
    index: 4,
    title: 'المبيعات',
    icon: Icons.receipt_long_rounded,
  ),
  _QuickAccessData(
    index: 5,
    title: 'المشتريات',
    icon: Icons.shopping_cart_rounded,
  ),
  _QuickAccessData(
    index: 6,
    title: 'العملاء والذمم',
    icon: Icons.people_alt_rounded,
  ),
  _QuickAccessData(
    index: 7,
    title: 'الموردون',
    icon: Icons.local_shipping_rounded,
  ),
  _QuickAccessData(
    index: 8,
    title: 'المصروفات',
    icon: Icons.money_off_rounded,
  ),
  _QuickAccessData(
    index: 9,
    title: 'الحسابات',
    icon: Icons.account_balance_wallet_rounded,
  ),
  _QuickAccessData(
    index: 10,
    title: 'النسخ والاستعادة',
    icon: Icons.backup_rounded,
  ),
  _QuickAccessData(
    index: 11,
    title: 'التقارير',
    icon: Icons.bar_chart_rounded,
  ),
  _QuickAccessData(
    index: 12,
    title: 'التحقق الآلي',
    icon: Icons.fact_check_rounded,
  ),
  _QuickAccessData(
    index: 13,
    title: 'المرتجعات',
    icon: Icons.assignment_return_rounded,
  ),
  _QuickAccessData(
    index: 14,
    title: 'إعدادات الفاتورة',
    icon: Icons.settings_rounded,
  ),
  _QuickAccessData(
    index: 15,
    title: 'كل الفواتير',
    icon: Icons.receipt_rounded,
  ),
  _QuickAccessData(
    index: 16,
    title: 'تنبؤ الأرباح',
    icon: Icons.insights_rounded,
  ),
];

// ================================================================
// Dashboard Page
// ================================================================

class DashboardPage extends ConsumerWidget {
  final ValueChanged<int>? onNavigate;

  const DashboardPage({
    super.key,
    this.onNavigate,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final metricsAsync =
        ref.watch(dashboardMetricsProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            Theme.of(context)
                .colorScheme
                .surfaceContainerLowest,
        appBar: _buildAppBar(
          context,
          ref,
        ),
        body: metricsAsync.when(
          // مهم:
          // عند refresh لا يتم إخفاء البيانات الحالية.
          loading: () => const _DashboardLoading(),

          error: (
            error,
            stackTrace,
          ) {
            // إذا كانت هناك بيانات قديمة وأثناء refresh
            // حدث خطأ، نبقي البيانات القديمة ظاهرة.
            if (metricsAsync.hasValue) {
              return _DashboardContent(
                metrics: metricsAsync.requireValue,
                onNavigate: onNavigate,
                onRefresh: () => _refresh(ref),
              );
            }

            return _ErrorState(
              onRetry: () => _refresh(ref),
            );
          },

          data: (metrics) {
            return _DashboardContent(
              metrics: metrics,
              onNavigate: onNavigate,
              onRefresh: () => _refresh(ref),
            );
          },

          // يمنع ظهور Loading عند refresh
          skipLoadingOnRefresh: true,

          // لا نحتاج إلى إخفاء البيانات السابقة
          // أثناء إعادة جلب البيانات.
          skipError: true,
        ),
      ),
    );
  }

  // ============================================================
  // Refresh
  // ============================================================

  Future<void> _refresh(
    WidgetRef ref,
  ) async {
    await ref.refresh(
      dashboardMetricsProvider.future,
    );
  }

  // ============================================================
  // App Bar
  // ============================================================

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    WidgetRef ref,
  ) {
    final theme =
        Theme.of(context);

    final colorScheme =
        theme.colorScheme;

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor:
          colorScheme.surface,
      surfaceTintColor:
          Colors.transparent,
      toolbarHeight: 70,
      titleSpacing: 28,

      title: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color:
                  colorScheme.primaryContainer,
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.dashboard_rounded,
              color:
                  colorScheme.primary,
              size: 23,
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Text(
                'لوحة التحكم',
                style: theme
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              Text(
                'نظرة عامة على نشاط النظام',
                style: theme
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color: colorScheme
                      .onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),

      actions: [
        Padding(
          padding:
              const EdgeInsetsDirectional.only(
            end: 20,
          ),
          child: _HeaderButton(
            tooltip:
                'تحديث البيانات',
            icon:
                Icons.refresh_rounded,
            onPressed: () {
              _refresh(ref);
            },
          ),
        ),
      ],

      bottom: PreferredSize(
        preferredSize:
            const Size.fromHeight(1),
        child: Divider(
          height: 1,
          thickness: 1,
          color:
              colorScheme.outlineVariant,
        ),
      ),
    );
  }
}

// ================================================================
// Dashboard Content
// ================================================================

class _DashboardContent
    extends StatelessWidget {
  final DashboardMetrics metrics;
  final ValueChanged<int>? onNavigate;
  final Future<void> Function() onRefresh;

  const _DashboardContent({
    required this.metrics,
    required this.onNavigate,
    required this.onRefresh,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return RefreshIndicator(
      onRefresh: onRefresh,

      child: SingleChildScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(),

        padding:
            const EdgeInsets.fromLTRB(
          28,
          24,
          28,
          40,
        ),

        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 1600,
            ),

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,

              children: [
                _buildWelcomeCard(
                  context,
                  metrics,
                ),

                const SizedBox(
                  height: 24,
                ),

                const _SectionHeader(
                  title: 'ملخص اليوم',
                  subtitle:
                      'نظرة سريعة على أهم مؤشرات النظام',
                ),

                const SizedBox(
                  height: 14,
                ),

                _buildMetricsGrid(
                  context,
                  metrics,
                ),

                const SizedBox(
                  height: 30,
                ),

                const _SectionHeader(
                  title: 'الوصول السريع',
                  subtitle:
                      'انتقل مباشرة إلى القسم الذي تحتاجه',
                ),

                const SizedBox(
                  height: 14,
                ),

                _buildQuickAccess(
                  context,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Welcome Card
  // ============================================================

  Widget _buildWelcomeCard(
    BuildContext context,
    DashboardMetrics metrics,
  ) {
    final theme =
        Theme.of(context);

    final colorScheme =
        theme.colorScheme;

    return Container(
      decoration:
          BoxDecoration(
        gradient:
            LinearGradient(
          begin:
              Alignment.centerRight,
          end:
              Alignment.centerLeft,
          colors: [
            colorScheme.primary,
            colorScheme.primary
                .withValues(
              alpha: 0.86,
            ),
          ],
        ),

        borderRadius:
            BorderRadius.circular(
          22,
        ),

        boxShadow: [
          BoxShadow(
            color:
                colorScheme.primary
                    .withValues(
              alpha: 0.18,
            ),
            blurRadius: 24,
            offset:
                const Offset(0, 10),
          ),
        ],
      ),

      child: Stack(
        children: [
          PositionedDirectional(
            end: -30,
            top: -45,
            child: Container(
              width: 180,
              height: 180,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color:
                    Colors.white
                        .withValues(
                  alpha: 0.06,
                ),
              ),
            ),
          ),

          PositionedDirectional(
            start: 80,
            bottom: -70,
            child: Container(
              width: 170,
              height: 170,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color:
                    Colors.white
                        .withValues(
                  alpha: 0.04,
                ),
              ),
            ),
          ),

          Padding(
            padding:
                const EdgeInsets.all(
              26,
            ),
            child: LayoutBuilder(
              builder: (
                context,
                constraints,
              ) {
                final compact =
                    constraints.maxWidth <
                        650;

                if (compact) {
                  return Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .stretch,
                    children: [
                      _buildWelcomeInfo(
                        context,
                        metrics,
                      ),
                      const SizedBox(
                        height: 24,
                      ),
                      _buildCashBalance(
                        context,
                        metrics,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child:
                          _buildWelcomeInfo(
                        context,
                        metrics,
                      ),
                    ),

                    const SizedBox(
                      width: 30,
                    ),

                    _buildCashBalance(
                      context,
                      metrics,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Welcome Information
  // ============================================================

  Widget _buildWelcomeInfo(
    BuildContext context,
    DashboardMetrics metrics,
  ) {
    final theme =
        Theme.of(context);

    return Row(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration:
              BoxDecoration(
            color:
                Colors.white.withValues(
              alpha: 0.14,
            ),
            borderRadius:
                BorderRadius.circular(
              17,
            ),
            border:
                Border.all(
              color:
                  Colors.white.withValues(
                alpha: 0.15,
              ),
            ),
          ),
          child:
              const Icon(
            Icons.storefront_rounded,
            color: Colors.white,
            size: 29,
          ),
        ),

        const SizedBox(
          width: 16,
        ),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'ملخص أعمال اليوم',
                style: theme
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                  color: Colors.white,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              const SizedBox(
                height: 7,
              ),

              Text(
                'آخر تحديث: ${_formatDate(metrics.from)}',
                style: theme
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                  color:
                      Colors.white
                          .withValues(
                    alpha: 0.78,
                  ),
                ),
              ),

              const SizedBox(
                height: 3,
              ),

              Text(
                'البيانات محدثة من قاعدة بيانات النظام',
                style: theme
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color:
                      Colors.white
                          .withValues(
                    alpha: 0.62,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // Cash Balance
  // ============================================================

  Widget _buildCashBalance(
    BuildContext context,
    DashboardMetrics metrics,
  ) {
    return Container(
      constraints:
          const BoxConstraints(
        minWidth: 210,
      ),

      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 16,
      ),

      decoration:
          BoxDecoration(
        color:
            Colors.white.withValues(
          alpha: 0.10,
        ),
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        border:
            Border.all(
          color:
              Colors.white.withValues(
            alpha: 0.13,
          ),
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Icon(
                Icons
                    .account_balance_wallet_outlined,
                size: 18,
                color:
                    Colors.white
                        .withValues(
                  alpha: 0.75,
                ),
              ),

              const SizedBox(
                width: 7,
              ),

              Text(
                'رصيد الصندوق',
                style: TextStyle(
                  color:
                      Colors.white
                          .withValues(
                    alpha: 0.78,
                  ),
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 7,
          ),

          Text(
            _formatMoney(
              metrics.cashBalance,
            ),
            style:
                const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Metrics Grid
  // ============================================================

  Widget _buildMetricsGrid(
    BuildContext context,
    DashboardMetrics metrics,
  ) {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final columns =
            _calculateColumns(
          constraints.maxWidth,
          large: 4,
          medium: 3,
          small: 2,
        );

        return GridView.builder(
          shrinkWrap: true,
          physics:
              const NeverScrollableScrollPhysics(),

          padding:
              EdgeInsets.zero,

          itemCount:
              _metricDefinitions.length,

          gridDelegate:
              SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:
                columns,
            crossAxisSpacing:
                14,
            mainAxisSpacing:
                14,
            mainAxisExtent:
                145,
          ),

          itemBuilder: (
            context,
            index,
          ) {
            final definition =
                _metricDefinitions[
                    index];

            final value =
                _metricValue(
              metrics,
              index,
            );

            return DashboardMetricCard(
              key: ValueKey(
                definition.title,
              ),
              data:
                  _MetricCardData(
                title:
                    definition.title,
                value:
                    value,
                subtitle:
                    definition.subtitle,
                icon:
                    definition.icon,
                color:
                    definition.color,
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // Metric Value
  // ============================================================

  String _metricValue(
    DashboardMetrics metrics,
    int index,
  ) {
    switch (index) {
      case 0:
        return _formatMoney(
          metrics.salesToday,
        );

      case 1:
        return _formatMoney(
          metrics.purchasesToday,
        );

      case 2:
        return _formatMoney(
          metrics.profitToday,
        );

      case 3:
        return _formatMoney(
          metrics.expensesToday,
        );

      case 4:
        return '${metrics.productsCount}';

      case 5:
        return '${metrics.customersCount}';

      case 6:
        return '${metrics.suppliersCount}';

      case 7:
        return _formatMoney(
          metrics.cashBalance,
        );

      default:
        return '-';
    }
  }

  // ============================================================
  // Quick Access
  // ============================================================

  Widget _buildQuickAccess(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(22),

      decoration:
          BoxDecoration(
        color:
            Theme.of(context)
                .colorScheme
                .surface,

        borderRadius:
            BorderRadius.circular(
          20,
        ),

        border:
            Border.all(
          color:
              Theme.of(context)
                  .colorScheme
                  .outlineVariant,
        ),
      ),

      child: LayoutBuilder(
        builder: (
          context,
          constraints,
        ) {
          final columns =
              _calculateColumns(
            constraints.maxWidth,
            large: 4,
            medium: 3,
            small: 2,
          );

          return GridView.builder(
            shrinkWrap: true,

            physics:
                const NeverScrollableScrollPhysics(),

            padding:
                EdgeInsets.zero,

            itemCount:
                _quickAccessItems.length,

            gridDelegate:
                SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount:
                  columns,

              crossAxisSpacing:
                  12,

              mainAxisSpacing:
                  12,

              mainAxisExtent:
                  62,
            ),

            itemBuilder: (
              context,
              index,
            ) {
              final item =
                  _quickAccessItems[
                      index];

              return _QuickAccessItem(
                key: ValueKey(
                  item.index,
                ),
                title:
                    item.title,
                icon:
                    item.icon,
                onTap:
                    onNavigate == null
                        ? null
                        : () =>
                            onNavigate!(
                              item.index,
                            ),
              );
            },
          );
        },
      ),
    );
  }
}

// ================================================================
// Metric Definition
// ================================================================

class _MetricDefinition {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MetricDefinition({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

// ================================================================
// Metric Card Data
// ================================================================

class _MetricCardData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MetricCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

// ================================================================
// Quick Access Data
// ================================================================

class _QuickAccessData {
  final int index;
  final String title;
  final IconData icon;

  const _QuickAccessData({
    required this.index,
    required this.title,
    required this.icon,
  });
}

// ================================================================
// Dashboard Metric Card
// ================================================================

class DashboardMetricCard
    extends StatefulWidget {
  final _MetricCardData data;

  const DashboardMetricCard({
    super.key,
    required this.data,
  });

  @override
  State<DashboardMetricCard>
      createState() =>
          _DashboardMetricCardState();
}

class _DashboardMetricCardState
    extends State<DashboardMetricCard> {
  bool _hovered = false;

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colorScheme =
        theme.colorScheme;

    final data =
        widget.data;

    return MouseRegion(
      cursor:
          SystemMouseCursors.basic,

      onEnter: (_) {
        if (!_hovered) {
          setState(() {
            _hovered = true;
          });
        }
      },

      onExit: (_) {
        if (_hovered) {
          setState(() {
            _hovered = false;
          });
        }
      },

      child: AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 160,
        ),

        transform:
            Matrix4.translationValues(
          0,
          _hovered ? -2 : 0,
          0,
        ),

        decoration:
            BoxDecoration(
          color:
              colorScheme.surface,

          borderRadius:
              BorderRadius.circular(
            18,
          ),

          border:
              Border.all(
            color: _hovered
                ? data.color.withValues(
                    alpha: 0.35,
                  )
                : colorScheme
                    .outlineVariant,
          ),

          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: data.color
                        .withValues(
                      alpha: 0.10,
                    ),
                    blurRadius: 18,
                    offset:
                        const Offset(
                      0,
                      7,
                    ),
                  ),
                ]
              : null,
        ),

        child: Padding(
          padding:
              const EdgeInsets.all(
            17,
          ),

          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,

                decoration:
                    BoxDecoration(
                  color:
                      data.color
                          .withValues(
                    alpha: 0.10,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),

                child: Icon(
                  data.icon,
                  color:
                      data.color,
                  size: 24,
                ),
              ),

              const SizedBox(
                width: 13,
              ),

              Expanded(
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,

                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,

                  children: [
                    Text(
                      data.title,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style: theme
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                        fontWeight:
                            FontWeight
                                .w600,
                        color: colorScheme
                            .onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      data.value,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style: theme
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                        fontWeight:
                            FontWeight
                                .w800,
                        color:
                            data.color,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      data.subtitle,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style: theme
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                        color: colorScheme
                            .onSurfaceVariant
                            .withValues(
                          alpha: 0.75,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// Quick Access Item
// ================================================================

class _QuickAccessItem
    extends StatefulWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onTap;

  const _QuickAccessItem({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_QuickAccessItem>
      createState() =>
          _QuickAccessItemState();
}

class _QuickAccessItemState
    extends State<_QuickAccessItem> {
  bool _hovered = false;

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colorScheme =
        theme.colorScheme;

    return MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,

      onEnter: (_) {
        if (!_hovered) {
          setState(() {
            _hovered = true;
          });
        }
      },

      onExit: (_) {
        if (_hovered) {
          setState(() {
            _hovered = false;
          });
        }
      },

      child: Material(
        color:
            Colors.transparent,

        child: InkWell(
          onTap:
              widget.onTap,

          borderRadius:
              BorderRadius.circular(
            14,
          ),

          child: AnimatedContainer(
            duration:
                const Duration(
              milliseconds: 150,
            ),

            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 13,
            ),

            decoration:
                BoxDecoration(
              color: _hovered
                  ? colorScheme
                      .primaryContainer
                  : colorScheme
                      .surfaceContainerLowest,

              borderRadius:
                  BorderRadius.circular(
                14,
              ),

              border:
                  Border.all(
                color: _hovered
                    ? colorScheme
                        .primary
                        .withValues(
                        alpha: 0.25,
                      )
                    : colorScheme
                        .outlineVariant,
              ),
            ),

            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,

                  decoration:
                      BoxDecoration(
                    color: _hovered
                        ? colorScheme
                            .primary
                        : colorScheme
                            .primaryContainer,

                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                  ),

                  child: Icon(
                    widget.icon,
                    size: 19,
                    color: _hovered
                        ? colorScheme
                            .onPrimary
                        : colorScheme
                            .primary,
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),

                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style: theme
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),

                Icon(
                  Icons
                      .chevron_left_rounded,
                  size: 19,
                  color: colorScheme
                      .onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// Section Header
// ================================================================

class _SectionHeader
    extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colorScheme =
        theme.colorScheme;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme
              .textTheme
              .titleLarge
              ?.copyWith(
            fontWeight:
                FontWeight.w800,
            color:
                colorScheme.onSurface,
          ),
        ),

        const SizedBox(
          height: 4,
        ),

        Text(
          subtitle,
          style: theme
              .textTheme
              .bodySmall
              ?.copyWith(
            color:
                colorScheme
                    .onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ================================================================
// Header Button
// ================================================================

class _HeaderButton
    extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _HeaderButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final colorScheme =
        Theme.of(context)
            .colorScheme;

    return IconButton(
      tooltip:
          tooltip,

      onPressed:
          onPressed,

      icon:
          Icon(icon),

      style:
          IconButton.styleFrom(
        foregroundColor:
            colorScheme
                .onSurfaceVariant,

        backgroundColor:
            colorScheme
                .surfaceContainerHighest,

        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(
            12,
          ),
        ),
      ),
    );
  }
}

// ================================================================
// Loading State
// ================================================================

class _DashboardLoading
    extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(
    BuildContext context,
  ) {
    final colorScheme =
        Theme.of(context)
            .colorScheme;

    return Center(
      child: Column(
        mainAxisSize:
            MainAxisSize.min,

        children: [
          SizedBox(
            width: 34,
            height: 34,

            child:
                CircularProgressIndicator(
              strokeWidth: 3,
              color:
                  colorScheme.primary,
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          Text(
            'جاري تحميل بيانات لوحة التحكم...',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(
              color:
                  colorScheme
                      .onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// Error State
// ================================================================

class _ErrorState
    extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({
    required this.onRetry,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colorScheme =
        theme.colorScheme;

    return Center(
      child: Container(
        constraints:
            const BoxConstraints(
          maxWidth: 420,
        ),

        margin:
            const EdgeInsets.all(
          24,
        ),

        padding:
            const EdgeInsets.all(
          28,
        ),

        decoration:
            BoxDecoration(
          color:
              colorScheme.surface,

          borderRadius:
              BorderRadius.circular(
            20,
          ),

          border:
              Border.all(
            color:
                colorScheme
                    .outlineVariant,
          ),
        ),

        child: Column(
          mainAxisSize:
              MainAxisSize.min,

          children: [
            Container(
              width: 62,
              height: 62,

              decoration:
                  BoxDecoration(
                color: colorScheme
                    .errorContainer,
                shape:
                    BoxShape.circle,
              ),

              child: Icon(
                Icons.cloud_off_rounded,
                size: 30,
                color:
                    colorScheme.error,
              ),
            ),

            const SizedBox(
              height: 18,
            ),

            Text(
              'تعذر تحميل لوحة التحكم',
              textAlign:
                  TextAlign.center,

              style: theme
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                fontWeight:
                    FontWeight.w800,
              ),
            ),

            const SizedBox(
              height: 7,
            ),

            Text(
              'حدث خطأ أثناء قراءة بيانات النظام. '
              'تأكد من قاعدة البيانات ثم حاول مرة أخرى.',

              textAlign:
                  TextAlign.center,

              style: theme
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                color: colorScheme
                    .onSurfaceVariant,
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            FilledButton.icon(
              onPressed:
                  onRetry,

              icon: const Icon(
                Icons.refresh_rounded,
              ),

              label: const Text(
                'إعادة المحاولة',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// Utility
// ================================================================

int _calculateColumns(
  double width, {
  required int large,
  required int medium,
  required int small,
}) {
  if (width >= 1250) {
    return large;
  }

  if (width >= 900) {
    return medium;
  }

  if (width >= 600) {
    return small;
  }

  return 1;
}

String _formatMoney(
  double value,
) {
  return value.toStringAsFixed(2);
}

String _formatDate(
  DateTime date,
) {
  final local =
      date.toLocal();

  final day =
      local.day.toString().padLeft(
        2,
        '0',
      );

  final month =
      local.month.toString().padLeft(
        2,
        '0',
      );

  final year =
      local.year.toString();

  return '$year/$month/$day';
}
