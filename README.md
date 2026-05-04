# Valance

Flutter MVP for managing USD/EUR savings with separate public benchmark rates
and factual exchange operations.

## What is implemented

- Today screen with EUR/USD benchmark, day/week changes, 3/5/10-year corridors,
  portfolio shares, target strategy, RUB allocation hint, USD/EUR threshold, and
  in-app alert text.
- Invest screen that simulates how to allocate a new RUB amount into EUR and
  USD.
- USD/EUR exchange screen that shows fair, good, acceptable, and bad receive
  ranges before going to an exchange office.
- History screen with manual factual exchange input in three modes: RUB to
  currency, USD to EUR, and RUB to EUR through BYN.
- Settings screen for active/moderate/conservative strategy and initial
  USD/EUR balances.
- Domain tests for factual rates, benchmark slippage, acceptable thresholds,
  RUB investment recommendation, and weighted RUB purchase cost.

## MVP constraints

- Rates are loaded from ECB Data API for EUR/USD and CBR XML for USD/RUB and
  EUR/RUB. If an API call fails, the app keeps demo fallback rates and shows an
  error note.
- EUR/USD is compared with a second source: CBR cross-rate
  `EUR/RUB / USD/RUB`.
- Operations are held in app memory. Production should add local persistence
  and optional sync.
- BYN is stored only as the exchange route marker, not as a portfolio asset.
# valance
# valance
# valance
# valance
