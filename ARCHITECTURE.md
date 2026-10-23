# Almajed PRO — Architecture

The project is organized by **feature**, with a strict separation between presentation, data access, and shared infrastructure.

## Principles

- Every navigation page represents one business section.
- Pages are presentation-only: UI, user interaction and navigation for that section.
- Database access lives under `core/database` and is never placed directly in a page.
- Feature services/repositories live inside their own feature.
- Shared cross-feature services live under `core/services`.
- Providers are colocated with the feature they belong to, or in `core/providers` when shared.
- Generated Drift files remain next to their source database files.

## Structure

```text
lib/
├── app/
│   └── presentation/   # application shell/navigation
├── core/
│   ├── bootstrap/
│   ├── database/
│   │   ├── daos/
│   │   └── tables/
│   ├── providers/
│   └── services/
├── features/
│   ├── accounting/
│   ├── audit/
│   ├── auth/
│   ├── backup/
│   ├── categories/
│   ├── customers/
│   ├── dashboard/
│   ├── employees/
│   ├── expenses/
│   ├── forecast/
│   ├── inventory/
│   ├── invoices/
│   ├── operations/
│   ├── products/
│   ├── purchases/
│   ├── reports/
│   ├── returns/
│   ├── sales/
│   ├── settings/
│   ├── shifts/
│   ├── suppliers/
│   ├── tips/
│   └── validation/
└── main.dart
```

Each feature uses this pattern where applicable:

```text
feature/
├── data/
│   ├── repositories/
│   └── services/
└── presentation/
    ├── pages
    └── widgets (when needed)
```

## Navigation responsibility

The shell exposes independent sections such as POS, Products, Categories, Inventory, Automatic Inventory, Sales, Purchases, Customers, Suppliers, Employees, Expenses, Accounting, Backup/Restore, Reports, Returns, Settings, and Profit Forecast.

The old combined **Products + Categories** catalog screen is no longer used. Products and Categories are separate navigation sections.

No business behavior or database schema is intentionally changed by this reorganization.
