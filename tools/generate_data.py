#!/usr/bin/env python3
"""Genera i .tres di tipi, abilità e creature.
Uso (dalla radice del progetto):  python3 tools/generate_data.py
Per cambiare un valore puoi modificare questo file e rigenerare, oppure
modificare il .tres dall'Inspector di Godot (in quel caso non rigenerare:
sovrascriverebbe le modifiche)."""
import os
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
S = "res://scripts/data/"
# Indici di Element.Type
E = {"fuoco":0,"acqua":1,"flora":2,"volt":3,"terra":4,"vento":5,"gelo":6,"luce":7,"ombra":8}
# attaccante: (forte contro, debole contro, immune)
CHART = {
 "fuoco": (["flora","gelo"], ["fuoco","acqua","terra"], []),
 "acqua": (["fuoco","terra"], ["acqua","flora"], []),
 "flora": (["acqua","terra"], ["fuoco","flora","vento","gelo"], []),
 "volt":  (["acqua","vento"], ["volt","flora"], ["terra"]),
 "terra": (["fuoco","volt"], ["flora","gelo"], ["vento"]),
 "vento": (["flora","ombra"], ["volt","terra"], []),
 "gelo":  (["flora","vento","terra"], ["fuoco","acqua","gelo"], []),
 "luce":  (["ombra","gelo"], ["fuoco","luce"], []),
 "ombra": (["luce","vento"], ["ombra","gelo"], []),
}
# id, nome, elemento, categoria(F/M/S), potenza, precisione, PA(0-5), effetto, % effetto, descrizione
SKILLS = [
 ("braciere","Braciere","fuoco","M",40,100,0,"bruciatura",10,"Piccole fiamme che possono bruciare il bersaglio."),
 ("lanciafiamme","Lanciafiamme","fuoco","M",85,100,3,"bruciatura",20,"Un getto di fuoco intenso."),
 ("zanna_ardente","Zanna Ardente","fuoco","F",70,95,2,"bruciatura",15,"Un morso rovente."),
 ("eruzione","Eruzione","fuoco","M",120,85,5,"",0,"Esplosione devastante: costa molti PA."),
 ("spruzzo","Spruzzo","acqua","M",40,100,0,"",0,"Un getto d'acqua veloce."),
 ("onda_marina","Onda Marina","acqua","M",80,100,3,"",0,"Un'onda che travolge il nemico."),
 ("morso_corallo","Morso Corallo","acqua","F",65,100,2,"difesa_giu",20,"Un morso tagliente di corallo."),
 ("tempesta","Tempesta","acqua","M",110,80,5,"confusione",20,"Pioggia torrenziale con forte vento."),
 ("frustata","Frustata","flora","F",40,100,0,"",0,"Una frustata di liane."),
 ("raggio_linfa","Raggio Linfa","flora","M",75,100,3,"assorbimento",100,"Cura il lanciatore di 1/4 del danno inflitto."),
 ("spora_sonno","Spora Sonno","flora","S",0,75,2,"sonno",100,"Spore che fanno addormentare il bersaglio."),
 ("radici_tenaci","Radici Tenaci","flora","F",90,95,4,"velocita_giu",30,"Radici robuste bloccano il nemico."),
 ("scossa","Scossa","volt","M",40,100,0,"paralisi",10,"Una piccola scarica elettrica."),
 ("arco_voltaico","Arco Voltaico","volt","M",80,100,3,"paralisi",20,"Un arco di elettricità."),
 ("tuono_a_catena","Tuono a Catena","volt","M",115,75,5,"paralisi",30,"Una tempesta di fulmini."),
 ("sassata","Sassata","terra","F",45,100,0,"",0,"Lancia un sasso."),
 ("frana","Frana","terra","F",85,90,3,"tentennamento",20,"Fa crollare massi sul nemico."),
 ("scudo_di_pietra","Scudo di Pietra","terra","S",0,100,1,"difesa_su",100,"Si ricopre di roccia: difesa +1."),
 ("spallata","Spallata","terra","F",40,100,0,"",0,"Una carica diretta."),
 ("soffio","Soffio","vento","M",40,100,0,"",0,"Una folata veloce."),
 ("lama_d_aria","Lama d'Aria","vento","M",70,95,2,"",0,"Taglia con aria compressa."),
 ("danza_del_vento","Danza del Vento","vento","S",0,100,1,"velocita_su",100,"Una danza leggera: velocità +1."),
 ("morso_ombra","Morso d'Ombra","ombra","F",60,100,2,"",0,"Un morso dalle tenebre."),
 ("velo_nero","Velo Nero","ombra","S",0,90,2,"precisione_giu",100,"Oscura la vista del bersaglio."),
 ("artiglio_notturno","Artiglio Notturno","ombra","F",85,100,3,"",0,"Artigli affilati nel buio."),
 ("lampo","Lampo","luce","M",50,100,1,"precisione_giu",15,"Un lampo accecante."),
 ("raggio_d_alba","Raggio d'Alba","luce","M",90,100,4,"",0,"Un raggio di pura luce."),
 ("benedizione","Benedizione","luce","S",0,100,2,"cura_25",100,"Cura il lanciatore di 1/4 dei PS massimi."),
 ("colpo_di_brina","Colpo di Brina","gelo","F",70,100,2,"congelamento",10,"Un pugno ghiacciato."),
 ("corazza_di_ghiaccio","Corazza di Ghiaccio","gelo","S",0,100,1,"difesa_su",100,"Si copre di ghiaccio: difesa +2."),
]
CAT = {"F":0,"M":1,"S":2}
SK = {s[0] for s in SKILLS}

