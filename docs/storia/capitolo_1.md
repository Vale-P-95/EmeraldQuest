# Capitolo 1 – Il vento che non torna

Questo documento racconta la storia del capitolo 1 e spiega come le scelte del
giocatore la cambiano. I dialoghi veri e propri sono in `dialogic/timelines/cap1/`,
l'elenco delle missioni è in `data/quests/capitolo_1.json`.

Tutti i nomi di persone, luoghi e creature sono originali. I nomi delle creature
(Brasolo, Gocciarpa, Germoglio, Saltarupe, Ciottolotto, Fauceverde) vengono dal GDD
e sono provvisori: se cambiano, vanno aggiornati nelle timeline.

## In breve

Tre mesi fa, nella **Notte Verde**, lo Smeraldo dei Venti si è spezzato e i suoi
frammenti sono caduti su tutta Verdalia. A Portofoglia nessuno lo sa ancora: si sa
solo che il maestrale soffia storto e che le creature più miti mostrano i denti.

Il giorno in cui la Gilda dei Cacciatori ti affida il primo compagno, il vento si
ferma del tutto. Barche e mulini restano fermi. Seguendo una polvere verde che fa
impazzire le creature (la **Smania**) arrivi alla Grotta Muschiata, dove
**Fauceverde**, la vecchia guardiana delle sorgenti, ha un frammento conficcato
nella mascella. La Gilda vuole abbatterla, il villaggio vuole placarla, e una donna
in grigio ti offre una terza strada. Alla fine hai in mano il primo frammento e
devi decidere a chi darlo: è il **primo dei tre bivi** della trama principale.

**Temi**: che cosa vuol dire proteggere (un contratto, una comunità o il silenzio),
e quanto costa ogni risposta. Il tono è avventuroso e colorato, con tre momenti
seri: il padre di Brisa, la scelta dell'antidoto e Fauceverde che cerca da tre mesi
di togliersi la scheggia da sola.

## Personaggi

| Personaggio | Chi è | Che cosa vuole | Fazione |
| --- | --- | --- | --- |
| **Ilva** | Capogilda di Portofoglia, ex cacciatrice. Severa, giusta, ironica. | Rispettare il contratto e tenere vive le sue reclute. | Gilda |
| **Brisa** | Apprendista, amica e rivale. Impulsiva. Il padre è scomparso in mare nella Notte Verde. | Una risposta su quella notte, e la stima di Ilva. | Gilda |
| **Oride** | Sindaca di Portofoglia. Calma, testarda. | Che il villaggio decida da sé che cosa proteggere. | Villaggi |
| **Nilde** | Anziana del villaggio. Da bambina Fauceverde la riportò a casa. | Che la Vecchia Verde non venga uccisa. | Villaggi |
| **Ferro** | Mastro Ferrante Battimaglio, fabbro. Pratico e brontolone. | Materiali buoni e conti che tornano. | Villaggi |
| **Velia** | Si presenta come "cartografa dei venti". È una Sorella della Confraternita del Vuoto. Gentile, paziente, inquietante. | I frammenti. Offre la **Quiete**: creature senza più Smania, ma anche senza volontà. | Confraternita |
| **Pina** | Mugnaia della Prateria. | Far ripartire il mulino. | Villaggi |
| **Odo** | Bambino del porto, nove anni. | Ritrovare Sasso, il suo Ciottolotto. | Villaggi |
| **Malco** | Intendente della Gilda. Tiene due registri. | Aiutare tre famiglie rovinate dalla Notte Verde. | Gilda |
| **Tano** | Vecchio pescatore. | Vento e pesce. | Villaggi |

Il protagonista è muto: le sue "battute" sono gesti e intenzioni, scritti tra
parentesi nelle risposte. Parla una volta sola, quando canta la Cantilena della
Fonte. I testi non usano mai il maschile o il femminile per il protagonista, così
funzionano con qualunque aspetto scelto dal giocatore. Gli altri lo chiamano con
la variabile `{Giocatore.Nome}`.

## Luoghi

- **Portofoglia**: villaggio costiero di case bianche. Molo, piazza, sede della Gilda
  (una vecchia rimessa delle barche), fucina di Ferro, molo vecchio (di notte).
- **Prateria dei Venti**: altopiano d'erba alta con i mulini. Branchi di Saltarupe,
  il mulino di Pina, il sentiero del nord.
