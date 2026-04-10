# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

ERPNext v17 — an open-source ERP built on the **Frappe Framework**. Python backend, JavaScript/Vue.js frontend, MariaDB database. All CLI operations go through `bench` (Frappe's CLI tool).

## Common Commands

```bash
# Development server
bench start

# Run all tests (parallelized across 4 containers in CI)
bench --site [site_name] run-parallel-tests --lightmode --app erpnext

# Run tests for a specific doctype
bench --site [site_name] run-tests --doctype "Sales Invoice"

# Run a specific test file
bench --site [site_name] run-tests --module erpnext.accounts.doctype.sales_invoice.test_sales_invoice

# Apply database migrations/patches
bench --site [site_name] migrate

# Build frontend assets
bench build --app erpnext

# Fresh site reinstall
bench --site [site_name] reinstall --yes
```

## Linting & Formatting

Python uses **ruff** (tabs, line-length 110). JS/Vue uses **ESLint** + **Prettier**. SCSS uses **Stylelint**. All enforced via pre-commit hooks.

```bash
# Run all pre-commit checks
pre-commit run --all-files

# Python only
ruff check erpnext/
ruff format erpnext/

# JS only
npx eslint [file]
npx prettier --write [file]
```

Key ruff settings: tab indentation, double quotes, 110 char line length. See `pyproject.toml` for full config.

## Architecture

### Module Structure

21 modules defined in `erpnext/modules.txt`: Accounts, Stock, Selling, Buying, Manufacturing, CRM, Projects, Assets, Setup, Support, Subcontracting, Quality Management, Regional, EDI, and others.

Each module follows the pattern:
```
erpnext/<module_name>/
    doctype/<doctype_name>/
        <doctype_name>.py          # Server-side DocType controller
        <doctype_name>.json        # DocType schema definition
        <doctype_name>.js          # Client-side form controller
        test_<doctype_name>.py     # Tests
```

### Controller Inheritance Chain

Transaction documents inherit through a controller hierarchy in `erpnext/controllers/`:

1. **`taxes_and_totals.py`** — Tax calculation and totals
2. **`accounts_controller.py`** — GL entries, payment handling, multi-currency (extends taxes_and_totals)
3. **`buying_controller.py`** / **`selling_controller.py`** — Purchase/sales-specific logic (extend accounts_controller)
4. **`stock_controller.py`** — Stock ledger entries, inventory valuation
5. **`subcontracting_controller.py`** — Subcontracting flows
6. **`status_updater.py`** — Cross-document status updates (e.g., order fulfillment %)

Most transaction doctypes (Sales Invoice, Purchase Order, etc.) inherit from one of these controllers rather than directly from `frappe.model.document.Document`.

### Hooks System

`erpnext/hooks.py` is the central app configuration — registers bundles, DocType overrides, scheduled tasks, document event handlers, and jinja methods. This is where ERPNext extends Frappe's core behavior.

### Patches / Migrations

Database migrations live in `erpnext/patches/` organized by version. The execution order is defined in `erpnext/patches.txt` with `[pre_model_sync]` and `[post_model_sync]` sections. Patches run during `bench migrate`.

### Frontend Bundles

- `erpnext.bundle.js` / `erpnext.bundle.css` — Main app assets
- `erpnext-web.bundle.css` — Portal/website styles
- Client scripts in `erpnext/public/js/` extend Frappe's desk UI

## Frappe Framework Patterns

- **DocType** = data model + controller. Schema in JSON, logic in Python, form UI in JS.
- **`frappe.get_doc()`** / **`frappe.new_doc()`** — Create/fetch documents.
- **`@frappe.whitelist()`** — Expose Python methods as API endpoints.
- **`frappe.db.get_value()`** / **`frappe.db.sql()`** — Database access (prefer query builder over raw SQL).
- **`frappe.get_cached_value()`** — Cached single-value reads.
- Tests use `frappe.tests.utils.FrappeTestCase` as base class with site database access (not mocked).

## CI

GitHub Actions (`.github/workflows/server-tests-mariadb.yml`): Python 3.14, Node 24, MariaDB 10.6, 4 parallel test containers. JS/CSS changes are excluded from server test triggers.
