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

## Struttura delle cartelle

| Cartella | Contenuto |
| --- | --- |
| `scenes/player/` | Il protagonista: movimento e camera |
| `scenes/monsters/` | I mostri che vagano nel mondo |
| `scenes/world/` | Le mappe (per ora la mappa di prova) |
| `scripts/data/` | Gli "stampi" dei dati: `CreatureData`, `SkillData`, `EvolutionRule`, `Element` |
| `data/creatures/` | Una scheda `.tres` per ogni creatura |
| `data/skills/` | Una scheda `.tres` per ogni abilità |

### Modificare una creatura senza codice

Apri `data/creatures/brasolo.tres` nel pannello FileSystem dell'editor: tutte le
statistiche appaiono nell'Inspector a destra. Per crearne una nuova:
tasto destro su `data/creatures/` > **Nuovo > Risorsa** > `CreatureData`.

## Regole del progetto

- Tutti i contenuti sono originali o con licenza CC0: niente nomi, creature o asset di altri giochi.
- Il codice è commentato in italiano.
