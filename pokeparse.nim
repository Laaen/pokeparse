import std/sugar
import std/json
import std/tables
import std/strutils
import std/sequtils
import std/httpclient
import std/strformat
import std/parseutils
import std/random
import std/unicode
import neel
import flatty
import std/algorithm

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
proc repr (p: Pokemon) : string = &"{p.nom.toLower.capitalize} | Type(s) : {p.types.join(sep = \" \")}"

proc box[T](x: T): ref T =
  new(result); result[] = x

proc getV(h : JsonNode, k : string) : string =
  return h[k].getSTr().toUpper()

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
        Pokemon(nom : parsed_content[e].getV("name"), tier : parsed_content[e].getV("tier").toLower, types : types)

proc loadPkdx(): seq[Pokemon] = 
  ## Génère une liste de pokemons à partir du fichier
  let file = open("pokedex", fmRead)
  result = fromFlatty(file.readAll, seq[Pokemon])
  file.close()

proc generateRes(p_list : seq[Pokemon]) : string =
  ## Génère un string de <p> 
  for e in p_list:
    result.add(&"<p>{e.repr}</p>\n")
  return result

proc generateOpt(a : seq[Pokemon]) : string =
  ## Retourne les tiers sous forme d'options à injecter dans la page html
  var tiers = collect:
    for elt in a:
      elt.tier.toUpper
  tiers = tiers.deduplicate().sorted

  for elt in tiers:
    result.add(&"<option>{elt}</option>\n")
  return result

proc recupRand(nombre : int, liste_tier : ref seq[string]): seq[Pokemon] = 
  ## Retourne un openArray de nombre pokémons choisis au hasard dans un tier donné
  
  # Liste filtrée, on a retiré les pokémons des tiers non selectionnés
  var filtered_list = loadPkdx().filter(p => p.tier in liste_tier[])

  # On vérifie que le nombre est bien inférieur à la taille max
  var maxi = nombre
  if nombre > filtered_list.len:
    maxi = filtered_list.len

  for i in 1..maxi: 
    result.add(filtered_list.sample)
    filtered_list.delete(filtered_list.find(result[^1]))

##################################
# Boucle principale du programme #
##################################

# Mise à jour du fichier pokedex
let pokedex = getPkdx()
let file = open("pokedex", fmWrite)
file.write(toFlatty(pokedex))
file.close()

exposeProcs:
    proc getPokemons(jsMsg: string) =
        ## Gets "number" pokemons of the given Tier List
        # Parse the params
        let params = parseJson(jsMsg)
        let tiers = params["tiers"].getElems.map(e => e.getStr.toLower)
        var nb : int
        discard params["number"].getStr.parseInt(nb)
        # Get the pokemons list
        callJs("inject_res", generateRes(recupRand(nb, box(tiers))))
    
    proc setupListBox() =
      ## Injecte les tiers dans la listbox
      callJs("inject_list", generateOpt(loadPkdx()))


startApp(webDirPath = currentSourcePath.parentDir / "assets", size= [700,600])



