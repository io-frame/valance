# Valance

Valance is a Flutter app for tracking a personal BYN/USD/EUR currency portfolio
valued in RUB.

The app is built around a simple ledger: every operation moves value from one
currency to another, RUB is treated as the settlement currency, and the current
portfolio result is calculated against net RUB spent.

## Features

- Portfolio summary with current RUB value, total RUB spent, and profit/loss.
- Portfolio structure for BYN, USD, and EUR with allocation percentages,
  current RUB values, and fresh CBR rates.
- Operation history with add, edit, delete, and ledger validation.
- Suspicious operation warnings when an operation rate materially differs from
  current market rates.
- CSV export through the system share sheet.
- CSV import with preview, append, and replace flows.
- EUR/USD screen with current ECB rate and 1, 5, and 10 year historical ranges.
- Offline persistence for operations and the last fetched rates.

## Screens

### Portfolio

The portfolio screen shows:

- total current value of BYN, USD, and EUR in RUB;
- total net RUB spent across all operations;
- profit/loss as `current RUB value - net RUB spent`;
- portfolio allocation across BYN, USD, and EUR;
- current RUB rates for each holding currency;
- stale or unavailable rate warnings.

### Operations

The operations screen is the source of truth for the wallet ledger. It supports
operations between RUB, BYN, USD, and EUR. The ledger is validated after every
change, so selling or transferring more currency than the current history allows
is rejected.

CSV backup is available from the same screen. Imported rows are validated before
they are saved.

### EUR/USD

The EUR/USD screen shows the latest ECB EUR/USD rate and compares it with
historical daily observations over 1, 5, or 10 years. The chart marks p10, p25,
p50, p75, and p90 levels and highlights the current rate when it is outside the
usual range.

Historical ranges are descriptive statistics, not a forecast.

## Rate Sources

- USD/RUB, EUR/RUB, and BYN/RUB are loaded from the official CBR XML feed.
- EUR/USD current and historical observations are loaded from the ECB Data API.
- Rates are cached locally after a successful refresh.
- If rates are missing or stale, dependent values are marked unavailable instead
  of being calculated from fallback data.

## Accounting Rules

- RUB is a settlement currency, not a wallet holding.
- BYN, USD, and EUR are wallet holdings.
- Holdings are calculated from the full sorted operation history.
- `RUB -> currency` increases the target currency holding and increases net RUB
  spent.
- `currency -> RUB` decreases the source currency holding and decreases net RUB
  spent.
- `currency -> currency` decreases one holding and increases another holding
  without changing net RUB spent.
- Profit/loss is calculated at the portfolio level as:

```text
current RUB value of BYN/USD/EUR - net RUB spent
```

The app does not maintain per-position cost basis.

## CSV Format

CSV export uses the following columns:

```csv
id,date,from_currency,from_amount,to_currency,to_amount,comment
```

The importer also accepts a compact money format when the CSV contains `from`
and `to` columns instead of the expanded currency and amount columns.

Dates may be ISO timestamps or `YYYY-MM-DD` dates. Amounts must be positive
finite numbers. Currency codes are `RUB`, `BYN`, `USD`, and `EUR`.

## Data Storage

Valance stores data locally with `shared_preferences`:

- operations are stored under `wallet.operations.v1`;
- cached rates are stored under `wallet.rates.v1`;
- corrupted local payloads are preserved with a `.corrupted` suffix before an
  error is reported.

No account, backend, or remote sync is used.

## Project Structure

```text
lib/
  core/
    formatters.dart
  features/fx/
    application/
      valance_store.dart
    data/
      benchmark_rates_api.dart
      local_store.dart
    domain/
      fx_engine.dart
      fx_models.dart
    presentation/
      home_shell.dart
      screens/
        wallet_screen.dart
        history_screen.dart
        eur_usd_screen.dart
      widgets/
        app_chrome.dart
```

## Supported Platforms

The repository contains Flutter platform projects for Android, iOS, macOS, and
web.

## Dependencies

Runtime dependencies include:

- `http` for CBR and ECB requests;
- `xml` for CBR XML parsing;
- `intl` and `flutter_localizations` for formatting and localization;
- `shared_preferences` for local persistence;
- `share_plus` for CSV export.

## Production Notes

- The app depends on public CBR and ECB endpoints; rate refresh can fail when
  those services are unavailable or the device is offline.
- Cached rates allow the UI to continue showing the last known data, with
  freshness labels and warnings.
- Portfolio result is only as accurate as the operation history entered by the
  user.
- EUR/USD historical ranges are informational and must not be treated as
  investment advice.
