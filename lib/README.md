# Общие библиотеки ModernTechnologies

Здесь хранятся **общие для всех проектов** библиотеки, чтобы у заказчика был
единый набор компонентов и обозначений.

Структура:

- `symbols/` — общие символы (`*.kicad_sym`) для схем (eeschema).
- `footprints/` — общие посадочные места (`*.pretty/`) для плат (pcbnew).

Как подключить в проекте (KiCad → Preferences → Manage Symbol Libraries →
вкладка Project) или прописать в `sym-lib-table` проекта, указывая путь через
переменную `${KIPRJMOD}`:

```
(lib (name "ModernTech")(type "KiCad")(uri "${KIPRJMOD}/../../lib/symbols/ModernTech.kicad_sym")(options "")(descr "ModernTechnologies shared symbols"))
```

Пока библиотеки не заполнены — используйте стандартные библиотеки KiCad
(`Device`, `power`, `Connector`, и т.д.), как в `projects/example-voltage-divider`.
