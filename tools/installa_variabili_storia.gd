@tool
extends EditorScript
## Crea in un colpo solo tutte le variabili di Dialogic usate dalla storia.
##
## COME SI USA (una volta sola, dopo aver installato Dialogic):
##   1. Apri questo file nell'editor degli script di Godot.
##   2. Menu File > Esegui (oppure Ctrl+Maiusc+X).
##   3. Leggi il messaggio nel pannello "Output" in basso.
##   4. Riavvia l'editor: le variabili compaiono nella scheda Dialogic > Variabili.
##
## Lo script non cancella e non sovrascrive niente: aggiunge solo le variabili
## che mancano. Puoi rieseguirlo ogni volta che la storia ne introduce di nuove.
##
## Le variabili sono organizzate in cartelle. Nelle timeline si scrivono
## tra parentesi graffe, per esempio {Rep.Gilda} oppure {Cap1.PattoVelia}.

## Elenco delle variabili con il loro valore iniziale.
## Numeri = contatori, true/false = interruttori (flag), "" = testo.
## ATTENZIONE: tools/controlla_timeline.py legge questo elenco, quindi va tenuto
## in questo formato semplice (solo testi, numeri, true e false, senza commenti dentro).
# INIZIO_VARIABILI
const VARIABILI := {
	"Giocatore": {
		"Nome": "Recluta",
		"Rango": 1
	},
	"Rep": {
		"Gilda": 0,
		"Villaggi": 0,
		"Confraternita": 0
	},
	"Legami": {
		"Brisa": 0
	},
	"Trama": {
		"Bivio1": ""
	},
	"Cap1": {
		"Starter": "",
		"StarterNome": "",
		"PromessaOride": false,
		"VeliaIncontrata": false,
		"VeliaSospetto": false,
		"PromessaVelia": false,
		"PolvereRaccolta": false,
		"PolvereMostrata": false,
		"VeliaDenunciata": false,
		"VeliaTaciuta": false,
		"Posizione": "",
		"Cantilena": false,
		"CantilenaUsata": false,
		"HaMateriali": false,
		"HaAntidoto": false,
		"BrisaCurata": false,
		"BrisaRimandata": false,
		"BrisaAlleata": false,
		"SaQuiete": false,
		"SaPianoVuoto": false,
		"SaFerroVuoto": false,
		"PattoVelia": false,
		"VeliaRespinta": false,
		"SigilloUsato": false,
		"FauceRotta": false,
		"FauceEsito": "",
		"PattoTradito": false,
		"MulinoStato": 0,
		"MulinoEsito": "",
		"MulinoPolvere": false,
		"MulinoBugia": false,
		"HaFocaccia": false,
		"HaSaltarupeSmanioso": false,
		"OdoStato": 0,
		"OdoEsito": "",
		"OdoMentito": false,
		"ContiStato": 0,
		"ContiEsito": "",
		"MalcoRicattato": false
	}
}
# FINE_VARIABILI


## Godot chiama questa funzione quando scegli File > Esegui.
func _run() -> void:
	# Le variabili di Dialogic vivono nelle impostazioni del progetto, sotto questa chiave.
	var attuali: Dictionary = ProjectSettings.get_setting("dialogic/variables", {})
	# duplicate(true) crea una copia completa, così non modifichiamo l'originale per sbaglio.
	var aggiornate: Dictionary = attuali.duplicate(true)

	var aggiunte: int = _aggiungi_mancanti(aggiornate, VARIABILI)

	if aggiunte == 0:
		print("[Storia] Tutte le variabili esistono già: non ho cambiato niente.")
		return

	ProjectSettings.set_setting("dialogic/variables", aggiornate)
	var errore: int = ProjectSettings.save()
	if errore != OK:
		push_error("[Storia] Non sono riuscito a salvare project.godot (errore %d)." % errore)
		return
	print("[Storia] Ho aggiunto %d variabili a Dialogic. Riavvia l'editor per vederle." % aggiunte)


## Copia da "sorgente" a "destinazione" solo le voci che mancano.
## Restituisce quante variabili ha aggiunto.
## Le cartelle sono dizionari dentro dizionari, quindi la funzione richiama sé stessa.
func _aggiungi_mancanti(destinazione: Dictionary, sorgente: Dictionary) -> int:
	var aggiunte: int = 0
	for chiave: String in sorgente:
		var valore: Variant = sorgente[chiave]
		if valore is Dictionary:
			# È una cartella: la creiamo se non c'è, poi guardiamo dentro.
			if not destinazione.has(chiave) or not (destinazione[chiave] is Dictionary):
				destinazione[chiave] = {}
			aggiunte += _aggiungi_mancanti(destinazione[chiave], valore)
		elif not destinazione.has(chiave):
			# È una variabile che manca: la aggiungiamo con il valore iniziale.
			destinazione[chiave] = valore
			aggiunte += 1
	return aggiunte
