# Clean-rebuild roadmap — from a 1.2 base (planned 2026-06-04)

**Why:** 2.0 = too many features stacked at once without per-feature verification (183 inputs,
S1.0–S3.2 rails + MMD + regime + scenarios). Data backs the reset: **1.2 beat 2.0** on the #GOLD
35k set (+64.8%/DD 10.8% vs +67.9%/DD 18.5%, cleaner). Rebuild from a minimal, verified base; add
**one** feature per minor version; verify each (discriminator + cross-period cells) before the next.

**HARD GATE:** this whole rebuild is gated on the **forward test** showing the underlying grid has
edge. Do NOT rebuild on sand. If STEP/35k forward-tests as no-edge, the rebuild is moot — fix the
vehicle, not the paint. Sequence: forward-test → (edge?) → rebuild.

**Process per version:** brainstorm → spec → plan → subagent-build → verify → commit. No stacking
unverified features. Each version is independently a working, tested EA.

---

## v3.0 — Clean base (fork from 1.2)
- Fork MoneyDancer **1.2** (the version that works on the 35k set; simpler than 2.0; 1.1 WIPES — never).
- **One canonical parameter naming.** Remove sprint/story tags (`S1.0`, `S2.C`…) from names + comments;
  semantic names only. **FREEZE the scheme + document it.** Extend `translate_set.py` into the official
  set-porter (we just got bitten twice by naming drift: underscore→camelCase silent-default). Every old
  set ports through the translator; no ad-hoc renames after freeze.
- **Re-add only verified-necessary safety rails, deliberately:** all-time DD kill (40%→harden), basket-SL.
  Each justified + tested, NOT inherited from 2.0's full stack.
- Keep the dashboard (user watches it). Drop unused scenarios/telemetry if not needed.
- **Verify:** reproduces 1.2's 35k-set 2026 result bit-for-bit (discriminator) on the clean base.
- OPEN: which 2.0 features to drop entirely? (MMD/regime gate, ScenarioE — the 35k set used none and won.)

## v3.1 — Auto lot-size scaling
- Add equity-scaled base lot (`LotsBasePerThousand`-style): base = equity/1000 × k.
- **Verify:** discriminator (balance change → lot change); % returns invariant across balances.

## v3.2 — ATR-adaptive distance params
- Scale ONLY the distance params by live ATR: `StepPoints / TPPoints / BEPoints / MinMovePoints`
  → `base × f(ATR)`. Toggleable; default OFF = fixed (backward-compatible).
- **VERIFY IT HELPS — do not ship on faith.** A/B ATR-scaled vs fixed across 2025+2026 cells. The
  5-cell probe (2026-06-04) was *discouraging* (noisy, inverted ATR→optimal-param relationship). Keep
  this feature ONLY if it beats fixed out-of-sample. Mechanically sound (grid spacing in ATR units),
  empirically unproven — let the A/B decide.
- OPEN: ATR timeframe/period? formula (ATR÷ref-ATR ratio vs ATR×k)? per-param coefficients?

## v3.3 — Manual orders into basket calc
- Include manual / non-EA positions (magic=0) on the symbol in basket P&L + management (BE/SL/
  martingale reference). Toggleable.
- OPEN: detect by magic=0? fold into management or P&L-only? direction handling vs grid direction?

---

## Notes
- Each version ships a working EA + a verification report (cross-period cells, not one window).
- Naming freeze + translator is the #1 discipline — naming drift caused two silent-default landmines
  this session.
- ATR-adaptive (v3.2) is the user's scaling thesis, scoped to distances, built as a *verified toggle* —
  not assumed to work.
- Versioning per `project_moneydancer_versioning` (MAJOR.MINOR layout under mt5/X.Y/).
