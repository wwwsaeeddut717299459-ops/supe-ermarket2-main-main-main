# almajedPRO

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


## تعديلات الذمم
- الموردون: الرصيد المعروض هو «في ذمتي للموردين».
- العملاء: يظهر إجمالي المبالغ المتبقية عند العملاء.
- العملاء: يوجد سقف مديونية، والصفر يعني بدون سقف.
- البيع الآجل يمنع تجاوز السقف المحدد للعميل.
- قاعدة البيانات الجديدة تستخدم ملف `almajedPRO_fresh.db` حتى يبدأ التطبيق بقاعدة جديدة مستقلة عن `almajedPRO.db`.
- بعد تعديل جدول العملاء يجب تشغيل `dart run build_runner build --delete-conflicting-outputs` لتوليد ملفات Drift.


## Release checklist

- جميع القيم المالية المخزنة في قاعدة البيانات بالريال اليمني YER.
- إدخال وعرض المبالغ يمكن أن يكون YER أو SAR، والتحويل يتم عند حدود الإدخال/الحفظ فقط.
- سعر الصرف الافتراضي: 1 SAR = 410 YER، ويمكن تغييره من الإعدادات.
- تم إضافة اختبارات للتحويل بين YER وSAR.
- قبل الإنتاج يجب اختبار: بيع نقدي، بيع آجل، سداد، شراء نقدي/آجل، مرتجع، ومصروف مع العملتين.
- يوصى بعمل نسخة احتياطية قبل تغيير سعر الصرف.


## almajedPRO 2.0.0

- Purchase returns now load the complete purchase invoice and allow per-item increase, decrease, or removal from the return.
- Sales returns use direct barcode scanning without invoice search.
- Sales and purchase invoices use one atomic global sequence starting at `1` for a fresh database and never reuse committed numbers.
- Database indexes were expanded across the application tables for common lookup/join fields.
- SQLite durability was hardened with WAL, `synchronous=FULL`, foreign-key enforcement, and busy timeout.
- Application branding/version updated to `almajedPRO` / `2.0.0`.
