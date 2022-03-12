import { idlFactory, FishTank } from "../../declarations/FishTank";
import { AuthClient } from "@dfinity/auth-client";
import { Actor, ActorCallError, HttpAgent } from "@dfinity/agent";
import { Principal } from "@dfinity/principal";
import { Identity } from "@dfinity/identity";

import ledgerInterfaceDid from "./ledgerInterface.did";

var currentProfile;

const hiddenClass = "hidden";
const bootcamp_canister = "yeeiw-3qaaa-aaaah-qcvmq-cai";
const backend_canister = "qo6ef-eaaaa-aaaai-abyyq-cai";
const canisterAccount = "4f02cf4e2896917db36daaf2ce12d1f8b47a3a644390f7851f83afcc99e954b3"

const verifyConnection = async () => {
  const connected = await window.ic.plug.isConnected();
  if (!connected) await window.ic.plug.requestConnect({
    whitelist: [bootcamp_canister,
      backend_canister]
  });
};

const mytankbtn = document.getElementById("mytank");
const randombtn = document.getElementById("getrandom");
const loginbtn = document.getElementById("login");
//const logoutbtn = document.getElementById("logout");
const mintbtn = document.getElementById("mint");
const nextrandbtn = document.getElementById("nextrand");

mytankbtn.addEventListener("click", myTankClick);
randombtn.addEventListener("click", randomTankClick);
loginbtn.addEventListener("click", loginClick);
//logoutbtn.addEventListener("click", logoutClick);
mintbtn.addEventListener("click", mintClick);
nextrandbtn.addEventListener("click", nextRandClick);

//Admin tasks
//document.getElementById("resetall").addEventListener("click", resetAll);
//document.getElementById("getlogs").addEventListener("click", getLogs);
/*    
<section id="adminbuttons">
      <p>Admin buttons will be removed or gated for production</p>
      <button id="getlogs">Get Logs</button>
      <button id="resetall">Reset all states</button>
    </section>
    <section>
      <p id="logs"></p>
    </section>
*/
async function myTankClick(e) {
  mytankbtn.disabled = true;

  await loadMyTank();

  mytankbtn.disabled = false;
  mytankbtn.classList.add(hiddenClass);
  randombtn.classList.remove(hiddenClass);
  nextrandbtn.classList.add(hiddenClass);
  mintbtn.classList.remove(hiddenClass);
}

async function loadMyTank() {
  await verifyConnection();
  const actor = await window.ic.plug.createActor({
    canisterId: backend_canister,
    interfaceFactory: idlFactory,
  });

  removeAllFishesFromTank();
  updateTankColor(currentProfile.tank_color);
  var fishes = await actor.allOwnedTokens();
  for (var i = 0; i < fishes.length; i++) {
    loadFish(fishes[i][0], fishes[i][1].properties);
  }
}

function updateTankColor(color){
  var tank = document.getElementById("tankobj").getSVGDocument().getElementById("tank");
  tank.getElementById("water3-gradient").children[1].setAttribute("stop-color", color);
}

async function randomTankClick(e) {
  randombtn.disabled = true;

  await loadRandomTank();

  randombtn.disabled = false;
  randombtn.classList.add(hiddenClass);
  mytankbtn.classList.remove(hiddenClass);
  mintbtn.classList.add(hiddenClass);
  nextrandbtn.classList.remove(hiddenClass);
}

async function loadRandomTank() {
  removeAllFishesFromTank();
  var results = await FishTank.randomOwnerAll();
  updateTankColor(results[0].tank_color);
  var fishes = results[1];
  for (var i = 0; i < fishes.length; i++) {
    loadFish(fishes[i][0], fishes[i][1].properties);
  }
}

async function loginClick(e) {
  loginbtn.disabled = true;

  await login();
  console.log(currentProfile);
  myTankClick();
  loginbtn.disabled = false;
  loginbtn.classList.add(hiddenClass);
  //logoutbtn.classList.remove(hiddenClass);
}

async function login() {
  const hasAllowed = await window.ic?.plug?.requestConnect({
    whitelist: [bootcamp_canister,
      backend_canister]
  });

  if (hasAllowed) {
    console.log("Plug wallet is connected");
    const actor = await window.ic.plug.createActor({
      canisterId: backend_canister,
      interfaceFactory: idlFactory,
    });

    var result = await actor.getProfile();
    if(result.err === "NOPROFILE") {
      result = await actor.createProfile();
    }
    currentProfile = result.ok;

    console.log(currentProfile);
  } else {
    console.log("Plug wallet connection was refused");
  }
}

// Disconnect doesn't seem to work keeps locking up, and I can't find documentation on it
/*
async function logoutClick(e) {
  logoutbtn.disabled = true;

  await logout();
  await randomTankClick();
  logoutbtn.disabled = false;
}

async function logout() {
  // Doesn't seem to work
  await window.ic.plug.disconnect();
}*/

async function getLogs(e) {
  e.target.disabled = true;
  document.getElementById("logs").innerText = await FishTank.getLogs();
  e.target.disabled = false;
};

async function resetAll(e) {
  e.target.disabled = true;
  await FishTank.resetAllState();
  e.target.disabled = false;
}

async function mintClick(e) {
  mintbtn.disabled = true;

  await mint();

  // mintbtn.disabled = false;
}

