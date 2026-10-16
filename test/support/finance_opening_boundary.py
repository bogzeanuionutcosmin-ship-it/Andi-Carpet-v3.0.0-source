"""Remove exactly the authorised VIII history projection before older inversions."""
import hashlib


def before_opening_projection(source):
    insertions = [
        '          // Preserve aggregate history in its original settlement-start period.\n'
        '          if(dateOk(st.startDate)) receivedTotal+=st.receivedOpeningDeparture+st.receivedOpeningDuring;\n',
        '          // Undated team history remains restricted to the all-time report.\n'
        '          if(allTime) receivedTotal+=tf.receivedOpeningDeparture+tf.receivedOpeningDuring;\n',
    ]
    for insertion in insertions:
        if source.count(insertion) != 1:
            raise ValueError('Opening projection delta changed; review required')
        source = source.replace(insertion, '', 1)
    new = '((f.receivedEntries.isEmpty&&f.totalReceived!=0)||f.receivedOpeningDeparture!=0||f.receivedOpeningDuring!=0)'
    old = 'f.receivedEntries.isEmpty&&f.totalReceived!=0'
    if source.count(new) != 1:
        raise ValueError('Undated balance warning delta changed; review required')
    source = source.replace(new, old, 1)
    if hashlib.sha256(source.encode()).hexdigest() != '0348242c2def81ac693ded3e3a64c96b9df701fff2b0895f4e6e2b1b09bc92b8':
        raise ValueError('Byte-exact VII runtime was not reconstructed')
    return source
