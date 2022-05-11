import { idlFactory, FishTank, canisterId } from "../../declarations/FishTank";
import { AuthClient } from "@dfinity/auth-client";
import { Actor, ActorCallError, HttpAgent } from "@dfinity/agent";
import { Principal } from "@dfinity/principal";
import { Identity } from "@dfinity/identity";
import { getAccountIdentifier } from './utils';

import ledgerInterfaceDid from "./ledgerInterface.did";

// Login and authentication **************************************************************
var authClient;

async function create() {
  authClient = await AuthClient.create();
  await authClient?.isAuthenticated();
}

async function getIdentity() {
  return await authClient?.getIdentity();
}

async function isAuthenticated() {
  return await authClient?.isAuthenticated();
}

/**
 * Get the internet-identity identityProvider URL to use when authenticating the end-user.
 * Use ?identityProvider if present (useful in development), otherwise return undefined
 * so that AuthClient default gets used.
 * For development, open browser to :
 * `http://localhost:8080/?canisterId=<wallet_canister_id>&identityProvider=http://localhost:8000/?canisterId=<internet_identity_id>`
 */
/*
function getIdentityProvider() {
const fromUrl = new URLSearchParams(location.search).get(
  "identityProvider"
);

  return fromUrl || undefined;
}
*/
create();

document.getElementById("test").addEventListener("click", mintTest);
async function mintTest(){
  await loginTest();
  const identity = await authClient.getIdentity();
  const actor = Actor.createActor(idlFactory, {
    agent: new HttpAgent({
      identity,
      
    }),
    canisterId,
  });

  actor.mint(5);
}

// End of test ***********************************************************************

var currentProfile;
var currentTank = [];

const hiddenClass = "hidden";
const bootcamp_canister = "yeeiw-3qaaa-aaaah-qcvmq-cai";
const backend_canister = canisterId; // "qo6ef-eaaaa-aaaai-abyyq-cai";
const canisterAccount = "4f02cf4e2896917db36daaf2ce12d1f8b47a3a644390f7851f83afcc99e954b3"
const walletAccount = "d85524dfcc255904b679494220f14d5f64dde746224a0834896cc00db95f4e99";

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
const tradegfbtn = document.getElementById("tradegoldfish");
const burnbtn = document.getElementById("burn");
const mintbtn = document.getElementById("mint");
const nextrandbtn = document.getElementById("nextrand");

mytankbtn.addEventListener("click", myTankClick);
randombtn.addEventListener("click", randomTankClick);
loginbtn.addEventListener("click", loginClick);
//logoutbtn.addEventListener("click", logoutClick);
tradegfbtn.addEventListener("click", tradeGfClick);
burnbtn.addEventListener("click", burnClick);
mintbtn.addEventListener("click", mintClick);
nextrandbtn.addEventListener("click", nextRandClick);

async function myTankClick(e) {
  mytankbtn.disabled = true;

  await loadMyTank();

  mytankbtn.disabled = false;
  mytankbtn.classList.add(hiddenClass);
  randombtn.classList.remove(hiddenClass);
  nextrandbtn.classList.add(hiddenClass);
  mintbtn.classList.remove(hiddenClass);
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

async function loginClick(e) {
  loginbtn.disabled = true;

  await login();
  myTankClick();
  loginbtn.disabled = false;
  loginbtn.classList.add(hiddenClass);
  //logoutbtn.classList.remove(hiddenClass);
}

async function loadMyTank() {
  await verifyConnection();
  const actor = await window.ic.plug.createActor({
    canisterId: backend_canister,
    interfaceFactory: idlFactory,
  });

  var results = await actor.allOwnedTokens();

  currentTank = results.fish;
  refreshCurrentTank(results.hasGoldfish);
}

async function loadRandomTank() {
  var results = await FishTank.randomOwnerAll();
  currentProfile = results.profile;
  currentTank = results.fish;
  refreshCurrentTank(results.hasGoldfish);
}

function refreshCurrentTank(hasGoldfish) {
  updateTankColor(currentProfile.tank_color);
  removeAllFishesFromTank();
  for (var i = 0; i < currentTank.length; i++) {
    loadFish(currentTank[i].id, currentTank[i].metadata.properties);
  }

  if (hasGoldfish) {
    loadGoldfish();
  }
}

function updateTankColor(color) {
  var tank = document.getElementById("tankobj").getSVGDocument().getElementById("tank");
  tank.getElementById("water3-gradient").children[1].setAttribute("stop-color", color);
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
    if (result.err === "NOPROFILE") {
      result = await actor.createProfile();
      showTutorial();
    }
    currentProfile = result.ok;

    console.log(currentProfile);

    updateMyBalance();
  } else {
    console.log("Plug wallet connection was refused");
  }
}

