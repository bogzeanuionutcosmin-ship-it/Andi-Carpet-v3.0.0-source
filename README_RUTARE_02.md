# Rutare 02 — kilometri rutieri și consum

- Folosește OSRM driving pentru întregul traseu: plecare, săli, destinație finală.
- Afișează kilometrii rutieri, litrii estimați și costul estimat în Grafic.
- Exportul PDF folosește kilometrii rutieri când rutarea este disponibilă.
- Dacă serviciul nu răspunde, etichetează clar calculul GPS în linie dreaptă; nu îl prezintă drept distanță rutieră.
- Nu efectuează apeluri rutier dacă lipsesc coordonate; previne cereri excesive cu peste 75 puncte.
- Serviciul public OSRM nu are SLA și necesită înlocuire cu un serviciu propriu sau contractat pentru utilizare intensă.

Verificări: codul a fost inspectat și ZIP-ul verificat; compilarea Flutter nu este disponibilă în acest mediu.
