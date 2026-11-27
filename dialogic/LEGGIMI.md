# Dialoghi e missioni: come funzionano

Questa cartella contiene i dialoghi del gioco, scritti per **Dialogic 2**, il plugin
di Godot per dialoghi e scelte.

| Cartella o file | Contenuto |
| --- | --- |
| `dialogic/characters/` | Una scheda `.dch` per ogni personaggio che parla |
| `dialogic/timelines/cap1/` | I dialoghi del capitolo 1, un file `.dtl` per scena |
| `data/quests/capitolo_1.json` | L'elenco delle missioni con obiettivi, finali e ricompense |
| `docs/storia/capitolo_1.md` | La storia raccontata per esteso, con tutte le diramazioni |
| `tools/installa_variabili_storia.gd` | Crea le variabili di Dialogic in un colpo solo |
| `tools/controlla_timeline.py` | Controlla che i dialoghi non contengano errori |

> **Stato**: i testi sono completi e controllati con `tools/controlla_timeline.py`,
> che segue le regole di lettura di Dialogic 2. Non sono ancora stati provati dentro
> Godot, perché il plugin va prima installato nel progetto (passi qui sotto).

## 1. Installare Dialogic (una volta sola)

1. Apri il progetto in Godot e clicca la scheda **AssetLib** in alto.
2. Cerca **Dialogic** e scarica **Dialogic 2**. Conferma l'installazione: compare la
   cartella `addons/dialogic/`.
3. Vai in **Progetto > Impostazioni del progetto > Plugin** e spunta **Dialogic**.
4. Riavvia Godot quando te lo chiede. In alto compare la scheda **Dialogic**.

Il progetto usa Godot 4.5: scegli una versione di Dialogic 2 che lo supporti
(quella più recente va bene).

## 2. Creare le variabili (una volta sola)

I dialoghi usano una quarantina di variabili: reputazione, scelte fatte, stato
delle missioni. Per non crearle a mano:

1. Nel pannello FileSystem apri `tools/installa_variabili_storia.gd`.
2. Nell'editor degli script scegli **File > Esegui** (Ctrl+Maiusc+X).
3. Nel pannello **Output** compare "Ho aggiunto 46 variabili a Dialogic".
4. Riavvia Godot. Le trovi in **Dialogic > Variabili**.

Lo script aggiunge solo quelle che mancano, quindi si può rieseguire senza rischi.

## 3. Provare un dialogo

Nella scheda **Dialogic** apri una timeline (per esempio `c1_01_prologo`) e premi
il pulsante **Play** della timeline nella barra di Dialogic. Si apre una finestra con il
dialogo: clicca per avanzare e scegli le risposte.

Da codice, un dialogo si avvia così:

```gdscript
# Avvia la scena iniziale.
Dialogic.start("c1_01_prologo")

# Avvia una timeline da un punto preciso (una "label").
Dialogic.start("c1_s1_mulino", "nido")
```

## 4. Come leggere un file .dtl

Un file `.dtl` è testo semplice. Si può modificare dalla scheda Dialogic
(modalità testo) o con qualsiasi editor.

```
# Un commento: il gioco lo ignora.
Una riga senza nome è narrazione.
ilva: Una riga con il nome è una battuta di quel personaggio.
ilva: Come ti chiami? Ah già, {Giocatore.Nome}.
- Prima risposta
	ilva: Questo succede solo se scegli la prima.
	set {Rep.Gilda} += 2
- Seconda risposta, visibile solo con una condizione | [if {Rep.Gilda} >= 10]
	ilva: Di te mi fido.
- Terza risposta, grigia se manca il requisito | [if {Cap1.Cantilena} == true] [else="disable" alt_text="(Ti manca qualcosa.)"]
	ilva: Canti bene.
if {Cap1.Posizione} == "caccia":
	ilva: Questo si vede solo se in piazza hai sostenuto la Gilda.
else:
	ilva: Questo in tutti gli altri casi.
[signal arg="oggetto:cristallo_cattura:5"]
[end_timeline]
```