# id, nome, elementi, (hp,atk,dif,mag,spi,vel), crescita, cattura, learnset[(lvl,skill)],
# evoluzioni[(condizione, parametri, target, ...)], descrizione, abilita_sul_campo
C = [
 ("fiammolo","Fiammolo",["fuoco"],(45,52,43,60,50,65),"media",190,
  [(1,"spallata"),(2,"braciere"),(7,"soffio"),(12,"zanna_ardente")],
  [dict(c="LIVELLO",lv=14,to="ardolupo")],
  "Un cucciolo di lupo con la coda in fiamme. La fiamma si spegne se è triste.","bruciare_rovi"),
 ("ardolupo","Ardolupo",["fuoco"],(65,75,60,80,65,80),"media",90,
  [(1,"braciere"),(2,"zanna_ardente"),(18,"lanciafiamme"),(24,"morso_ombra")],
  [dict(c="ORA_DEL_GIORNO",lv=30,time="notte",to="infernolupo"),
   dict(c="OGGETTO",lv=1,item="pietra_solare",to="aurelupo")],
  "Corre nelle praterie lasciando una scia di scintille. Si evolve in due modi: al livello 30 di notte, o con una Pietra Solare.","bruciare_rovi"),
 ("infernolupo","Infernolupo",["fuoco","ombra"],(85,100,75,100,75,95),"lenta",45,
  [(1,"lanciafiamme"),(2,"morso_ombra"),(34,"artiglio_notturno"),(42,"eruzione")],[],
  "Un lupo nero dagli occhi ardenti, cacciatore delle notti d'estate.","bruciare_rovi"),
 ("aurelupo","Aurelupo",["fuoco","luce"],(85,70,80,105,95,80),"lenta",45,
  [(1,"lanciafiamme"),(2,"lampo"),(34,"raggio_d_alba"),(42,"eruzione")],[],
  "Il suo manto dorato brilla come il sole all'alba.","bruciare_rovi"),
 ("gocciolo","Gocciolo",["acqua"],(50,45,50,60,55,55),"media",190,
  [(1,"spallata"),(2,"spruzzo"),(8,"soffio"),(13,"morso_corallo")],
  [dict(c="LIVELLO",lv=18,to="marealto"),
   dict(c="AMICIZIA",lv=18,val=220,to="coralunghi")],
  "Una creatura gelatinosa delle pozze. Evolve al livello 18; se però è molto affezionato (amicizia 220+) diventa Coralunghi.","riempire_pozze"),
 ("marealto","Marealto",["acqua"],(80,70,75,90,80,60),"lenta",75,
  [(1,"spruzzo"),(2,"morso_corallo"),(22,"onda_marina"),(36,"tempesta")],[],
  "Cavalca le onde: i pescatori dicono che porti buona sorte.","riempire_pozze"),
 ("coralunghi","Coralunghi",["acqua","terra"],(85,80,95,75,85,45),"lenta",75,
  [(1,"spruzzo"),(2,"sassata"),(22,"onda_marina"),(28,"scudo_di_pietra"),(36,"frana")],[],
  "Il suo guscio di corallo cresce con l'affetto che riceve.","riempire_pozze"),
 ("germoglio","Germoglio",["flora"],(48,45,55,58,55,45),"media",190,
  [(1,"spallata"),(2,"frustata"),(9,"spora_sonno"),(14,"raggio_linfa")],
  [dict(c="LIVELLO",lv=16,to="fogliarbo")],
  "Un piccolo spirito del bosco con un bocciolo sulla testa.","tagliare_rovi"),
 ("fogliarbo","Fogliarbo",["flora"],(70,70,75,85,75,55),"media",90,
  [(1,"frustata"),(2,"raggio_linfa"),(20,"radici_tenaci"),(26,"spora_sonno")],
  [dict(c="LIVELLO",lv=34,to="selvarbo")],
  "Il suo corpo è un tronco vivo; gli uccelli vi fanno il nido.","tagliare_rovi"),
 ("selvarbo","Selvarbo",["flora","terra"],(95,95,105,85,90,40),"lenta",45,
  [(1,"radici_tenaci"),(2,"raggio_linfa"),(38,"frana"),(44,"scudo_di_pietra")],[],
  "Un guardiano della foresta con corteccia dura come la roccia.","tagliare_rovi"),
 ("scintilla","Scintilla",["volt"],(40,45,40,65,50,80),"veloce",190,
  [(1,"spallata"),(2,"scossa"),(8,"soffio"),(14,"arco_voltaico")],
  [dict(c="LIVELLO",lv=20,to="fulgurala")],
  "Rimbalza ovunque, carica di elettricità statica.","accendere_lampioni"),
 ("fulgurala","Fulgurala",["volt","vento"],(70,70,60,100,75,110),"veloce",60,
  [(1,"arco_voltaico"),(2,"lama_d_aria"),(24,"danza_del_vento"),(32,"tuono_a_catena")],[],
  "Vola veloce come il lampo e precede i temporali.","accendere_lampioni"),
]
COND = {"LIVELLO":0,"OGGETTO":1,"LUOGO":2,"ORA_DEL_GIORNO":3,"AMICIZIA":4,"REPUTAZIONE":5}
for c in C:
    for _,s in c[6]: assert s in SK, s

