# MoneyDancer

**Bare MT4→MT5 port reference. Frozen — not actively developed.**

Active development, including MMD regime detection, telemetry logging,
prop-compliance SL, and the Phase B/C/D/E roadmap, lives in the sibling
repo **[CashCabaret](../CashCabaret)**.

## What's in this repo

```
mt4/
  MoneyDancer_legacy.mq4   Original MT4 EA (cleaned: AXI broker lock + license
                           gating removed, Polish → English, rebranded "JoJo").
                           The MT4 baseline for diff-based validation.

mt5/
  MoneyDancer/             Bare 1:1 MT4→MT5 port. Phase A5 end-state.
    MoneyDancer.mq5        Main EA
    Include/               Module files (Inputs, Globals, Utils, Persistence,
                           Orders, Slope, Pyramid, Series, Basket, ScenarioD,
                           Risk, ScenarioE, Dashboard stub, Telemetry stub,
                           Signal). MMD and full Telemetry do NOT exist in
                           this repo — those are CashCabaret-only additions.

scripts/                   Build helpers (deploy.sh, compile.sh, dev.sh, lib.sh)
                           targeting MQL5/Experts/MoneyDancer/ in the MT5
                           terminal data folder.
```

## Why it exists

When the active development layer (CashCabaret) grows more complex with
MMD/telemetry/ML/etc., a clean diff against the bare port is the
ground-truth check that "the MT4 strategy itself" behaves identically
between legacy MT4 and MT5. Any trade-sequence divergence between this
bare port and MoneyDancer_legacy.mq4 is a bug in our porting; any
divergence between CashCabaret and this bare port is from the additions
layered on top.

Phase A8 validation (per CashCabaret's docs/PLAN.md) will use this repo
as the reference baseline.

## Usage

```bash
./scripts/dev.sh    # mirror mt5/MoneyDancer/ into MT5 Experts + compile
```

Deploys to `<MT5 data folder>/MQL5/Experts/MoneyDancer/` so it sits
alongside CashCabaret's EA — both can run simultaneously with different
Magic numbers.
