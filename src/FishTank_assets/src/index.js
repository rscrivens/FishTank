import { idlFactory, FishTank, canisterId } from "../../declarations/FishTank";
import { Principal } from "@dfinity/principal";
import { Identity } from "@dfinity/identity";
import { getAccountIdentifier, sleep } from './utils';
import * as iiAuth from './iiAuthentication';

// Login and authentication **************************************************************
iiAuth.init();

var currentProfile;
var currentTank = [];

const hiddenClass = "hidden";
const bootcamp_canister = "yeeiw-3qaaa-aaaah-qcvmq-cai";
const backend_canister = canisterId; // "qo6ef-eaaaa-aaaai-abyyq-cai";
const canisterAccount = "4f02cf4e2896917db36daaf2ce12d1f8b47a3a644390f7851f83afcc99e954b3"
const walletAccount = "d85524dfcc255904b679494220f14d5f64dde746224a0834896cc00db95f4e99";

const mytankbtn = document.getElementById("mytank");
const randombtn = document.getElementById("getrandom");
const loginbtn = document.getElementById("login");
//const logoutbtn = document.getElementById("logout");
const tradegfbtn = document.getElementById("tradegoldfish");
const donatebtn = document.getElementById("donate");
const mintbtn = document.getElementById("mint");
const nextrandbtn = document.getElementById("nextrand");

mytankbtn.addEventListener("click", myTankClick);
randombtn.addEventListener("click", randomTankClick);
loginbtn.addEventListener("click", loginClick);
//logoutbtn.addEventListener("click", logoutClick);
tradegfbtn.addEventListener("click", tradeGfClick);
donatebtn.addEventListener("click", donateClick);
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

async function login() {
  await iiAuth.authenticate();
}

async function loadMyTank() {
  const actor = await iiAuth.getActor();

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

function showTutorial() {
  //document.get
}

async function logoutClick(e) {
  logoutbtn.disabled = true;

  await logout();
  await randomTankClick();
  logoutbtn.disabled = false;
}

async function logout() {
  await iiAuth.logout();
}

async function tradeGfClick(e) {
  tradegfbtn.disabled = true;
  const actor = await iiAuth.getActor();
  var claimResult = await actor.tradeGoldfish();
  if (claimResult.ok) {
    console.log(claimResult);
    var tankobj = document.getElementById("tankobj").getSVGDocument();
    tankobj.getElementById("tank").removeChild(tankobj.getElementById("goldfish"));
    loadFish(claimResult.ok)
    updateMyBalance();
  }

  tradegfbtn.disabled = false;
}

async function donateClick(e) {
  console.log("donate clicked");
}

async function mintClick(e) {
  mintbtn.disabled = true;

  await mint();

  setTimeout(() => { mintbtn.innerText = "Mint!"; mintbtn.disabled = false; }, 1000);
}

// need to hook up payment system later
async function mint() {
  mintbtn.innerText = "Processing Payment!";
  await sleep(2000);

  try {
    mintbtn.innerText = "Minting Fish!";
    const actor = await iiAuth.getActor();

    var mintResult = await actor.mint(0);
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
    donatebtn.classList.add("hidden");
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
      donatebtn.classList.add("hidden");
    } else {
      tradegfbtn.classList.add("hidden");
      donatebtn.classList.remove("hidden");
    }
    mintbtn.classList.add("hidden");

    // Show the fish info
    var fishid = fishsvg.id;
    if (fishid !== "goldfish") {
      fishid = fishid.replace("fish_", "");
      var fishdata = currentTank.find((value) => {
        console.log(fishid + " === " + value.id);
        return Number(fishid) === Number(value.id);
      });
      document.getElementById("fishid").innerText = fishdata.id;
      document.getElementById("fishdate").innerText = new Date(Number(fishdata.metadata.minted_at / 1000000n));
      document.getElementById("fishtradable").innerText = fishdata.metadata.transferrable;
      document.getElementById("fishcolor1text").innerText = fishdata.metadata.properties.color_1;
      document.getElementById("fishcolor1box").style.backgroundColor = fishdata.metadata.properties.color_1;
      document.getElementById("fishcolor2text").innerText = fishdata.metadata.properties.color_2;
      document.getElementById("fishcolor2box").style.backgroundColor = fishdata.metadata.properties.color_2;
      document.getElementById("fishcolor3text").innerText = fishdata.metadata.properties.color_3;
      document.getElementById("fishcolor3box").style.backgroundColor = fishdata.metadata.properties.color_3;
      document.getElementById("fishinfo").classList.remove("hidden");
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