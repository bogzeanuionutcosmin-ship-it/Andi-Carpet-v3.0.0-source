# Monitor Mapbox – actualizare incrementală

- Buget orientativ: 50.000 solicitări/lună pentru cele două echipe, fără blocare.
- Admin Dashboard: contor pe serviciu (Directions, Optimization, Map Matching), praguri 70/85/95%.
- **Limitare importantă:** contorul este strict local, per sesiune și per dispozitiv. Nu este total lunar sau între dispozitive; nu poate declanșa praguri pe baza consumului real agregat. Pentru aceasta este necesară integrare server-side cu contabilizare centralizată și autorizare.
- Nu au fost schimbate tokenul, GitHub sau APK-ul.
- Compilarea Flutter și testele pe dispozitiv nu au fost executate.