def w(path, text):
    p = os.path.join(ROOT, path); os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p,"w",encoding="utf-8").write(text)

# Tabella tipi
lines=[]
for a,(se,nv,im) in CHART.items():
    for d in se: lines.append((a,d,2.0))
    for d in nv: lines.append((a,d,0.5))
    for d in im: lines.append((a,d,0.0))
body = ",\n".join(f"Vector2i({E[a]}, {E[d]}): {v}  # {a} -> {d}".replace("  #","") if False else f"Vector2i({E[a]}, {E[d]}): {v}" for a,d,v in lines)
w("data/types/type_chart.tres", f'''[gd_resource type="Resource" script_class="TypeChart" format=3]

[ext_resource type="Script" path="{S}type_chart.gd" id="1_chart"]

[resource]
script = ExtResource("1_chart")
effectiveness = Dictionary[Vector2i, float]({{
{body}
}})
''')

for (i,n,t,cat,pw,ac,ap,ef,pc,ds) in SKILLS:
    w(f"data/skills/{i}.tres", f'''[gd_resource type="Resource" script_class="SkillData" format=3]

[ext_resource type="Script" path="{S}skill_data.gd" id="1_skill"]

[resource]
script = ExtResource("1_skill")
id = &"{i}"
display_name = "{n}"
description = "{ds}"
element = {E[t]}
category = {CAT[cat]}
power = {pw}
accuracy = {ac}
ap_cost = {ap}
status_effect = &"{ef}"
status_chance = {pc}
''')

for (i,n,tp,st,gr,cr,ls,evs,ds,fs) in C:
    ext=[f'[ext_resource type="Script" path="{S}creature_data.gd" id="1_creature"]',
         f'[ext_resource type="Script" path="{S}evolution_rule.gd" id="2_rule"]']
    for s in sorted({s for _,s in ls}):
        ext.append(f'[ext_resource type="Resource" path="res://data/skills/{s}.tres" id="s_{s}"]')
    for e in evs:
        ext.append(f'[ext_resource type="Resource" path="res://data/creatures/{e["to"]}.tres" id="c_{e["to"]}"]')
    subs=[]; names=[]
    for k,e in enumerate(evs,1):
        t=f'[sub_resource type="Resource" id="Rule_{k}"]\nscript = ExtResource("2_rule")\nevolves_into = ExtResource("c_{e["to"]}")\ncondition = {COND[e["c"]]}\nmin_level = {e["lv"]}\n'
        if "item" in e: t+=f'required_item = &"{e["item"]}"\n'
        if "time" in e: t+=f'time_of_day = "{e["time"]}"\n'
        if "val" in e: t+=f'required_value = {e["val"]}\n'
        subs.append(t); names.append(f'SubResource("Rule_{k}")')
    lsx = ",\n".join(f'{l}: ExtResource("s_{s}")' for l,s in ls)
    types = ", ".join(str(E[x]) for x in tp)
    parts = "\n".join(ext)+"\n\n"+("\n".join(subs)+"\n" if subs else "")
    ev = f'evolutions = Array[ExtResource("2_rule")]([{", ".join(names)}])\n' if names else ""
    w(f"data/creatures/{i}.tres", f'''[gd_resource type="Resource" script_class="CreatureData" format=3]

{parts}[resource]
script = ExtResource("1_creature")
id = &"{i}"
display_name = "{n}"
description = "{ds}"
types = Array[int]([{types}])
hp = {st[0]}
attack = {st[1]}
defense = {st[2]}
magic = {st[3]}
spirit = {st[4]}
speed = {st[5]}
growth = "{gr}"
learnset = Dictionary[int, Resource]({{
{lsx}
}})
{ev}catch_rate = {cr}
field_skill = &"{fs}"
''')
print(len(SKILLS),"abilità,",len(C),"creature")