function showTutorial() {
  //document.get
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

async function burnClick(e) {
  console.log("not yet implemented");
}

async function tradeGfClick(e) {
  tradegfbtn.disabled = true;
  await verifyConnection();
  const actor = await window.ic.plug.createActor({
    canisterId: backend_canister,
    interfaceFactory: idlFactory,
  });

  const accountId = getAccountIdentifier(window.ic.plug.principal);
  var claimResult = await actor.tradeGoldfish(accountId);
  if (claimResult.ok) {
    console.log(claimResult);
    var tankobj = document.getElementById("tankobj").getSVGDocument();
    tankobj.getElementById("tank").removeChild(tankobj.getElementById("goldfish"));
    loadFish(claimResult.ok)
    updateMyBalance();
  }

  tradegfbtn.disabled = false;
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
    to: walletAccount,//canisterAccount,
    fee: { e8s: 10000 },
    memo: 0,
    from_subaccount: [],
    created_at_time: [],
    amount: { e8s: 1000000000 }
  };

  try {
    var block_height = await faucetActor.send_dfx(sendArgs);
    mintbtn.innerText = "Minting Fish!";
    updateMyBalance();

    // Let minter know you sent funds and want a NFT minted
    const actor = await window.ic.plug.createActor({
      canisterId: backend_canister,
      interfaceFactory: idlFactory,
    });

    var mintResult = await actor.mint(block_height);
    if (mintResult.ok) {
      mintbtn.innerText = "Congrats on new Fish!";
      var fishId = mintResult.ok.id;
      currentTank.add(mintResult.ok);
      var fishsvg = loadFish(fishId, mintResult.ok.metadata.properties);

      selectFish(fishsvg);
    }
  } catch (e) {
    console.log(e);
    mintbtn.innerText = "Failed to Mint!";
  }

  setTimeout(() => { mintbtn.innerText = "Mint!"; mintbtn.disabled = false; }, 1000);
}

async function updateMyBalance() {
  await verifyConnection();
  //send funds
  const faucetActor = await window.ic.plug.createActor({
    canisterId: bootcamp_canister,
    interfaceFactory: ledgerInterfaceDid
  })
  const accountID = getAccountIdentifier(window.ic.plug.principal);
  console.log(accountID);
  const sendArgs = {
    account: accountID
  };

  var balance = await faucetActor.account_balance_dfx(sendArgs);
  document.getElementById("balance").innerText = Number(balance.e8s) / 1e8;
  console.log(balance);
}

async function nextRandClick(e) {
  nextrandbtn.disabled = true;

  await loadRandomTank();

  nextrandbtn.disabled = false;
}

function clickedOnFish(e) {
  var fishsvg = e.currentTarget.parentElement;
  console.log("clicked on: " + fishsvg.id);
  selectFish(fishsvg);
}

