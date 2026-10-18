# Annual history integration witness

New explicit opening balances are preserved by models/Home codecs, but the
existing general calculation dialog only sums entries when a record is itemised.
It therefore drops the opening history once a protocol receipt is appended.

Four real ExpensePage dialog cases compare legacy vs protocol, and settlement vs
team-finance. Expected legacy annual/all-time values remain unchanged. Settlement
opening balances retain the original settlement-start-year attribution; undated
team-finance openings remain all-time only. New transfer dates remain independent.
No money is invented, rounded or assigned a new date. Controls require zero writes
and zero audit messages. This commit adds the RED witness before changing code.


### VIII-10 follow-up — real annual report regression repaired
29b855b / MissionVIII38742920846 job116448984266 reproduced exactly2RED (protocol openings in settlement annual and team all-time) with89PASS, including both legacy controls. Same4dialog tests retained. The correction adds opening balances in original settlement-start period and undated team openings only inallTime, preserving existing financial attribution. The existing undated-warning condition also includes new opening fields.
Explicit freeze pin for expense_settlement_actions:0348242c2def81ac693ded3e3a64c96b9df701fff2b0895f4e6e2b1b09bc92b8 ->2cf1a4471d6c5fc41458201d3794a919ee318be74b8bf56208e484d121a00db9. All20otherfreezeentries and116protectedmanifestentries preserved. Historical stale-close/Vision inversion assertions keep their original expected hashes: a new exact-delta helper removes only2opening additions+warning delta and verifies the full0348242 previous runtime before the old inversions run.187PythonPASS; no guard is disabled or accepted via new arbitrary expectedhashes. Final targetedDart count91/overallFlutter695 are verification targets, pendingCI.
