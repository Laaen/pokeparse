function get_pokemons(param){
    neel.callNim("getPokemons", param)
}

function inject_res(str){
    conteneur = document.getElementById("div_droite")
    conteneur.innerHTML=str
}

function setup_list(){
    neel.callNim("setupListBox")
}

function inject_list(str){
    listBox = document.getElementById("tiers")
    listBox.innerHTML = str
}