- **Grotta Muschiata**: dungeon del capitolo. Muschio azzurro luminoso che il
  frammento sta trasformando in muschio nero. Sala delle radici, nicchia laterale,
  lago sotterraneo, tana di Fauceverde.

## Trama principale, scena per scena

| # | Timeline | Che cosa succede | Scelte che contano |
| --- | --- | --- | --- |
| 1 | `c1_01_prologo` | Il giorno del cristallo: Ilva ti affida il primo compagno. La campana del molo suona fuori orario. | Che cos'è un cacciatore (primi punti reputazione). Compagno iniziale. |
| 2 | `c1_02_vento_storto` | Le barche rientrano a remi. Ilva ti manda sulla Prateria, Oride ti chiede di non fare male ai branchi. | A chi dai retta (promessa a Oride). |
| 3 | `c1_03_prateria_velia` | Incontri Velia accanto a un Saltarupe con la Smania. Scopri la polvere di smeraldo. | Aiutarla, osservarla o mandarla via. Prendere un campione. Prometterle il silenzio. |
| 4 | `c1_04_assemblea` | Rapporto a Ilva, poi assemblea in piazza: abbattere o placare Fauceverde? | Che cosa racconti a Ilva. **Posizione in piazza** (4 risposte, una richiede il campione di polvere). |
| 5 | `c1_05_ferro` | Ferro ti fabbrica il paramano (introduzione al crafting). | — |
| 6 | `c1_06_grotta_ingresso` | Apri l'ingresso con l'abilità del compagno: brucia, nuota o taglia. Brisa racconta di suo padre. | Come rispondi a Brisa (legame). |
| 7 | `c1_07_grotta_brisa` | Brisa è corsa avanti ed è avvelenata dalle spore. Hai un solo antidoto. | Darglielo tutto, a metà, rimandarla a casa o lasciarla lì. |
| 8 | `c1_08_grotta_patto` | Velia rivela chi è e offre il Sigillo del Vuoto in cambio del frammento. | **Accettare il patto**, rifiutare, o mandarla via. |
| 9 | `c1_09_fauceverde_prima` | Davanti a Fauceverde. | Usare il Sigillo, cantare la Cantilena, o lottare e basta. |
| 10 | `c1_10_fauceverde_dopo` | Fauceverde è a terra. | **Abbatterla o placarla** (placarla richiede la Rottura o la Cantilena). |
| 11 | `c1_11_frammento` | Il vento torna. Ilva e Oride vogliono entrambe il frammento. | **Bivio 1**: Gilda, villaggio o Confraternita. |

### Come si arriva a placare Fauceverde

Placare è la strada più difficile, e il gioco la premia senza obbligarla.
La risposta "afferri la scheggia" è disponibile se vale almeno una di queste:

- in battaglia hai svuotato la barra di **Rottura** (il sistema di battaglia imposta
  `Cap1.FauceRotta`);
- conosci la **Cantilena della Fonte**, che Nilde ti insegna in piazza se sostieni
  il villaggio oppure se mostri il campione di polvere.

Chi ha sostenuto la Gilda in piazza può comunque placarla con la Rottura: Ilva lo
nota e ne chiede conto.

### Il primo bivio

| Scelta | `Trama.Bivio1` | Subito | Aggancio per i capitoli successivi |
| --- | --- | --- | --- |
| Lo consegni a Ilva | `gilda` | Gilda +15, Villaggi −3. Rango 2, lasciapassare del traghetto. | Il frammento viaggia verso la Rocca Maestra sotto scorta. |
| Lo affidi a Oride | `villaggio` | Villaggi +15, Gilda −5. Rango 2, lasciapassare. | Il frammento resta al Sacrario della Fonte, con Fauceverde di guardia se è viva. |
| Lo dai a Velia | `vuoto` | Confraternita +20, Gilda −15, Villaggi −10. Niente rango, lasciapassare grigio. | Ilva ti tiene d'occhio. La Confraternita ti considera uno dei suoi. |

La terza risposta compare solo con un patto con Velia oppure con reputazione
Confraternita 10 o più. Chi ha fatto il patto e poi non lo rispetta ottiene
`Cap1.PattoTradito` e Confraternita −10.