Regole da ricordare quando scrivi:

- I rientri si fanno con il tasto **TAB**, mai con gli spazi.
- La prima risposta (`-`) deve stare **subito sotto una riga di testo**: commenti,
  `set` e `label` vanno messi prima della domanda.
- Non iniziare una riga di narrazione con `set`, `jump`, `label`, `join`, `leave`,
  `update`, `do` o con una parola seguita dai due punti (`Nota: ...`): Dialogic la
  scambierebbe per un comando o per un personaggio.
- Il nome prima dei due punti è il nome del file in `dialogic/characters/`
  (`ilva`, `brisa`, ...). Il nome mostrato a schermo si cambia dentro la scheda.
- Il protagonista è muto e personalizzabile: le sue risposte sono gesti tra
  parentesi, e nessun testo usa il maschile o il femminile riferito a lui.

Dopo ogni modifica puoi controllare tutto con:

```
python3 tools/controlla_timeline.py
```

## 5. Le variabili

Si scrivono tra graffe, con la cartella davanti.

| Cartella | A che cosa serve | Esempi |
| --- | --- | --- |
| `Giocatore` | Dati del protagonista | `Giocatore.Nome`, `Giocatore.Rango` |
| `Rep` | Reputazione con le 3 fazioni, da 0 in su o in giù | `Rep.Gilda`, `Rep.Villaggi`, `Rep.Confraternita` |
| `Legami` | Rapporto con i compagni di viaggio | `Legami.Brisa` |
| `Trama` | I bivi della trama principale | `Trama.Bivio1` = `gilda`, `villaggio` o `vuoto` |
| `Cap1` | Scelte e stato delle missioni del capitolo 1 | `Cap1.Posizione`, `Cap1.PattoVelia`, `Cap1.FauceEsito` |

Soglie di reputazione: **10 o più** benvisto, **−10 o meno** malvisto.

### Variabili che deve impostare il gioco

Queste non le cambia il dialogo: le imposta il codice prima di avviare la scena.

| Variabile | Quando metterla a `true` |
| --- | --- |
| `Cap1.HaMateriali` | In borsa ci sono 3 ciuffi di Saltarupe e 1 legno di deriva |
| `Cap1.HaAntidoto` | In borsa c'è l'antidoto di salvia (il dialogo la accende quando Ilva lo consegna) |
| `Cap1.HaFocaccia` | In borsa c'è una Focaccia di semi |
| `Cap1.FauceRotta` | Nella lotta con Fauceverde la barra di Rottura è stata svuotata almeno una volta |

```gdscript
# Leggere e scrivere una variabile di Dialogic dal codice.
Dialogic.VAR.set_variable("Cap1.FauceRotta", true)
var reputazione_gilda: int = Dialogic.VAR.get_variable("Rep.Gilda")
```

Finché il sistema di battaglia non esiste, per provare il finale "placata" basta
mettere `Cap1.FauceRotta` a `true` nella scheda Dialogic > Variabili.

## 6. I segnali: come il dialogo parla al resto del gioco

Una riga `[signal arg="..."]` non mostra niente: avvisa il gioco che è successo
qualcosa. Il testo è sempre `tipo:dettaglio` oppure `tipo:dettaglio:quantità`.

