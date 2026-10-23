import 'package:flutter/material.dart';

class TipsPage extends StatelessWidget {
  const TipsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tips = <TipItem>[
      // ============================================================
      // 💰 الأرباح والمبيعات
      // ============================================================

      TipItem(
        category: 'الأرباح والمبيعات',
        title: 'لا تعتمد على إجمالي المبيعات',
        text:
            'ارتفاع المبيعات لا يعني بالضرورة ارتفاع الأرباح. تابع صافي الربح بعد خصم تكلفة البضاعة والمرتجعات والمصروفات.',
        icon: Icons.trending_up_rounded,
      ),

      TipItem(
        category: 'الأرباح والمبيعات',
        title: 'اعرف تكلفة كل صنف',
        text:
            'قبل تخفيض سعر أي منتج، تأكد من معرفة تكلفته الفعلية حتى لا تبيع بخسارة دون أن تلاحظ.',
        icon: Icons.calculate_rounded,
      ),

      TipItem(
        category: 'الأرباح والمبيعات',
        title: 'راجع الأصناف الأكثر ربحاً',
        text:
            'لا تركز فقط على الأصناف الأكثر مبيعاً. بعض الأصناف قد تحقق مبيعات كبيرة بهامش ربح ضعيف، بينما أصناف أخرى تحقق ربحاً أعلى بعدد مبيعات أقل.',
        icon: Icons.insights_rounded,
      ),

      TipItem(
        category: 'الأرباح والمبيعات',
        title: 'راقب الخصومات',
        text:
            'الخصومات المتكررة والصغيرة قد تؤثر بشكل كبير على الربح الشهري. تابع إجمالي الخصومات وليس كل عملية بشكل منفصل فقط.',
        icon: Icons.discount_rounded,
      ),

      TipItem(
        category: 'الأرباح والمبيعات',
        title: 'لا تخلط مصروفات المحل الشخصية',
        text:
            'سحب صاحب المحل لأموال للاستخدام الشخصي يجب تسجيله كسحب أو حركة مستقلة، وليس كمصروف تشغيلي للمحل.',
        icon: Icons.account_balance_wallet_rounded,
      ),

      TipItem(
        category: 'الأرباح والمبيعات',
        title: 'راجع المبيعات اليومية',
        text:
            'اجعل مراجعة إجمالي المبيعات والتحصيل والمرتجعات والخصومات جزءاً من إغلاق كل يوم.',
        icon: Icons.point_of_sale_rounded,
      ),

      // ============================================================
      // 📦 المخزون
      // ============================================================

      TipItem(
        category: 'المخزون',
        title: 'لا تنتظر نفاد الصنف',
        text:
            'ضع حد إعادة طلب مناسب لكل صنف حتى تعرف متى يجب شراء كمية جديدة قبل نفاد المخزون.',
        icon: Icons.inventory_2_rounded,
      ),

      TipItem(
        category: 'المخزون',
        title: 'راقب الأصناف بطيئة الحركة',
        text:
            'وجود كمية كبيرة من صنف لا يتحرك يعني أن جزءاً من رأس المال متوقف داخل المخزون.',
        icon: Icons.hourglass_bottom_rounded,
      ),

      TipItem(
        category: 'المخزون',
        title: 'راجع الأصناف قريبة الانتهاء',
        text:
            'الأصناف التي تقترب من تاريخ الانتهاء تحتاج إلى متابعة مبكرة لتقليل التلف والخسائر.',
        icon: Icons.warning_amber_rounded,
      ),

      TipItem(
        category: 'المخزون',
        title: 'لا تعتمد على الرقم المسجل فقط',
        text:
            'قم بجرد فعلي للمخزون بشكل دوري وقارن الكمية الموجودة فعلياً بالكمية المسجلة في النظام.',
        icon: Icons.fact_check_rounded,
      ),

      TipItem(
        category: 'المخزون',
        title: 'سجل المرتجعات فوراً',
        text:
            'تأخير تسجيل المرتجعات يجعل المخزون والتقارير غير دقيقة، وقد يؤدي إلى بيع كمية غير موجودة فعلياً.',
        icon: Icons.assignment_return_rounded,
      ),

      TipItem(
        category: 'المخزون',
        title: 'تجنب التخزين الزائد',
        text:
            'شراء كميات أكبر من الحاجة لا يعني دائماً توفير المال؛ فقد يتجمد رأس المال أو تتلف البضاعة.',
        icon: Icons.warehouse_rounded,
      ),

      // ============================================================
      // 👥 العملاء والديون
      // ============================================================

      TipItem(
        category: 'العملاء والديون',
        title: 'ضع سقفاً ائتمانياً',
        text:
            'حدد الحد الأقصى للدين لكل عميل حسب قدرته على السداد وتاريخ تعاملاته مع المحل.',
        icon: Icons.credit_score_rounded,
      ),

      TipItem(
        category: 'العملاء والديون',
        title: 'لا تترك الديون دون متابعة',
        text:
            'راجع أرصدة العملاء بشكل دوري، وركز على الديون القديمة قبل السماح بزيادة المديونية.',
        icon: Icons.people_alt_rounded,
      ),

      TipItem(
        category: 'العملاء والديون',
        title: 'سجل كل دفعة',
        text:
            'أي مبلغ يدفعه العميل يجب تسجيله في النظام مباشرة حتى يبقى الرصيد الحقيقي واضحاً.',
        icon: Icons.payments_rounded,
      ),

      TipItem(
        category: 'العملاء والديون',
        title: 'ميز بين العميل المتأخر والجيد',
        text:
            'ليس كل العملاء بنفس مستوى المخاطرة. استخدم سجل السداد السابق عند اتخاذ قرار البيع الآجل.',
        icon: Icons.verified_user_rounded,
      ),

      // ============================================================
      // 🚚 الموردون والمشتريات
      // ============================================================

      TipItem(
        category: 'الموردون والمشتريات',
        title: 'قارن أسعار الموردين',
        text:
            'لا تعتمد دائماً على مورد واحد. مقارنة الأسعار وشروط الدفع تساعد على تقليل تكلفة الشراء.',
        icon: Icons.compare_arrows_rounded,
      ),

      TipItem(
        category: 'الموردون والمشتريات',
        title: 'راجع فواتير الشراء',
        text:
            'تأكد من مطابقة الكميات والأسعار والفواتير المستلمة قبل اعتماد عملية الشراء.',
        icon: Icons.receipt_long_rounded,
      ),

      TipItem(
        category: 'الموردون والمشتريات',
        title: 'راقب ديون الموردين',
        text:
            'معرفة المبالغ المستحقة للموردين تساعدك على التخطيط للتدفقات النقدية وتجنب التأخير في السداد.',
        icon: Icons.local_shipping_rounded,
      ),

      TipItem(
        category: 'الموردون والمشتريات',
        title: 'لا تشترِ لمجرد وجود عرض',
        text:
            'العرض الجيد لا يكون جيداً إذا كان الصنف بطيء الحركة أو سيستهلك رأس المال لفترة طويلة.',
        icon: Icons.shopping_cart_checkout_rounded,
      ),

      // ============================================================
      // 💵 النقدية والصندوق
      // ============================================================

      TipItem(
        category: 'النقدية والصندوق',
        title: 'طابق الصندوق يومياً',
        text:
            'قارن النقدية الموجودة فعلياً مع المبلغ المتوقع حسب المبيعات والتحصيل والمصروفات والسحوبات.',
        icon: Icons.account_balance_rounded,
      ),

      TipItem(
        category: 'النقدية والصندوق',
        title: 'سجل المصروف فوراً',
        text:
            'لا تؤجل تسجيل المصروفات؛ لأن المصروف غير المسجل يجعل الأرباح الظاهرة أعلى من الأرباح الحقيقية.',
        icon: Icons.money_off_csred_rounded,
      ),

      TipItem(
        category: 'النقدية والصندوق',
        title: 'تجنب السحوبات غير المسجلة',
        text:
            'أي مبلغ يخرج من الصندوق يجب أن يكون له سبب وسجل واضح حتى لا تظهر فروقات في نهاية اليوم.',
        icon: Icons.output_rounded,
      ),

      TipItem(
        category: 'النقدية والصندوق',
        title: 'حقق في فروقات الصندوق',
        text:
            'إذا وجدت فرقاً بين النقدية الفعلية والنظام، لا تعدله عشوائياً. ابحث عن سبب الفرق أولاً.',
        icon: Icons.search_rounded,
      ),

      // ============================================================
      // 💱 العملات وسعر الصرف
      // ============================================================

      TipItem(
        category: 'العملات وسعر الصرف',
        title: 'ثبت سعر الصرف قبل العملية',
        text:
            'عند التعامل بأكثر من عملة، تأكد من استخدام سعر الصرف الصحيح وقت تسجيل العملية.',
        icon: Icons.currency_exchange_rounded,
      ),

      TipItem(
        category: 'العملات وسعر الصرف',
        title: 'لا تخلط أسعار الصرف',
        text:
            'استخدام أسعار صرف مختلفة لنفس الفترة دون تسجيل واضح قد يؤدي إلى فروقات في الحسابات والأرباح.',
        icon: Icons.sync_alt_rounded,
      ),

      TipItem(
        category: 'العملات وسعر الصرف',
        title: 'راجع أثر تغير العملة',
        text:
            'عند تغير سعر الصرف بشكل كبير، راجع أسعار البيع وتكلفة المخزون حتى لا تستمر في البيع بأسعار قديمة.',
        icon: Icons.currency_exchange_rounded,
      ),

      // ============================================================
      // 👨‍💼 الموظفون
      // ============================================================

      TipItem(
        category: 'الموظفون',
        title: 'سجل السلف',
        text:
            'أي سلفة أو مبلغ يُصرف للموظف يجب تسجيله حتى يظهر الرصيد المستحق بشكل صحيح.',
        icon: Icons.badge_rounded,
      ),

      TipItem(
        category: 'الموظفون',
        title: 'افصل الصلاحيات',
        text:
            'ليس من الأفضل أن يمتلك كل موظف صلاحية تعديل الأسعار أو حذف الفواتير أو الوصول إلى التقارير المالية.',
        icon: Icons.admin_panel_settings_rounded,
      ),

      TipItem(
        category: 'الموظفون',
        title: 'راجع العمليات الحساسة',
        text:
            'راقب عمليات حذف الفواتير وتعديل الأسعار والمرتجعات والمصروفات، خصوصاً عند وجود أكثر من مستخدم.',
        icon: Icons.security_rounded,
      ),

      TipItem(
        category: 'الموظفون',
        title: 'لا تشارك حساب المستخدم',
        text:
            'اجعل لكل موظف حسابه الخاص حتى يمكن معرفة من قام بالعملية عند الحاجة إلى المراجعة.',
        icon: Icons.person_pin_rounded,
      ),

      // ============================================================
      // 📊 التقارير
      // ============================================================

      TipItem(
        category: 'التقارير',
        title: 'استخدم التقارير لاتخاذ القرار',
        text:
            'التقرير ليس مجرد رقم للطباعة. استخدمه لمعرفة المنتجات الأفضل، الديون، المصروفات، وحركة المخزون.',
        icon: Icons.bar_chart_rounded,
      ),

      TipItem(
        category: 'التقارير',
        title: 'قارن الفترات',
        text:
            'قارن المبيعات والأرباح والمصروفات بين الفترات لمعرفة هل أداء النشاط يتحسن أم يتراجع.',
        icon: Icons.compare_rounded,
      ),

      TipItem(
        category: 'التقارير',
        title: 'راقب المصروفات المتكررة',
        text:
            'المصروفات الصغيرة المتكررة قد تتحول إلى مبلغ كبير شهرياً. راجعها وابحث عن المصروفات التي يمكن تقليلها.',
        icon: Icons.analytics_rounded,
      ),

      // ============================================================
      // 🔐 البيانات والنسخ الاحتياطي
      // ============================================================

      TipItem(
        category: 'البيانات والنسخ الاحتياطي',
        title: 'خذ نسخة احتياطية بانتظام',
        text:
            'النسخة الاحتياطية تحمي بيانات المبيعات والعملاء والمخزون في حال تعطل الجهاز أو تلف قاعدة البيانات.',
        icon: Icons.backup_rounded,
      ),

      TipItem(
        category: 'البيانات والنسخ الاحتياطي',
        title: 'لا تحفظ النسخة على نفس الجهاز فقط',
        text:
            'إذا تعطل الجهاز أو القرص، قد تفقد النسخة أيضاً. احتفظ بنسخة في مكان آمن آخر.',
        icon: Icons.cloud_upload_rounded,
      ),

      TipItem(
        category: 'البيانات والنسخ الاحتياطي',
        title: 'اختبر الاستعادة',
        text:
            'وجود ملف Backup لا يكفي. اختبر عملية الاستعادة بشكل دوري للتأكد من أن النسخة قابلة للاستخدام.',
        icon: Icons.restore_rounded,
      ),

      // ============================================================
      // 🧾 إغلاق اليوم
      // ============================================================

      TipItem(
        category: 'إغلاق اليوم',
        title: 'لا تغلق اليوم دون مراجعة',
        text:
            'قبل نهاية اليوم راجع المبيعات والمرتجعات والتحصيل والمصروفات والنقدية وأي فروقات.',
        icon: Icons.event_available_rounded,
      ),

      TipItem(
        category: 'إغلاق اليوم',
        title: 'راجع العمليات غير المعتادة',
        text:
            'الفواتير الكبيرة جداً، الخصومات غير المعتادة، المرتجعات المتكررة أو التعديلات الحساسة تستحق المراجعة.',
        icon: Icons.priority_high_rounded,
      ),

      TipItem(
        category: 'إغلاق اليوم',
        title: 'احتفظ بتقرير اليوم',
        text:
            'الاحتفاظ بتقارير يومية يساعدك على معرفة أداء النشاط والرجوع إلى العمليات السابقة عند حدوث أي مشكلة.',
        icon: Icons.description_rounded,
      ),
    ];

