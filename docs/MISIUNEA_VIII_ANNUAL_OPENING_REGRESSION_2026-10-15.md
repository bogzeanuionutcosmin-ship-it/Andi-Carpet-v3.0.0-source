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
