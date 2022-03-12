import { idlFactory, FishTank } from "../../declarations/FishTank";
import { AuthClient } from "@dfinity/auth-client";
import { Actor, ActorCallError, HttpAgent } from "@dfinity/agent";
import { Principal } from "@dfinity/principal";
import { Identity } from "@dfinity/identity";

import ledgerInterfaceDid from "./ledgerInterface.did";

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
const logoutbtn = document.getElementById("logout");
const mintbtn = document.getElementById("mint");
const nextrandbtn = document.getElementById("nextrand");

mytankbtn.addEventListener("click", myTankClick);
randombtn.addEventListener("click", randomTankClick);
loginbtn.addEventListener("click", loginClick);
logoutbtn.addEventListener("click", logoutClick);
mintbtn.addEventListener("click", mintClick);
nextrandbtn.addEventListener("click", nextRandClick);

//Admin tasks
document.getElementById("resetall").addEventListener("click", resetAll);
document.getElementById("getlogs").addEventListener("click", getLogs);

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
  var fishes = await actor.allOwnedTokens();
  for (var i = 0; i < fishes.length; i++) {
    loadFish(fishes[i][0], fishes[i][1].properties);
  }
}

async function randomTankClick(e) {
  randombtn.disabled = true;

  await loadRandomTank();

  randombtn.disabled = false;
  randombtn.classList.add(hiddenClass);
  mytankbtn.classList.remove(hiddenClass);
  mintbtn.classList.remove(hiddenClass);
  nextrandbtn.classList.add(hiddenClass);
}

async function loadRandomTank() {
  removeAllFishesFromTank();
  var fishes = await FishTank.randomOwnerAll();
  for (var i = 0; i < fishes.length; i++) {
    loadFish(fishes[i][0], fishes[i][1].properties);
  }
}

async function loginClick(e) {
  loginbtn.disabled = true;

  await login();

  loginbtn.disabled = false;
  loginbtn.classList.add(hiddenClass);
  mytankbtn.classList.remove(hiddenClass);
  logoutbtn.classList.remove(hiddenClass);
}

async function login() {
  const hasAllowed = await window.ic?.plug?.requestConnect({
    whitelist: [bootcamp_canister,
      backend_canister]
  });

  if (hasAllowed) {
    console.log("Plug wallet is connected");
  } else {
    console.log("Plug wallet connection was refused");
  }
}

async function logoutClick(e) {
  logoutbtn.disabled = true;

  await logout();
  await randomTankClick();
  logoutbtn.disabled = false;
}

async function logout() {
  await window.ic.plug.disconnect();
}

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
  e.target.disabled = true;

  await mint();

  e.target.disabled = false;
}

async function mint() {
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

  var block_height = await faucetActor.send_dfx(sendArgs);

  // Let minter know you sent funds and want to you NFT minted
  const actor = await window.ic.plug.createActor({
    canisterId: backend_canister,
    interfaceFactory: idlFactory,
  });

  var mintResult = await actor.mint(block_height);
  if (mintResult.ok) {
    var fishId = mintResult.ok[0];
    var fish = mintResult.ok[1];
    loadFish(fishId, fish.properties);
    document.getElementById("nftmetadata").innerText = `Minted at: ${fish.minted_at}
      Minted by: ${fish.minted_by}
      Color 1: ${fish.properties.color_1}
      Color 2: ${fish.properties.color_2}`;
  }
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

  let animationDelay = Math.random() * 8;
  let animationTime = (Math.random() * 10) + 30;
  let y = 0;
  while (y < .1 || y > .9) {
    y = Math.random();
  }
  y = y * 1080;
  
  let fishPrefix = "fish_" + fishId;
  
  fish.innerHTML = fish.innerHTML.replaceAll("--base_fish_animationtime: 30s;", `--base_fish_animationtime: ${animationTime}s;`);
  fish.innerHTML = fish.innerHTML.replaceAll("--base_fish_animationdelay: 0s;", `--base_fish_animationdelay: ${animationDelay}s;`);
  fish.innerHTML = fish.innerHTML.replaceAll("--base_fish_transY: 0px;", `--base_fish_transY: ${y}px;`);
  fish.innerHTML = fish.innerHTML.replaceAll("base_fish", fishPrefix);

  fish.id = fishPrefix;
  fish.getElementById(fishPrefix + "_linear-gradient").children[0].setAttribute("stop-color", properties.color_1);
  fish.getElementById(fishPrefix + "_linear-gradient").children[2].setAttribute("stop-color", properties.color_2);
  fish.getElementById("Layer_2").addEventListener("click", clickedOnFish);
  let fishBGRule = `#${fishPrefix} g:first-of-type rect{
          fill: transparent;
      }`;

  let fishPartsRule = `#${fishPrefix} g {
          transform: translateY(${y}px) scale(${.1}) rotateY(90deg);
      }`;

  fishesCSS.insertRule(fishBGRule, 0);
  fishesCSS.insertRule(fishPartsRule, 0);
  tank.appendChild(fish);
  triggerDelayedRedraw();
}

function triggerDelayedRedraw() {
  document.getElementById("tankobj").getSVGDocument().getElementById("tank").style.display = "none";
  setTimeout(() => {
    var tanksvg = document.getElementById("tankobj").getSVGDocument().getElementById("tank");
    tanksvg.style.display = "";
  }, 500);
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