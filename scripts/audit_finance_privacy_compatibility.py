"""Read-only Git audit. Never creates a merge tree, checkout, commit or branch."""
import argparse
import ast
import hashlib
import json
import subprocess

BASE = '736ef9ea66bec5ff0c431d05808e43423c1f3ba9'
PRIVACY = '926ed1e7474e22a73257291a0089b5efbd5fe925'
FREEZE = 'test/vision_hardening_freeze_test.py'


def proposed_union(base, finance, privacy):
    if base.keys() != finance.keys() or base.keys() != privacy.keys():
        raise ValueError('Freeze key set changed; review every added/deleted guard')
    financial = {key: value for key, value in finance.items() if value != base[key]}
    redacted = {key: value for key, value in privacy.items() if value != base[key]}
    if financial.keys() & redacted.keys():
        raise ValueError('Overlapping source pins require explicit review')
    return {**base, **financial, **redacted}, financial, redacted


def git(*args):
    return subprocess.check_output(['git', *args])


def source(ref, path):
    return git('show', f'{ref}:{path}')


def frozen(ref):
    for node in ast.parse(source(ref, FREEZE)).body:
        if isinstance(node, ast.Assign) and any(getattr(t, 'id', None) == 'FROZEN' for t in node.targets):
            return ast.literal_eval(node.value)
    raise ValueError('FROZEN assignment missing')


def audit(finance_ref, privacy_ref, base_ref):
    finance_ref, privacy_ref, base_ref = [
        git('rev-parse', '--verify', '--end-of-options', ref + '^{commit}').decode().strip()
        for ref in [finance_ref, privacy_ref, base_ref]]
    base, finance, privacy = map(frozen, [base_ref, finance_ref, privacy_ref])
    union, financial, redacted = proposed_union(base, finance, privacy)
    if set(financial) != {'lib/expenses/expense_page.dart', 'lib/expenses/expense_settlement_actions.dart'}:
        raise ValueError('Expected both Mission VII source pins')
    if set(redacted) != {'lib/home/home_page.dart', 'lib/home/home_live_location.dart', 'lib/home/home_push_notifications.dart'}:
        raise ValueError('Expected all three privacy source pins')
    for ref, catalog in [(finance_ref, finance), (privacy_ref, privacy)]:
        for path, expected in catalog.items():
            if hashlib.sha256(source(ref, path)).hexdigest() != expected:
                raise ValueError(f'Pin mismatch: {ref}:{path}')
    def changed(ref):
        return set(git('diff', '--no-ext-diff', '--no-textconv', '--name-only', base_ref, ref).decode().splitlines())
    shared = sorted(changed(finance_ref) & changed(privacy_ref))
    if shared != ['ChatGpt', FREEZE]:
        raise ValueError(f'Unexpected shared changes: {shared}')
    note = source(base_ref, 'ChatGpt')
    for ref in [finance_ref, privacy_ref]:
        if not source(ref, 'ChatGpt').startswith(note):
            raise ValueError('Historical checkpoint edited; manual review required')
    return {
        'finance_head': git('rev-parse', finance_ref).decode().strip(),
        'privacy_head': git('rev-parse', privacy_ref).decode().strip(),
        'shared_paths': shared,
        'finance_pins': financial, 'privacy_pins': redacted,
        'proposed_union': union,
        'verified_pins_per_branch': len(base),
        'both_checkpoint_appendices_preserved': True,
        'integration_performed': False,
    }


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--finance-ref', default='HEAD')
    parser.add_argument('--privacy-ref', default=PRIVACY)
    parser.add_argument('--base-ref', default=BASE)
    args = parser.parse_args()
    print(json.dumps(audit(args.finance_ref, args.privacy_ref, args.base_ref), indent=2))
