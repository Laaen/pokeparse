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
import std/unicode

# Couleurs pour les types de pokemons
type
  TypeColor = enum
    Flying = ("blue")

type
  LogType = enum
    Error
    Info

type
  RecupError = object of CatchableError

type
  Pokemon* = object of RootObj
    nom : string
    tier : string
    types : seq[string]

proc tier* (p : Pokemon) : string = p.tier
proc nom* (p : Pokemon) : string = p.nom
proc types* (p: Pokemon) : seq[string] = p.types
proc repr (p: Pokemon) : string = 
  &"{p.nom.toLower.capitalize} | Type(s) : {p.types.join(sep = \" \")}"


proc getV(h : JsonNode, k : string) : string =
  return h[k].getSTr().toUpper()

proc log(l_type : LogType, contenu : string) = 
  ## Permet de logger des infos ou erreurs
  case l_type
    of LogType.Error: stdout.styledWriteLine(fgRed, contenu & "\n")
    of LogType.Info : stdout.styledWriteLine(fgYellow, contenu & "\n")

proc getPkdx() : auto = 
  ## Retreives the json, parses it and returns a seq of Pokemon objects 
  # Récupération du contenu, et parsage du JSON
  let client = newHttpClient()
  var contenu : string
  try:
    contenu = client.getContent("https://play.pokemonshowdown.com/data/pokedex.json")
  except CatchableError as e:
    raise newException(RecupError, &"Erreur lors de la récupération du json : {e.msg}")
  finally:
    client.close()
  let parsed_content = parseJson(contenu)

  # On crée la liste de pokémons, on exclut les pokémons sans tier
  result = collect:
    for e in parsed_content.keys: 
      if parsed_content[e].hasKey("tier"):
        # On récupère la liste de types
        let types = collect:
          for elt in items(parsed_content[e]["types"]):
            elt.getStr()
        Pokemon(nom : parsed_content[e].getV("name"), tier : parsed_content[e].getV("tier"), types : types)

proc recupRand(liste_pk : openArray[Pokemon], nombre : int): auto = 
  ## Retourne un openAr ray de nombre pokémons choisis au hasard dans la liste liste_pk
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

# On affiche quelques infos
echo splash
# On charge la loste de pokemons
let pokedex = getPkdx()

# Boucle, on demande à l'uilisateur d'entrer un tier
var entree = ""
var nombre = 0 # Nombre de pokémons à tirer
while not (entree =~ re"[q|Q]"):
  
  stdout.write prompt_tier
  entree = readLine(stdin).toUpper()
  
  # On essaie de récupérer la liste des pokémons du tier choisi, si len liste == 0, on reboucle
  let liste_pkmn = pokedex.filter((p) => p.tier == entree)
  if liste_pkmn.len == 0:
    if not (entree =~ re"[q|Q]"):
      log(LogType.Error, &"Erreur, le tier {entree} n'existe pas")
    continue  

  # On demande un nombre (réaliste de 1 à taille de la liste)
  while not (nombre in 1..liste_pkmn.len):
    stdout.write(&"Entrez le nombre de Pokémons à récupérer (entre 1 et {liste_pkmn.len - 1})\n=> ")
    # var temporaire pour stocker l'entrée utilisateur
    let nb = readline(stdin)
    discard parseint(nb, nombre)
  
  echo ""
  # On a le bon nombre, on va récupérer X pokémons du tier demande, et les afficher
  for e in liste_pkmn.recupRand(nombre):
    echo e.repr
  echo ""

  # On reset le nombre et l'entrée
  nombre = 0
  entree = ""
