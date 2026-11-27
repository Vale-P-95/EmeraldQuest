#!/usr/bin/env python3
"""Controlla le timeline di Dialogic (.dtl) senza aprire Godot.

Uso, dalla cartella del progetto:

    python3 tools/controlla_timeline.py

Che cosa controlla:
  1. ogni variabile {Cartella.Nome} usata nelle timeline esiste in
     tools/installa_variabili_storia.gd;
  2. ogni personaggio che parla ha la sua scheda in dialogic/characters/;
  3. ogni "jump" punta a un'etichetta ("label") che esiste;
  4. le risposte ("- ...") arrivano subito dopo una riga di testo, altrimenti
     Dialogic non mostra la domanda insieme alle risposte;
  5. nessuna riga di narrazione viene scambiata per un comando
     (per esempio una frase che comincia con "set" o "Nota:");
  6. i rientri sono fatti con il TAB e non saltano livelli;
  7. le missioni citate nei segnali esistono in data/quests/capitolo_1.json.

Se è tutto a posto stampa un riepilogo ed esce con codice 0,
altrimenti elenca i problemi ed esce con codice 1.
"""

import json
import re
import sys
from pathlib import Path

RADICE = Path(__file__).resolve().parent.parent
CARTELLA_TIMELINE = RADICE / "dialogic" / "timelines"
CARTELLA_PERSONAGGI = RADICE / "dialogic" / "characters"
FILE_VARIABILI = RADICE / "tools" / "installa_variabili_storia.gd"
FILE_MISSIONI = RADICE / "data" / "quests" / "capitolo_1.json"

# Parole con cui Dialogic riconosce un comando a inizio riga.
# Una riga di narrazione non deve cominciare così.
PREFISSI_COMANDO = ("set", "jump", "label", "join", "leave", "update",
                    "audio", "setting", "do ", "return")

RE_VARIABILE = re.compile(r"\{([A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)+)\}")
RE_BATTUTA = re.compile(r"^([^\s(:]+)\s*(\(.*\))?\s*:\s*\S")
RE_SEGNALE = re.compile(r'^\[signal arg="([^"]*)"\]$')
RE_SCELTA_OPZIONI = re.compile(r'\[else="(\w+)"')


def leggi_variabili() -> set[str]:
    """Legge l'elenco delle variabili dallo script di installazione."""
    testo = FILE_VARIABILI.read_text(encoding="utf-8")
    blocco = testo.split("# INIZIO_VARIABILI")[1].split("# FINE_VARIABILI")[0]
    # Il dizionario GDScript, scritto in forma semplice, è anche JSON valido.
    dizionario = json.loads(blocco[blocco.index("{"):])
    nomi: set[str] = set()

    def visita(cartella: dict, percorso: str) -> None:
        for chiave, valore in cartella.items():
            nome = f"{percorso}.{chiave}" if percorso else chiave
            if isinstance(valore, dict):
                visita(valore, nome)
            else:
                nomi.add(nome)

    visita(dizionario, "")
    return nomi


def tipo_riga(riga: str) -> str:
    """Dice che tipo di evento è una riga già ripulita dai rientri."""
    if riga.startswith("#"):
        return "commento"
    if riga.startswith("-"):
        return "scelta"
    if riga in ("if", "elif", "else") or riga.startswith(("if ", "elif ", "else")):
        return "condizione"
    if riga.startswith("["):
        return "codice"
    if riga.startswith("set"):
        return "variabile"
    if riga.startswith("jump"):
        return "jump"
    if riga.startswith("label"):
        return "label"
    return "testo"


def costruisci_eventi(righe: list[str]) -> tuple[list[dict], dict[int, int]]:
    """Ricostruisce la lista di eventi come fa Dialogic quando legge una timeline.

    Dialogic aggiunge un evento nascosto di "fine blocco" ogni volta che il rientro
    diminuisce. Serve per capire se una risposta è la prima del suo gruppo
    oppure la continuazione di un gruppo già aperto.
    Restituisce la lista degli eventi e, per ogni numero di riga, la sua posizione.
    """
    eventi: list[dict] = []
    posizione: dict[int, int] = {}
    aperti: list[int] = []       # posizioni degli eventi che hanno aperto un blocco
    livello_prima = 0
    apriva = False

    def chiudi() -> None:
        apertura = aperti.pop() if aperti else None
        eventi.append({"tipo": "fine", "apertura": apertura})

    for numero, originale in enumerate(righe, start=1):
        if not originale.strip():
            continue
        rientro = originale[: len(originale) - len(originale.lstrip())]
        livello = rientro.count("\t")
        for _ in range(max(0, livello_prima - livello)):
            chiudi()
        if apriva and livello <= livello_prima:
            chiudi()
        tipo = tipo_riga(originale.strip())
        continua = False
        if tipo == "scelta" and eventi and eventi[-1]["tipo"] == "fine":
            apertura = eventi[-1]["apertura"]
            continua = apertura is not None and eventi[apertura]["tipo"] == "scelta"
        posizione[numero] = len(eventi)
        eventi.append({"tipo": tipo, "continua_gruppo": continua})
        apriva = tipo in ("scelta", "condizione")
        if apriva:
            aperti.append(len(eventi) - 1)
        livello_prima = livello
    return eventi, posizione


