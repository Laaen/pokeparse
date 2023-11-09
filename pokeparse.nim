import std/sugar
import std/json
import std/tables
import std/strutils
import std/sequtils
import std/httpclient
import std/terminal
import std/re
import std/enumutils
import std/strformat
import std/parseutils
import std/random

type
  LogType = enum
    Error
    Info

type
  RecupError = object of CatchableError

type
  Tier = enum
    Illegal, LC, NFE, PU, PrPU = "(PU)", RU, OU, NUBL, UU, PUBL, NU, RUBL, Uber, UUBL, AG, CAPLC = "CAP LC", CAP, CAPNFE = "CAP NFE"

type
  Pokemon* = object of RootObj
    nom : string
    tier : Tier

proc tier* (p : Pokemon) : Tier = p.tier
proc nom* (p : Pokemon) : string = p.nom

proc log(l_type : LogType, contenu : string) = 
  ## Permet de logger des infos ou erreurs
  echo contenu

proc getPkdx() : auto = 
  ## Retreives the json, parses it and returns a seq of Pokemon objects 
  # Récupération du contenu, et parsage du JSON
  let client = newHttpClient()
  var contenu : string
  try:
    # contenu = client.getContent("https://pokemonshowdown.com/data/pokedex.json")
    contenu = readfile("pokedex.json")
  except:
    raise newException(RecupError, "Erreur lors de la récupération du json")
  finally:
    client.close()
  let parsed_content = parseJson(contenu)

  # On récupère toutes les clés pour itérer dessus
  let cles = collect(newSeq):
    for k in parsed_content.keys:
      k

  # On crée le dico, on ignore les pokemons sans tier
  result = collect:
    for e in cles:
      if parsed_content[e].hasKey("tier"):
        Pokemon(nom : parsed_content[e]["name"].getStr(), tier : parseEnum[Tier](parsed_content[e]["tier"].getStr()))


proc getByTier(liste_pk : openArray[Pokemon], tier: string): auto =
  ## On récupère tous les pokémons du tier choisi
  # On crée un openarray qui ne contient que les poké du tier choisi
  result = collect:
    for p in liste_pk:
      if p.tier == parseEnum[Tier](tier):
        p

proc recupRand(liste_pk : openArray[Pokemon], nombre : int): auto = 
  ## Retourne un openArray de nombre pokémons choisis au hasard dans la liste liste_pk
  result = collect:
    for i in 1..nombre:
       liste_pk.sample()

##################################
# Boucle principale du programme #
##################################

const splash = """  _____      _        _____                    
 |  __ \    | |      |  __ \                   
 | |__) |__ | | _____| |__) |_ _ _ __ ___  ___ 
 |  ___/ _ \| |/ / _ \  ___/ _` | '__/ __|/ _ \
 | |  | (_) |   <  __/ |  | (_| | |  \__ \  __/
 |_|   \___/|_|\_\___|_|   \__,_|_|  |___/\___|
                                               
                                               """
const prompt_tier = """Entrez un tier (Illegal, LC, NFE, PU, (PU), RU, OU, NUBL, UU, PUBL, NU, RUBL, Uber, UUBL, AG,CAP LC, CAP, CAP NFE) (q pour quitter) 
=>  """
const prompt_nb = """Entrez le nombre de pokémons à récupérer 
=> """

# On affiche quelques infos
echo splash
# On charge le pokedex
let pokedex = getPkdx()

# On crée une map avec pour clé le Tier et pour valeur la liste de Pokemon
let map_pkdx = collect:
  for e in Tier.items:
    {$e : pokedex.getByTier($e)}

# Boucle, on demande à l'uilisateur d'entrer un tier
var entree = ""
var liste_pkmn : seq[Pokemon] # Liste des pokémons d'un même tier
var nombre = 0 # Nombre de pokémons à tirer
while not (entree =~ re"[q|Q]"):
  stdout.write prompt_tier
  entree = readLine(stdin)
  # On essaie de récupérer la liste des pokémons du tier choisi, si erreur => l'entrée est incorrecte, on continue
  try:
    liste_pkmn = map_pkdx[entree]
  except:
    # Histoire de ne pas afficher d'erreur lorsqu'on quitte
    if not(entree =~ re"[q|Q]"):
      log(LogType.Error, &"Tier inconnu : {entree}")
    continue
  # On demande un nombre (réaliste de 1 à taille de la liste)
  while (nombre <= 0) or (nombre >= liste_pkmn.len):
    stdout.write(prompt_nb)
    try:
      # var temporaire pour stocker l'entrée utilisateur
      let nb = readline(stdin)
      discard parseint(nb, nombre)
    except:
      log(LogType.Error, &"Nombre invalide, il doit être entre 1 et {liste_pkmn.len}")
  # On a le bon nombre, on va récupérer X pokémons de la liste, et les afficher
  for e in liste_pkmn.recupRand(nombre):
    echo &"{e.nom}"

  # On reset le nombre et l'entrée
  nombre = 0
  entree = ""