    final categories = tips
        .map((e) => e.category)
        .toSet()
        .toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'نصائح الإدارة والمحاسبة',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: false,
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth >= 1100
                ? 3
                : constraints.maxWidth >= 700
                    ? 2
                    : 1;

            return ListView(
              padding: const EdgeInsets.all(22),
              children: [
                // ======================================================
                // Header
                // ======================================================

                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primaryContainer,
                      ],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lightbulb_rounded,
                          color: Colors.white,
                          size: 31,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'دليل الإدارة الذكية',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 23,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'إرشادات عملية تساعدك على إدارة المبيعات والمخزون والديون والأرباح بشكل أفضل.',
                              style: TextStyle(
                                color: Colors.white.withOpacity(.9),
                                height: 1.5,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                // ======================================================
                // Summary
                // ======================================================

                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        icon: Icons.lightbulb_outline_rounded,
                        title: '${tips.length}',
                        subtitle: 'نصيحة عملية',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        icon: Icons.category_outlined,
                        title: '${categories.length}',
                        subtitle: 'مجالات إدارية',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // ======================================================
                // Categories
                // ======================================================

                ...categories.map((category) {
                  final categoryTips =
                      tips.where((e) => e.category == category).toList();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 27,
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              category,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: categoryTips.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            mainAxisExtent: 205,
                          ),
                          itemBuilder: (context, index) {
                            return _TipCard(
                              tip: categoryTips[index],
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ======================================================================
// Model
// ======================================================================

class TipItem {
  final String category;
  final String title;
  final String text;
  final IconData icon;

  const TipItem({
    required this.category,
    required this.title,
    required this.text,
    required this.icon,
  });
}

// ======================================================================
// Tip Card
// ======================================================================

class _TipCard extends StatelessWidget {
  final TipItem tip;

  const _TipCard({
    required this.tip,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: colorScheme.outlineVariant.withOpacity(.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(19),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    tip.icon,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.tips_and_updates_outlined,
                  size: 19,
                  color: colorScheme.outline,
                ),
              ],
            ),

            const SizedBox(height: 14),

            Text(
              tip.title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: Text(
                tip.text,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.55,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// Summary Card
// ======================================================================

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: colorScheme.primary,
            size: 28,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