| Segnale | Significato |
| --- | --- |
| `missione_inizio:<id>` | Aggiungi la missione al diario |
| `missione_obiettivo:<id>:<n>` | Passa all'obiettivo numero n |
| `missione_fine:<id>:<esito>` | Chiudi la missione con quel finale |
| `missione_disponibile:<id>` | La missione si può accettare (segnalino sull'NPC) |
| `oggetto:<id>:<n>` e `oggetto_togli:<id>:<n>` | Aggiungi o togli oggetti dalla borsa |
| `oggetto_chiave:<id>` | Aggiungi un oggetto chiave |
| `monete:<n>` | Aggiungi monete |
| `ricetta:<id>` | Sblocca una ricetta |
| `creatura:<id>` | Aggiungi una creatura alla squadra |
| `rivale_compagno` | Assegna a Brisa il compagno forte contro il tuo |
| `alleato:<id>` | Un personaggio ti segue |
| `battaglia:<id>` e `battaglia_cattura:<id>` | Avvia una lotta (vedi sotto) |
| `boss_modifica:<boss>:<effetto>` | Modifica il boss prima della lotta (`sigillo`, `cantilena`) |
| `sblocca:<zona>` | Apri il passaggio verso una zona |
| `abilita_campo_usata:<punto>` | Il compagno ha usato l'abilità sul campo in quel punto |
| `prezzi:<negozio>:<percentuale>` | Cambia i prezzi di un negozio (−10 = sconto del 10%) |
| `negozio:<id>` | Apri la schermata del negozio |
| `rango_su` | Il protagonista sale di rango |
| `diario:<voce>` | Aggiungi una voce al diario |
| `capitolo_fine:<n>` | Il capitolo è finito |

Per riceverli, uno script collega il segnale di Dialogic a una sua funzione:

```gdscript
func _ready() -> void:
	# Ogni volta che una timeline incontra [signal arg="..."], Dialogic chiama _su_segnale.
	Dialogic.signal_event.connect(_su_segnale)

func _su_segnale(argomento: String) -> void:
	# "oggetto:cristallo_cattura:5" diventa ["oggetto", "cristallo_cattura", "5"].
	var parti: PackedStringArray = argomento.split(":")
	match parti[0]:
		"oggetto":
			print("Aggiungo ", parti[2], " x ", parti[1])
		"missione_inizio":
			print("Nuova missione: ", parti[1])
```

### Lotte in mezzo a un dialogo

In tre punti (`c1_s1_mulino` due volte, `c1_s2_odo` una) il segnale `battaglia:`
arriva a metà scena, e il testo dopo racconta la vittoria. Quando lo riceve, il
gioco deve mettere in pausa il dialogo e riprenderlo a lotta vinta:

```gdscript
Dialogic.paused = true    # quando arriva il segnale "battaglia:..."
Dialogic.paused = false   # quando la lotta è vinta
```

La lotta con Fauceverde invece chiude la scena `c1_09_fauceverde_prima`: a lotta
vinta il gioco avvia `c1_10_fauceverde_dopo`.

## 7. Dove va avviata ogni scena

| Timeline | Quando |
| --- | --- |
| `c1_01_prologo` | Nuova partita, dopo la creazione del personaggio |
| `c1_02_vento_storto` | Arrivo al molo, subito dopo il prologo |
| `c1_03_prateria_velia` | Sul sentiero oltre i mulini della Prateria |
| `c1_04_assemblea` | Parlando con Ilva dopo l'incontro con Velia |
| `c1_05_ferro` | Parlando con Ferro: `inizio` la prima volta, poi `consegna` |
| `c1_06_grotta_ingresso` | Davanti all'ingresso della Grotta, con il paramano |
| `c1_07_grotta_brisa` | Entrando nella sala delle radici |
| `c1_08_grotta_patto` | Arrivando al lago sotterraneo |
| `c1_09_fauceverde_prima` | Entrando nella tana |
| `c1_10_fauceverde_dopo` | A lotta vinta |
| `c1_11_frammento` | Tornando a Portofoglia con il frammento |
| `c1_s1_mulino` | Pina: `inizio`. In cima al mulino: `nido`. Velia sul sentiero: `velia` |
| `c1_s2_odo` | Odo al molo: `inizio`. Nicchia nella Grotta: `grotta` |
| `c1_s3_conti` | Ferro: `inizio`. Scrittoio nel magazzino: `magazzino` |
| `c1_voci_portofoglia` | Parlando con gli abitanti: `tano`, `nilde`, `oride`, `ilva`, `mercante`, `brisa` |

Le timeline delle missioni secondarie controllano da sole a che punto sei: si può
avviare sempre `inizio` e ci pensano loro a mostrare la battuta giusta.
