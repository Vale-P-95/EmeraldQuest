# EmeraldQuest

RPG 3D a turni con creature originali, fatto con [Godot 4](https://godotengine.org).
Il design completo è nel GDD del progetto.

## Come provarlo (anche se non hai mai usato Godot)

1. Installa [GitHub Desktop](https://desktop.github.com), accedi con il tuo account e
   fai **File > Clone repository > Vale-P-95/emeraldquest**.
2. Apri Godot (versione 4.5 o più recente). Nel Project Manager premi **Importa**,
   scegli il file `project.godot` nella cartella appena scaricata e poi **Importa e modifica**.
3. Premi **F5** (o il triangolo ▶ in alto a destra) per avviare il gioco.

Quando ci sono novità: in GitHub Desktop premi **Fetch origin** e poi **Pull**.

### Comandi

| Azione | Tastiera e mouse | Controller |
| --- | --- | --- |
| Muoversi | W A S D | Stick sinistro |
| Correre | Shift | B / Cerchio |
| Camera | Mouse (clicca per agganciarlo) oppure frecce | Stick destro |
| Liberare il mouse | Esc | — |
| Provare la storia (scena successiva) | T | — |
| Avanzare nei dialoghi | Invio, Spazio, X o clic | A / Croce |

## Struttura delle cartelle

| Cartella | Contenuto |
| --- | --- |
| `scenes/player/` | Il protagonista: movimento e camera |
| `scenes/monsters/` | I mostri che vagano nel mondo |
| `scenes/world/` | Le mappe (per ora la mappa di prova) |
| `scripts/data/` | Gli "stampi" dei dati: `CreatureData`, `SkillData`, `EvolutionRule`, `Element` |
| `data/creatures/` | Una scheda `.tres` per ogni creatura |
| `data/skills/` | Una scheda `.tres` per ogni abilità |
| `dialogic/` | Dialoghi e personaggi della storia (guida in `dialogic/LEGGIMI.md`) |
| `autoload/` | Script sempre attivi: `storia.gd` collega i dialoghi al gioco |
| `data/quests/` | L'elenco delle missioni |
| `docs/storia/` | La storia raccontata per esteso |
| `addons/dialogic/` | Il plugin Dialogic 2 per i dialoghi |
| `scripts/battle/` | La logica della battaglia: regole, turni CTB, IA (nessuna grafica) |
| `scenes/battle/` | `BattleManager` (ferma il mondo e gestisce la lotta) e l'interfaccia |
| `tests/` | Test automatici (`test_battle.gd`) |

### Modificare una creatura senza codice

Apri `data/creatures/brasolo.tres` nel pannello FileSystem dell'editor: tutte le
statistiche appaiono nell'Inspector a destra. Per crearne una nuova:
tasto destro su `data/creatures/` > **Nuovo > Risorsa** > `CreatureData`.

## Regole del progetto

- Tutti i contenuti sono originali o con licenza CC0: niente nomi, creature o asset di altri giochi.
- Il codice è commentato in italiano.

## Creature, abilità e tipi (M2)

- `data/creatures/` — 12 creature originali (4 linee evolutive, con evoluzioni a rami).
- `data/skills/` — 30 abilità.
- `data/types/type_chart.tres` — tabella dei 9 elementi (forte/debole/immune).
- `tools/generate_data.py` — genera tutti questi `.tres` da una tabella leggibile; in alternativa modifica i `.tres` dall'Inspector.

## Battaglie (M2)

Avvicinati a un mostro nella mappa di prova (Fauceverde, il mostro grande, o la
piccola Scintilla): la lotta parte sul posto e il mondo si ferma finché scegli.

- **Turni CTB**: in alto vedi la coda dei prossimi 8 turni. La Velocità decide
  quanto spesso agisci; Difendi ti fa tornare prima, le abilità da 4-5 PA ti rallentano.
- **PA**: +1 a ogni tuo turno (massimo 5). Le abilità li spendono, Difendi ne dà +2.
- **Cambio**: costa il turno. Ma se la creatura in campo ha appena usato un'abilità
  d'attacco di un elemento che anche l'altra creatura possiede, e ha 3 PA, il cambio
  diventa una **★ Staffetta**: chi entra attacca subito con un colpo potenziato.
  Esempio con la squadra di prova: Fiammolo usa Spallata (Terra) e passa a Coralunghi (Acqua/Terra).
- **Rottura**: i mostri grandi hanno una barra gialla. Colpiscili sulla debolezza per
  svuotarla: il mostro perde un turno.
- **Difficoltà**: premi **F2** nella mappa (Facile, Normale, Difficile). Cambia i danni
  del nemico e quanto è furba la sua IA.
- Comandi nei menu: mouse, oppure frecce + Invio (o il controller); Esc per tornare indietro.

La squadra di prova si cambia senza codice: apri `scenes/battle/battle_manager.tscn`,
seleziona `BattleManager` e modifica **Starting Party** e **Starting Level** nell'Inspector.
I numeri del bilanciamento (danni, PA, velocità dei turni) sono tutti in
`scripts/battle/battle_rules.gd`.

I dialoghi della storia possono chiedere una lotta con `[signal arg="battaglia:id"]`:
l'elenco delle lotte è `STORY_BATTLES` in `scenes/battle/battle_manager.gd`.

### Lanciare i test

```
godot --headless --path . -s res://tests/test_battle.gd
```
