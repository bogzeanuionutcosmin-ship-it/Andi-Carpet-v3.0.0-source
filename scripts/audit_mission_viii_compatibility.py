"""Read-only Mission VIII/#52 compatibility; no merge, checkout or guard removal."""
import argparse
import hashlib
import json
from audit_finance_privacy_compatibility import frozen, git, proposed_union, source

BASE = '736ef9ea66bec5ff0c431d05808e43423c1f3ba9'
PRIVACY = '950f736a4e2e32799db5c61ccd8388fe1acae70e'
FINANCE_CHANGED = {'lib/expenses/expense_page.dart',
                   'lib/expenses/expense_settlement_actions.dart', 'pubspec.yaml'}
PRIVACY_CHANGED = {'lib/home/home_page.dart', 'lib/home/home_live_location.dart',
                   'lib/home/home_push_notifications.dart'}


def audit(finance_ref='HEAD', privacy_ref=PRIVACY, base_ref=BASE):
    finance, privacy, base = [git('rev-parse', '--verify', '--end-of-options', r+'^{commit}').decode().strip()
                              for r in (finance_ref, privacy_ref, base_ref)]
    baseline, fp, pp = map(frozen, (base, finance, privacy))
    union, fdelta, pdelta = proposed_union(baseline, fp, pp)
    if set(fdelta) != FINANCE_CHANGED or set(pdelta) != PRIVACY_CHANGED:
        raise ValueError('Unexpected pin delta: review every changed guard')
    for ref, pins in ((finance, fp), (privacy, pp)):
        for path, digest in pins.items():
            if hashlib.sha256(source(ref, path)).hexdigest() != digest:
                raise ValueError('Source does not match its guard: '+path)
    changed = lambda ref: set(git('diff', '--no-ext-diff', '--no-textconv', '--name-only', base, ref).decode().splitlines())
    overlap = sorted(changed(finance) & changed(privacy))
    if overlap != ['ChatGpt', 'test/vision_hardening_freeze_test.py']:
        raise ValueError('Unexpected shared sources require manual integration review')
    note = source(base, 'ChatGpt')
    if any(not source(ref, 'ChatGpt').startswith(note) for ref in (finance, privacy)):
        raise ValueError('Historical checkpoint prefix changed')
    manifest='docs/ROUTING_PDF_PROTECTED_2026-10-13.json'
    catalog=json.loads(source(finance, manifest))['protected_sha256']
    if len(catalog) != 116:
        raise ValueError('Expected116 protected entries')
    if set(catalog) != set(json.loads(source(base,manifest))['protected_sha256']):
        raise ValueError('Protected catalog key set changed')
    for path,digest in catalog.items():
        if hashlib.sha256(source(finance,path)).hexdigest()!=digest:
            raise ValueError('Protected source mismatch: '+path)
    return dict(finance_head=finance, privacy_head=privacy, base=base,
                shared_paths=overlap, finance_pins=fdelta, privacy_pins=pdelta,
                proposed_union=union, verified_freeze_pins_per_branch=len(baseline),
                verified_protected_sources=116, checkpoint_prefixes_preserved=True,
                integration_performed=False,
                remaining_privacy_risk='Four protected Routing/Learning log sites remain KNOWN UNSAFE',
                limitation='Source compatibility only; no merged build, device logs or live SDK certification')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--finance-ref',default='HEAD')
    parser.add_argument('--privacy-ref',default=PRIVACY)
    parser.add_argument('--base-ref',default=BASE)
    args=parser.parse_args()
    print(json.dumps(audit(args.finance_ref,args.privacy_ref,args.base_ref),indent=2))