def controlla_file(percorso: Path, variabili: set[str], personaggi: set[str],
                   missioni: set[str], etichette_per_file: dict[str, set[str]]) -> list[str]:
    problemi: list[str] = []
    nome = percorso.relative_to(RADICE)
    righe = percorso.read_text(encoding="utf-8").split("\n")
    etichette = etichette_per_file[percorso.stem]

    eventi, posizione = costruisci_eventi(righe)
    livello_precedente = 0
    apre_blocco = False         # l'evento precedente era una scelta o una condizione

    for numero, originale in enumerate(righe, start=1):
        if not originale.strip():
            continue

        def segnala(messaggio: str) -> None:
            problemi.append(f"{nome}:{numero}: {messaggio}")

        rientro = originale[: len(originale) - len(originale.lstrip())]
        if " " in rientro:
            segnala("rientro fatto con spazi: usa il tasto TAB")
        livello = rientro.count("\t")
        riga = originale.strip()
        tipo = tipo_riga(riga)

        if livello > livello_precedente + 1 or (livello > livello_precedente and not apre_blocco):
            segnala("rientro inatteso: questa riga non sta sotto una scelta o un if")

        # 1. Variabili
        if tipo != "commento":
            for variabile in RE_VARIABILE.findall(riga):
                if variabile not in variabili:
                    segnala(f"variabile sconosciuta {{{variabile}}}: aggiungila a "
                            "tools/installa_variabili_storia.gd")

        if tipo == "testo":
            # 5. Narrazione scambiata per comando
            if riga.startswith(PREFISSI_COMANDO):
                segnala("la frase comincia come un comando di Dialogic: riformulala")
            if "<" in riga or ">" in riga or "[" in riga:
                segnala("evita i caratteri < > [ nel testo: Dialogic li usa per gli effetti")
            if riga.endswith("\\"):
                segnala("la riga finisce con \\ e verrebbe unita alla successiva")
            # 2. Personaggi
            battuta = RE_BATTUTA.match(riga)
            if battuta and battuta.group(1) not in personaggi:
                segnala(f"'{battuta.group(1)}:' viene letto come nome di personaggio "
                        "ma non esiste in dialogic/characters/")

        elif tipo == "scelta":
            # 4. Le risposte devono seguire una riga di testo
            if not eventi[posizione[numero]]["continua_gruppo"]:
                indice = posizione[numero]
                if indice == 0 or eventi[indice - 1]["tipo"] != "testo":
                    segnala("la prima risposta deve venire subito dopo una riga di testo "
                            "(sposta commenti, set e label prima della domanda)")
            for azione in RE_SCELTA_OPZIONI.findall(riga):
                if azione not in ("hide", "disable", "default"):
                    segnala(f'else="{azione}" non valido: usa hide oppure disable')
            if "|" in riga and "[if" not in riga and "[else" not in riga:
                segnala("il carattere | è riservato alle condizioni delle risposte")

        elif tipo == "condizione":
            if not riga.endswith(":"):
                segnala("if, elif ed else devono finire con i due punti")

        elif tipo == "variabile":
            if not re.match(r"^set \{[^}]+\} (=|\+=|-=|\*=|/=) .+$", riga):
                segnala("comando set scritto male: set {Cartella.Nome} = valore")

        elif tipo == "jump":
            # 3. Destinazione dei jump
            destinazione = riga[len("jump"):].strip()
            if "/" in destinazione:
                timeline, etichetta = destinazione.split("/", 1)
                if timeline not in etichette_per_file:
                    segnala(f"jump verso una timeline che non esiste: {timeline}")
                elif etichetta and etichetta not in etichette_per_file[timeline]:
                    segnala(f"jump verso un'etichetta che non esiste: {destinazione}")
            elif destinazione not in etichette:
                segnala(f"jump verso un'etichetta che non esiste: {destinazione}")

        elif tipo == "codice":
            segnale = RE_SEGNALE.match(riga)
            if segnale:
                argomento = segnale.group(1)
                if "{" in argomento:
                    segnala("i segnali non leggono le variabili: usa un if con segnali diversi")
                # 7. Missioni
                parti = argomento.split(":")
                if parti[0].startswith("missione_") and (len(parti) < 2 or parti[1] not in missioni):
                    segnala(f"missione sconosciuta nel segnale: {argomento}")
            elif riga != "[end_timeline]":
                segnala(f"comando tra parentesi quadre non riconosciuto: {riga}")

        apre_blocco = tipo in ("scelta", "condizione")
        livello_precedente = livello

    return problemi


def main() -> int:
    variabili = leggi_variabili()
    personaggi = {p.stem for p in CARTELLA_PERSONAGGI.glob("*.dch")}
    missioni = {m["id"] for m in json.loads(FILE_MISSIONI.read_text(encoding="utf-8"))["missioni"]}
    timeline = sorted(CARTELLA_TIMELINE.rglob("*.dtl"))

    # Prima passata: raccoglie le etichette di ogni file.
    etichette_per_file: dict[str, set[str]] = {}
    for percorso in timeline:
        etichette = set()
        for riga in percorso.read_text(encoding="utf-8").split("\n"):
            riga = riga.strip()
            if riga.startswith("label "):
                etichette.add(riga[len("label "):].split("(")[0].strip())
        if percorso.stem in etichette_per_file:
            print(f"ERRORE: due timeline con lo stesso nome: {percorso.stem}")
            return 1
        etichette_per_file[percorso.stem] = etichette

    problemi: list[str] = []
    usate: set[str] = set()
    for percorso in timeline:
        problemi += controlla_file(percorso, variabili, personaggi, missioni, etichette_per_file)
        for riga in percorso.read_text(encoding="utf-8").split("\n"):
            if not riga.strip().startswith("#"):
                usate.update(RE_VARIABILE.findall(riga))

    for inutilizzata in sorted(variabili - usate):
        print(f"nota: la variabile {inutilizzata} è definita ma nessuna timeline la usa")

    if problemi:
        print("\n".join(problemi))
        print(f"\n{len(problemi)} problemi trovati.")
        return 1
    print(f"Tutto a posto: {len(timeline)} timeline, {len(usate)} variabili, "
          f"{len(personaggi)} personaggi, {len(missioni)} missioni.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