async function mint() {
  mintbtn.innerText = "Processing Payment!";
  await verifyConnection();
  
  //send funds
  const faucetActor = await window.ic.plug.createActor({
    canisterId: bootcamp_canister,
    interfaceFactory: ledgerInterfaceDid
  })

  const sendArgs = {
    to: canisterAccount,
    fee: { e8s: 10000 },
    memo: 0,
    from_subaccount: [],
    created_at_time: [],
    amount: { e8s: 1000000000 }
  };

  try{
    var block_height = await faucetActor.send_dfx(sendArgs);
    mintbtn.innerText = "Minting Fish!";
    // Let minter know you sent funds and want to you NFT minted
    const actor = await window.ic.plug.createActor({
      canisterId: backend_canister,
      interfaceFactory: idlFactory,
    });

    var mintResult = await actor.mint(block_height);
    if (mintResult.ok) {
      mintbtn.innerText = "Congrats on new Fish!";
      var fishId = mintResult.ok[0];
      var fish = mintResult.ok[1];
      loadFish(fishId, fish.properties);
      document.getElementById("nftmetadata").innerText = `Minted at: ${fish.minted_at}
        Minted by: ${fish.minted_by}
        Color 1: ${fish.properties.color_1}
        Color 2: ${fish.properties.color_2}`;
    }
  } catch(e){
    console.log(e);
    mintbtn.innerText = "Failed to Mint!";
  }

  setTimeout(()=> {mintbtn.innerText = "Mint!"; mintbtn.disabled = false;}, 1000);
}

async function nextRandClick(e) {
  nextrandbtn.disabled = true;

  await loadRandomTank();

  nextrandbtn.disabled = false;
}

function clickedOnFish(e) {
  var fishsvg = e.currentTarget.parentElement;
  console.log("clicked on: " + fishsvg.id);
  if (fishsvg.classList.contains("selectedfish")) {
    fishsvg.classList.remove("selectedfish");
    triggerDelayedRedraw();
  } else {
    var tanksvg = fishsvg.parentElement;
    tanksvg.removeChild(fishsvg);
    tanksvg.appendChild(fishsvg);
    fishsvg.classList.add("selectedfish");
  }
}

function loadFish(fishId, properties) {
  var fishesCSS = document.getElementById("tankobj").getSVGDocument().getElementById('fishes').sheet;
  var tank = document.getElementById("tankobj").getSVGDocument().getElementById("tank");
  var basefish = document.getElementById("basefishobj").getSVGDocument().getElementById("base_fish");
  let fish = basefish.cloneNode(true);

  let animationDelay = Math.random() * 5;
  let animationTime = (Math.random() * 15) + 30;
  let y = 0;
  while (y < .1 || y > .9) {
    y = Math.random();
  }
  y = y * 1080;

  let fishPrefix = "fish_" + fishId;
  var innerhtml = fish.innerHTML;
  innerhtml = innerhtml.replaceAll("animation-duration: 30s;", `animation-duration: ${animationTime}s;`);
  innerhtml = innerhtml.replaceAll("animation-delay: 0s;", `animation-delay: ${animationDelay}s;`);
  innerhtml = innerhtml.replaceAll("translateY(1000000px)", `translateY(${y}px)`);
  innerhtml = innerhtml.replaceAll("base_fish", fishPrefix);
  fish.innerHTML = innerhtml;

  tank.appendChild(fish);
  fish.id = fishPrefix;
  fish.getElementById(fishPrefix + "_linear-gradient").children[0].setAttribute("stop-color", properties.color_1);
  fish.getElementById(fishPrefix + "_linear-gradient").children[2].setAttribute("stop-color", properties.color_2);

  fish.getElementById(fishPrefix + "_radial-gradient").children[1].setAttribute("stop-color", properties.color_1);

  fish.getElementById(fishPrefix + "_radial-gradient-2").children[0].setAttribute("stop-color", properties.color_1);
  fish.getElementById(fishPrefix + "_radial-gradient-2").children[3].setAttribute("stop-color", properties.color_2);
  fish.getElementById(fishPrefix + "_radial-gradient-2").children[4].setAttribute("stop-color", properties.color_1);
  fish.getElementById(fishPrefix + "_radial-gradient-2").children[5].setAttribute("stop-color", properties.color_2);

  fish.getElementById("Layer_2").addEventListener("click", clickedOnFish);
  let fishBGRule = `#${fishPrefix} g:first-of-type rect{
          fill: transparent;
      }`;

  let fishPartsRule = `#${fishPrefix} g {
          transform: translateY(${y}px) translateX(-13%) scale(${.15});
      }`;

  fishesCSS.insertRule(fishBGRule, 0);
  fishesCSS.insertRule(fishPartsRule, 0);
  triggerDelayedRedraw();
}

function triggerDelayedRedraw() {
  setTimeout(() => {
    document.getElementById("tankobj").getSVGDocument().getElementById("tank").style.display = "flex";
    console.log("first timeout");
  }, 500);
  setTimeout(() => {
    document.getElementById("tankobj").getSVGDocument().getElementById("tank").style.display = "";
    console.log("second timeout");
  }, 1000);
}

function removeAllFishesFromTank() {
  var tank = document.getElementById("tankobj").getSVGDocument().getElementById("tank");
  var children = tank.children;
  for (var childIndex = children.length - 1; childIndex > -1; childIndex--) {
    if (children[childIndex].classList.contains("fish")) {
      tank.removeChild(children[childIndex]);
    }
  }
}


async function authenticateViaII() {
  const authClient = await AuthClient.create();
  authClient.login({
    onSuccess: async () => {
      // authClient now has an identity
      const identity = authClient.getIdentity();

      /*const idlFactory = ({ IDL }) =>
      IDL.Service({
        whoami: IDL.Func([], [IDL.Principal], []),
        mint : IDL.Func([], [IDL.Nat], []),
      });*/

      const canisterId = authClient.getIdentity().getPrincipal();
      console.log(canisterId);
      const actor = Actor.createActor(idlFactory, {
        agent: new HttpAgent({
          identity,
        }),
        canisterId,
      });

      actor.mint();
    },
  });
}

setTimeout(nextRandClick, 500);