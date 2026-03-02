# Valance

Flutter utility for a personal BYN/USD/EUR wallet measured in RUB.

## What is implemented

- Wallet summary with total current value, invested RUB, and difference.
- BYN, USD, and EUR rows with the current RUB rate, amount invested, current
  value, and difference.
- Compact empty currency rows when there are no holdings.
- Transaction history in the short form `25.05.26 · 200 USD -> 10 BYN`.
- Direction-independent factual operation rate, for example RUB per 1 USD,
  BYN per 1 EUR, or USD per 1 EUR.
- CSV export through the system share sheet and paste import.
- Euro-to-dollar screen with human-readable 1 year, 5 years, and 10 years
  ranges, plus the current rate marker.
- Euro and dollar wallet composition as two visual segments. BYN is not included
  in that composition.

## Rate sources

- USD/RUB, EUR/RUB, and BYN/RUB are loaded from the official CBR XML feed.
- EUR/USD current and historical observations are loaded from the ECB Data API.
- If current or historical rates are missing or stale, dependent values are
  marked unavailable instead of being calculated from fallback data.

## Accounting rules

- RUB is a settlement currency for operations, not a wallet holding.
- BYN, USD, and EUR are wallet holdings.
- Cost basis uses weighted average accounting.
- RUB -> currency adds RUB cost basis to the received currency.
- Currency -> RUB releases cost basis from the sold currency; received RUB is
  not tracked as a holding.
- Currency -> currency transfers the released RUB cost basis to the received
  currency.
