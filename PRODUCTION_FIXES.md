# Almajed PRO – Production fixes

## 1. SQLite UNIQUE constraint on `journal_entries.entry_number`

The accounting service no longer creates journal numbers from `DateTime.now().microsecondsSinceEpoch`.
Each posting now receives a deterministic number based on its source type and source id:

`JE-<sourceType>-<sourceId>`

This removes the timing-based collision that caused:

`SqliteException(2067): UNIQUE constraint failed: journal_entries.entry_number`

The same fix is applied to both accounting service copies present in the project.

## 2. Empty first-run database

The production database file is now `almajed_pro.db` instead of the previous `almajed_pro_v12.db`.
This intentionally starts a fresh database for this production build instead of reopening the previous seeded database.

The startup initializer no longer seeds a supermarket catalog. New installations therefore contain no products or categories.
Only the system administrator account is created:

- Username: `000`
- Password: `000`

## 3. Purchases do not create products automatically

A purchase line must reference an existing product by product id or barcode.
If the product does not exist, the purchase is rejected with a clear Arabic message asking the user to add the product first.

## 4. Performance

The active database schema is version 13 and includes additional indexes for common product searches, sales/purchases/returns date filtering, stock movement history, customer/supplier transactions, and accounting source lookups.
SQLite is configured with WAL mode, full synchronous writes, a busy timeout, cache tuning, and `PRAGMA optimize`.

## 5. Backup/restore

The backup services now target the same `almajed_pro.db` file used by the application, preventing backup/restore from silently targeting a different database filename. Legacy `almajed_pro_v12.db` entries are excluded from new backups, while old backups are transparently mapped to the new database filename during restore.