Gli altri due bivi e i due finali del gioco arriveranno nei capitoli successivi.
Suggerimento per chi li scriverà: i tre valori di `Trama.Bivio1` non devono chiudere
nessun finale, ma cambiare chi si fida di te e chi ti aiuta.

## Missioni secondarie

Ognuna ha almeno tre finali e mostra una meccanica diversa.

### Il mulino fermo (`c1_s1_mulino`)

Un branco di Saltarupe ha fatto il nido negli ingranaggi del mulino di Pina,
attirato dal grano sporco di polvere.

| Finale | Come | Conseguenze |
| --- | --- | --- |
| **Scacciati** | Lotti contro il branco. | Gilda +5, materiali, 120 monete. Pina è sollevata ma a disagio. |
| **Spostati** | Li attiri nel fienile con la Focaccia di semi (cucina). | Villaggi +6, ricetta, farina a metà prezzo. |
| **Venduti** | Catturi il capobranco e lo porti a Velia. | Confraternita +8, Villaggi −5, 300 monete. Vedi la Quiete da vicino. |

Davanti a Velia puoi ancora ripensarci e liberare il capobranco.

### Il compagno di Odo (`c1_s2_odo`)

Sasso, il Ciottolotto di Odo, è scappato verso la Grotta. Lo trovi che rosicchia
muschio nero.

| Finale | Come | Conseguenze |
| --- | --- | --- |
| **Riportato** | Lo ripulisci dalla polvere (devi sapere che cos'è). | Villaggi +6, amo fortunato. |
| **Affidato alla Gilda** | Lo catturi e lo porti a Ilva. | Gilda +5, Villaggi +2. Odo potrà riaverlo. |
| **Tenuto, con la verità** | Lo tieni in squadra e lo dici a Odo. | Villaggi −3, ottieni un Ciottolotto. |
| **Tenuto, con la bugia** | Lo tieni e dici di non averlo trovato. | Ottieni un Ciottolotto. Flag `Cap1.OdoMentito`: va ripreso più avanti. |

### Conti in sospeso (`c1_s3_conti`)

Il ferro destinato a Ferro arriva dimezzato. Malco lo vende di notte a un
barcaiolo col nastro color cenere, e con il ricavato sfama tre famiglie.
Il compratore è la Confraternita: il ferro serve per le sbarre delle gabbie.

| Finale | Come | Conseguenze |
| --- | --- | --- |
| **Denunciato** | Porti il registro a Ilva. | Gilda +8, Villaggi −3, sconto 10% alla fucina. |
| **Confessato** | Lo accompagni da Ilva e garantisci tu (serve Gilda 10+). | Gilda +5, Villaggi +4, due sconti. Il finale migliore per tutti. |
| **Coperto** | Taci, lui smette. | Villaggi +5, sconto 20% allo spaccio. |
| **Ricattato** | Ti fai pagare. | 200 monete, Villaggi −2. Ferro e Malco se lo ricordano. |

## Reputazione

Tre contatori, tutti a 0 all'inizio: `Rep.Gilda`, `Rep.Villaggi`, `Rep.Confraternita`.
Nel capitolo 1 ogni scelta sposta da 1 a 15 punti.

- **10 o più**: benvisto. Sblocca risposte (garantire per Malco), sconti e battute
  diverse in paese.
- **−10 o meno**: malvisto. Prezzi più alti, battute fredde.

`Legami.Brisa` funziona allo stesso modo ma riguarda solo lei: a 6 o più diventa
tua alleata fissa a fine capitolo, sotto 0 si allontana.

Valori massimi raggiungibili nel capitolo, per orientarsi nei capitoli successivi:
circa Gilda +65, Villaggi +70, Confraternita +50 (non tutti insieme: le scelte più
importanti alzano una fazione e ne abbassano un'altra).

## Fili lasciati aperti per i capitoli successivi

- Il padre di Brisa: la barca è tornata vuota nella Notte Verde.
- Chi ha spezzato lo Smeraldo dei Venti, e perché.
- La Quiete: si può invertire? Il Saltarupe nella gabbia di Velia è un buon banco di prova.
- Il ferro da sbarre comprato dalla Confraternita (`Cap1.SaFerroVuoto`).
- Odo e la bugia su Sasso (`Cap1.OdoMentito`).
- La luce verde a ponente, oltre lo stretto: destinazione del capitolo 2.
