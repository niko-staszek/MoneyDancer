"""Dry-run: parse signals + apply typo + cancellation. No tick load. Print sample + stats."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from replay_discord_signals import (
    parse_discord_csv, typo_check_and_repair, apply_cancellations, SIGNALS_DIR_DEFAULT,
)

for f in ['signals1.csv', 'tnfx.csv']:
    p = SIGNALS_DIR_DEFAULT / f
    print(f'\n=== {f} ===')
    raw = parse_discord_csv(p)
    print(f'Parsed {len(raw)} signals')
    if raw:
        s = raw[0]
        print(f'  First: msg{s.msg_idx} {s.time_utc} {s.symbol} {s.side} entry={s.entry} sl={s.sl} tps={s.tps}')
        s = raw[-1]
        print(f'  Last:  msg{s.msg_idx} {s.time_utc} {s.symbol} {s.side} entry={s.entry} sl={s.sl} tps={s.tps}')

    sig, stats = typo_check_and_repair(raw)
    print(f'Typo stats: {stats}')
    rep = [s for s in sig if 'repaired' in s.typo_action]
    rej = [s for s in sig if s.typo_action == 'rejected-bad-sl']
    print(f'  Repaired ({len(rep)}):')
    for s in rep[:10]:
        print(f'    msg{s.msg_idx} {s.time_utc} {s.side} entry={s.entry} -> {s.typo_action}')
    print(f'  Rejected ({len(rej)}):')
    for s in rej[:10]:
        print(f'    msg{s.msg_idx} {s.time_utc} {s.side} entry={s.entry} sl={s.sl}')

    cancel_stats = apply_cancellations(sig)
    print(f'Cancellation stats: {cancel_stats}')
    canc = [s for s in sig if s.cancel_status.startswith('canceled-by')]
    print(f'  Canceled ({len(canc)}):')
    for s in canc[:10]:
        print(f'    msg{s.msg_idx} {s.time_utc} {s.side} entry={s.entry}: {s.cancel_status}')

    final = [s for s in sig if not s.skip_reason]
    print(f'Final surviving: {len(final)} signals')