function selectFish(fishsvg) {
  var tanksvg = fishsvg.parentElement;

  if (fishsvg.classList.contains("selectedfish")) {
    fishsvg.classList.remove("selectedfish");
    tradegfbtn.classList.add("hidden");
    burnbtn.classList.add("hidden");
    mintbtn.classList.remove("hidden");
    document.getElementById("fishinfo").classList.add("hidden");
    //triggerDelayedRedraw();
  } else {
    var selectedfish = tanksvg.getElementsByClassName("selectedfish");
    if (selectedfish[0] !== undefined) {
      var sf = selectedfish[0];
      sf.classList.remove("selectedfish");
    }

    tanksvg.removeChild(fishsvg);
    tanksvg.appendChild(fishsvg);
    fishsvg.classList.add("selectedfish");

    // Determine which buttons should be shown
    if (fishsvg.id === "goldfish") {
      tradegfbtn.classList.remove("hidden");
      burnbtn.classList.add("hidden");
    } else {
      tradegfbtn.classList.add("hidden");
      burnbtn.classList.remove("hidden");
    }
    mintbtn.classList.add("hidden");

    // Show the fish info
    var fishid = fishsvg.id;
    if (fishid !== "goldfish") {
      fishid = fishid.replace("fish_", "");
      var fishdata = currentTank.find((value) => {
        console.log(fishid + " === " + value.id);
        return fishid === value.id;
      });
      document.getElementById("fishid").innerText = fishdata.id;
      document.getElementById("fishdate").innerText = new Date(fishdata.metadata.minted_at);
      document.getElementById("fishtradable").innerText = fishdata.metadata.transferrable;
      document.getElementById("fishcolor1").innerText = fishdata.metadata.properties.color_1;
      document.getElementById("fishcolor2").innerText = fishdata.metadata.properties.color_2;
      document.getElementById("fishcolor3").innerText = fishdata.metadata.properties.color_3;
      document.getElementById("fishinfo").classList.add("hidden");
    }
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
  fish.getElementById(fishPrefix + "_linear-gradient").children[1].setAttribute("stop-color", properties.color_3);
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
  //triggerDelayedRedraw();
  return fish;
}

function loadGoldfish() {
  var fishCSS = document.getElementById("tankobj").getSVGDocument().getElementById('fishes').sheet;
  var tank = document.getElementById("tankobj").getSVGDocument().getElementById("tank");
  var basegoldfish = document.getElementById("goldfishobj").getSVGDocument().getElementById("goldfish");
  let goldfish = basegoldfish.cloneNode(true);

  let animationDelay = Math.random() * 5;
  let animationTime = (Math.random() * 15) + 30;
  let y = 0;
  while (y < .1 || y > .9) {
    y = Math.random();
  }
  y = y * 1080;

  //let fishPrefix = "fish_" + fishId;
  var innerhtml = goldfish.innerHTML;
  innerhtml = innerhtml.replaceAll("animation-duration: 30s;", `animation-duration: ${animationTime}s;`);
  innerhtml = innerhtml.replaceAll("animation-delay: 0s;", `animation-delay: ${animationDelay}s;`);
  innerhtml = innerhtml.replaceAll("translateY(1000000px)", `translateY(${y}px)`);
  //innerhtml = innerhtml.replaceAll("base_fish", fishPrefix);
  goldfish.innerHTML = innerhtml;

  tank.appendChild(goldfish);
  //fish.id = fishPrefix;

  goldfish.getElementById("Layer_2").addEventListener("click", clickedOnFish);
  let fishPartsRule = `#goldfish g {
          transform: translateY(${y}px) translateX(-13%) scale(${.15});
      }`;

  fishCSS.insertRule(fishPartsRule, 0);
  // triggerDelayedRedraw();
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
  return new Promise(async (resolve) => {
    return await authClient?.login({
      identityProvider: undefined,// getIdentityProvider(),
      onSuccess: async () => {
        var authenticated = await isAuthenticated();
        var iden = await getIdentity();
        console.log(`isauthenticated: ${authenticated}`);
        console.log(`identity: ${iden}`);
        console.log(`principal: ${iden.toString()}`)
        //document.getElementById("login").classList.add("hidden");
        //document.getElementById("import_exportsection").classList.remove("hidden");
        resolve(await authClient?.getIdentity());
      },
    });
  });
}

setTimeout(nextRandClick, 500);

// Admin tasks ---------------------------------------------------------------------------------------------
document.getElementById("resetall").addEventListener("click", resetAll);
document.getElementById("getlogs").addEventListener("click", getLogs);

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
// End Admin Tasks ------------------------------------------------------------------------------------------