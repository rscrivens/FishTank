import { idlFactory, FishTank, canisterId, ErrorCode } from "../../declarations/FishTank";
import { Principal } from "@dfinity/principal";
import { Identity } from "@dfinity/identity";
import { getAccountIdentifier, sleep } from './utils';
import * as iiAuth from './iiAuthentication';

// Login and authentication **************************************************************
iiAuth.init();

var curMenuState = "logout";

var user;
var userPrincipalId;
var userIsAdmin;
var userDisplayTank;
var userDisplayFish = [];
var userHasGoldfish = false;
var userStorageTank;

var storageSortAsc = true;

var tankOnDisplay;
var fishOnDisplay;
var goldfishOnDisplay;

var infoCols = [
  { name: "favorite", label: "★", private: true },
  { name: "id", label: "Id", private: false },
  { name: "name", label: "Name", private: true },
  { name: "level", label: "Level", private: false },
  { name: "eye_color", label: "Eyes", private: false },
  { name: "color_1", label: "Body", private: false },
  { name: "color_2", label: "Accent", private: false },
  { name: "color_3", label: "Fins", private: false },
  { name: "speed", label: "Speed", private: false },
  { name: "size", label: "Size", private: false },
  { name: "hat", label: "Hat", private: false },
  { name: "displayed", label: "Displayed", private: true },
  { name: "staked", label: "Staked", private: true },
  { name: "donate", label: "Donate!", private: true }
];

const hiddenClass = "hidden";
const bootcamp_canister = "yeeiw-3qaaa-aaaah-qcvmq-cai";
const backend_canister = canisterId; // "qo6ef-eaaaa-aaaai-abyyq-cai";
const canisterAccount = "4f02cf4e2896917db36daaf2ce12d1f8b47a3a644390f7851f83afcc99e954b3"
const walletAccount = "d85524dfcc255904b679494220f14d5f64dde746224a0834896cc00db95f4e99";

document.getElementById("testnetbannerclose").addEventListener("click", (e) => {
  document.getElementById("testnetbanner").classList.add("hidden");
});

document.getElementById("navdropbtn").addEventListener("click", (e) => {
  document.getElementById("navdropdown").classList.toggle("hidden");
});

function setupMenu() {
  var links = document.getElementById("navdropdown").children
  for (let i = 0; i < links.length; i++) {
    links[i].addEventListener("click", menuLinkClicked);
  }
}
setupMenu();

BigInt.prototype.toJSON = function () { return Number(this); }
document.getElementById("exportbackupbtn").addEventListener("click", exportBackup);
document.getElementById("importbackupbtn").addEventListener("click", importBackup);

const tradegfbtn = document.getElementById("tradegoldfish");
const mintbtn = document.getElementById("mint");
const nextrandbtn = document.getElementById("nextrandom");

tradegfbtn.addEventListener("click", tradeGfClick);
mintbtn.addEventListener("click", mintClick);
nextrandbtn.addEventListener("click", nextRandClick);

async function menuLinkClicked(e) {
  e.preventDefault();
  // Load the clicked links data
  document.getElementById("navdropdown").classList.add("hidden");
  document.getElementById("navdropdown").classList.remove("random", "display", "storage", "login", "logout", "about", "admin");

  let newState = e.target.href.split("#")[1];
  if ((newState === "about" || newState === "random") && user === undefined) {
    document.getElementById("navdropdown").classList.add("logout");
  } else {
    document.getElementById("navdropdown").classList.add(newState);
  }

  hideActionPlusSections();

  switch (newState) {
    case "random":
      loadRandomTank();
      showSection("random");
      break;
    case "login":
    case "storage":
      await loadDisplayTank();
      await getStorageTank();
      loadStorageInfo();
      showSection("storage");
      break;
    case "display":
      await loadDisplayTank();
      loadUserInfo();
      showSection("display");
      showSection("accountinfo");
      break;
    case "logout":
      logout();
      loadRandomTank();
      showSection("random");
      break;
    case "about":
      showSection("about");
      break;
    case "admin":
      loadAdminPage();
      showSection("admin");
      break;
  }

  return false;
}

function hideActionPlusSections() {
  var actionSections = document.getElementsByClassName("actionssection");
  var infoSections = document.getElementsByClassName("infosection");
  var sections = Array.from(actionSections).concat(Array.from(infoSections));

  for (let i = 0; i < sections.length; i++) {
    sections[i].classList.add("hidden");
  }
}

function showSection(section) {
  document.getElementById(section + "section").classList.remove("hidden");
}

async function loadUserInfo() {
  document.getElementById("displayCount").innerText = userDisplayFish.length;
  document.getElementById("storageCount").innerText = user.fish.length - userDisplayFish.length;
  document.getElementById("tankAccCount").innerText = user.tank_accs.length;
  document.getElementById("fishHatUnlocksCount").innerText = user.fish_hats.length;
  document.getElementById("principalId").innerText = userPrincipalId;
  document.getElementById("loginStreak").innerText = user.login_streak;
  document.getElementById("createdDate").innerText = formatDate(user.created_date);
}

async function loadStorageInfo() {
  let tablesection = document.getElementById("storagetablesection");
  // remove all children
  while (tablesection.hasChildNodes()) {
    tablesection.removeChild(tablesection.childNodes[0]);
  }

  if (userDisplayTank !== undefined) {
    // Build header
    var headerrow = createHeaderInfoRow(true);
    tablesection.appendChild(headerrow);

    // Build rows
    for (let rindex = 0; rindex < userStorageTank.fish.length; rindex++) {
      var row = createInfoRow(userStorageTank.fish[rindex], userStorageTank.fishMD[rindex], true);
      tablesection.appendChild(row);
    }
  }
}

function createHeaderInfoRow(includePrivate) {
  var headerrow = document.createElement("div");
  headerrow.classList.add("storageheaderrow");
  for (let hcindex = 0; hcindex < infoCols.length; hcindex++) {
    if (!infoCols[hcindex].private || includePrivate) {
      var headcell = document.createElement("label");
      headcell.innerText = infoCols[hcindex].label;
      headcell.classList.add("storagecell");
      headcell.dataset.colname = infoCols[hcindex].name;
      switch (infoCols[hcindex].name) {
        case "favorite":
          headcell.classList.add("togglefavorite");
          break;
        case "color_1":
        case "color_2":
        case "color_3":
        case "eye_color":
        case "displayed":
        case "staked":
          headcell.style.textAlign = "center";
          break;
      }
      headcell.addEventListener("click", sortStorage);
      headerrow.appendChild(headcell);
    }
  }

  return headerrow;
}

function createInfoRow(fishId, fishMD, includePrivate) {
  let row = document.createElement("div");
  row.classList.add("storagerow");
  row.dataset.fishid = fishId;

  for (let rcindex = 0; rcindex < infoCols.length; rcindex++) {
    if (!infoCols[rcindex].private || includePrivate) {
      var rowcell = document.createElement("label");
      rowcell.classList.add("storagecell");
      let prop = infoCols[rcindex].name;
      rowcell.id = prop + "_" + fishId;

      switch (prop) {
        case "id":
          let id = fishId;
          rowcell.innerText = id;

          rowcell.dataset.sortval = id;
          break;
        case "favorite":
          let btn = document.createElement("button");
          btn.classList.add("togglefavorite");
          btn.addEventListener("click", favoriteClick);
          updateFavoriteButton(btn, fishMD.favorite);
          rowcell.appendChild(btn);

          rowcell.dataset.sortval = fishMD.favorite;
          break;
        case "displayed":
          let dCheckbox = document.createElement("input");
          dCheckbox.type = "checkbox";
          if (userStorageTank.inDisplay.indexOf(fishId) !== -1) {
            dCheckbox.checked = true;
          }
          dCheckbox.addEventListener("click", toggleDisplayTank);
          rowcell.appendChild(dCheckbox);
          rowcell.style.textAlign = "center";

          rowcell.dataset.sortval = dCheckbox.checked;
          break;
        case "staked":
          let sCheckbox = document.createElement("input");
          sCheckbox.type = "checkbox";
          if (userStorageTank.inStaking.indexOf(fishId) !== -1) {
            sCheckbox.checked = true;
          }
          // sCheckbox.addEventListener("click", toggleStakingTank);
          sCheckbox.disabled = true;
          rowcell.appendChild(sCheckbox);
          rowcell.style.textAlign = "center";

          rowcell.dataset.sortval = sCheckbox.checked;
          break;
        case "color_1":
        case "color_2":
        case "color_3":
        case "eye_color":
          let color = fishMD.properties[prop];

          let box = document.createElement("label");
          box.style.backgroundColor = color;
          box.title = color;
          box.classList.add("color-box");

          rowcell.style.textAlign = "center";

          rowcell.appendChild(box);

          rowcell.dataset.sortval = color;
          break;
        case "donate":
          let donatebtn = document.createElement("button");
          if (fishMD.soul_bound == false) {
            donatebtn.innerText = infoCols[rcindex].label;
            donatebtn.title = "Donate fish with id " + fishId;
            if (fishMD.favorite === true) {
              donatebtn.disabled = true;
              donatebtn.title = "Unfavorite fish if you want to donate";
            }
            donatebtn.addEventListener("click", donateClick);
            rowcell.dataset.sortval = donatebtn.disabled;

          } else {
            donatebtn.innerText = "Soul Bound";
            donatebtn.title = "Fish is Soul Bound";
            donatebtn.disabled = true;
            rowcell.dataset.sortval = "soulbound";
          }

          rowcell.appendChild(donatebtn);
          break;
        case "speed":
          let speed = fishMD.properties[prop];
          speed = convertSpeed(speed);
          rowcell.innerText = speed.label;

          rowcell.dataset.sortval = speed.label;
          break;
        case "size":
          let size = fishMD.properties[prop];
          size = convertSize(size);
          rowcell.innerText = size.label;

          rowcell.dataset.sortval = size.label;
          break;
        case "hat":
          let hat = fishMD.properties[prop];
          hat = convertHat(hat);

          // generate dropdown of unlocked hats for this fish
          var hatsDropdown = generateHatsDropList(fishMD.unlocked_hats, hat);
          if (includePrivate) {
            hatsDropdown.addEventListener("change", setFishHat);
          }
          rowcell.appendChild(hatsDropdown);
          // Unlock button to open a dialog for unlocking new hats for this fish

          rowcell.dataset.sortval = hat.label;

          if (includePrivate) {
            var editbtn = document.createElement("button");
            editbtn.classList.add("editbtn");
            editbtn.innerText = "🔓";
            editbtn.title = "Click to unlock hats";
            editbtn.addEventListener("click", unlockHatClicked);
            rowcell.appendChild(editbtn);
          }
          break;
        default:
          let label = fishMD[prop];
          if (label === undefined) {
            label = fishMD.properties[prop];
          }
          rowcell.innerText = label;

          rowcell.dataset.sortval = label;
      }

      row.appendChild(rowcell);
    }
  }

  return row;
}

function generateHatsDropList(unlocked_hats, curHat) {
  var select = document.createElement("select");
  select.classList.add("hatsdropdown");
  for (let i = 0; i < unlocked_hats.length; i++) {
    let opt = document.createElement("option");
    let uhat = convertHat(unlocked_hats[i]);
    opt.value = uhat.value;
    opt.innerText = uhat.label;
    if (uhat.value === curHat.value) {
      opt.selected = true;
    }
    select.appendChild(opt);
  }

  return select;
}

async function setFishHat(e) {
  e.target.disabled = true;
  var fishId = BigInt(e.target.parentElement.id.split("_")[1]);

  var serverHat = convertHatValToServer(e.target.value);
  const actor = await iiAuth.getActor();
  var results = await actor.setFishHat(fishId, serverHat);
  if (results.ok !== undefined) {
    console.log(results.ok.properties.hat);
    console.log("hat set");
    var hatVal = convertHat(results.ok.properties.hat).value;
    loadFishHat(fishId, hatVal);
    e.target.parentElement.dataset.sortval = hatVal;
    syncFishMD(fishId, results.ok);
  }

  e.target.disabled = false;
}

function convertSpeed(speed) {
  var label = "Average";
  var value = 1;
  if (speed.SLOW === null) {
    label = "Slow";
    value = 1.2;
  } else if (speed.FAST === null) {
    label = "Fast";
    value = .8;
  }
  return { label: label, value: value };
}

function convertSize(size) {
  var label = "Average";
  var value = 1;
  if (size.SMALL === null) {
    label = "Small";
    value = .75;
  } else if (size.LARGE === null) {
    label = "Large";
    value = 1.25;
  }
  return { label: label, value: value };
}

function convertHat(hat) {
  var label = "None";
  var value = "";
  if (hat.STRAW === null) {
    label = "Straw";
    value = "straw_hat";
  } else if (hat.PARTY === null) {
    label = "Party";
    value = "party_hat";
  }
  return { label: label, value: value };
}

function convertHatValToServer(hat) {
  var serverHat = {};
  if (hat === "") {
    serverHat.NONE = null;
  } else if (hat === "straw_hat") {
    serverHat.STRAW = null;
  } else if (hat === "party_hat") {
    serverHat.PARTY = null;
  }

  return serverHat;
}

function sortStorage(e) {
  if (e.target.classList.contains("sortdsc") === true) {
    storageSortAsc = true;
    e.target.classList.replace("sortdsc", "sortasc");
  } else if (e.target.classList.contains("sortasc") === true) {
    storageSortAsc = false;
    e.target.classList.replace("sortasc", "sortdsc");
  } else {
    // remove class from previous col
    var prevsort = document.getElementsByClassName("sortdsc");
    while (prevsort.length > 0) { prevsort[0].classList.remove("sortdsc"); }

    prevsort = document.getElementsByClassName("sortasc");
    while (prevsort.length > 0) { prevsort[0].classList.remove("sortasc"); }

    // add new sort col
    storageSortAsc = true;
    e.target.classList.add("sortasc");
  }

  var colName = e.target.dataset.colname;
  var colIndex = infoCols.findIndex((value) => {
    return value.name === colName;
  });

  // perform sort of html elements
  var rows = Array.from(document.getElementsByClassName("storagerow"));
  var sortedRows = rows.sort((a, b) => {
    let aSortVal = a.children[colIndex].dataset.sortval;
    let bSortVal = b.children[colIndex].dataset.sortval;

    let numVal = Number(aSortVal);
    if (!isNaN(numVal)) {
      aSortVal = numVal;
    }
    numVal = Number(bSortVal);
    if (!isNaN(numVal)) {
      bSortVal = numVal;
    }

    if (storageSortAsc === true) {
      if (aSortVal > bSortVal) {
        return 1;
      } else if (aSortVal < bSortVal) {
        return -1;
      } else {
        return 0;
      }
    } else {
      if (aSortVal < bSortVal) {
        return 1;
      } else if (aSortVal > bSortVal) {
        return -1;
      } else {
        return 0;
      }
    }
  });

  var tablesection = document.getElementById("storagetablesection")
  for (var index = 0; index < rows.length; index++) {
    tablesection.removeChild(rows[index]);
  }

  for (var index = 0; index < sortedRows.length; index++) {
    tablesection.appendChild(sortedRows[index]);
  }
}

async function unlockHatClicked(e) {
  var fishId = BigInt(e.target.parentElement.id.split("_")[1]);
  console.log("trying to edit: " + fishId);
  var content = document.getElementById("unlockhatcontent");
  while (content.hasChildNodes()) {
    content.removeChild(content.children[0]);
  }

  var title = document.createElement("p");
  title.innerText = `Unlock Hats for Fish ${fishId}`;
  content.appendChild(title);

  var select = document.createElement("select");
  select.id = "unlockselection";
  var party_hats = 0;
  var straw_hats = 0;
  for (var i = 0; i < user.fish_hats.length; i++) {
    if (user.fish_hats[i].PARTY === null) {
      party_hats++;
    } else if (user.fish_hats[i].STRAW === null) {
      straw_hats++;
    }
  }

  var party_is_locked = true;
  var straw_is_locked = true;
  var unlocked_hats = userStorageTank.fishMD[userStorageTank.fish.indexOf(fishId)].unlocked_hats;
  for (var i = 0; i < unlocked_hats.length; i++) {
    if (unlocked_hats[i].PARTY === null) {
      party_is_locked = false;
    } else if (unlocked_hats[i].STRAW === null) {
      straw_is_locked = false;
    }
  }

  if (party_is_locked == true && party_hats > 0) {
    var opt = document.createElement("option");
    opt.value = "party_hat";
    opt.innerText = `Party Hat (${party_hats})`;
    select.appendChild(opt);
  }

  if (straw_is_locked == true && straw_hats > 0) {
    var opt = document.createElement("option");
    opt.value = "straw_hat";
    opt.innerText = `Straw Hat (${straw_hats})`;
    select.appendChild(opt);
  }

  var button = document.createElement("button");
  button.innerText = "Unlock!";
  button.dataset.fishid = fishId;
  button.addEventListener("click", unlockHat);

  if (select.children.length == 0) {
    var opt = document.createElement("option");
    opt.value = "";
    opt.innerText = `None Available`;
    select.appendChild(opt);
    button.disabled = true;
  }
  content.appendChild(select);

  content.appendChild(button);

  var cancelbutton = document.createElement("button");
  cancelbutton.innerText = "Cancel";
  cancelbutton.addEventListener("click", (e) => {
    document.getElementById("unlockhatmodal").classList.remove("showmodal");
  });
  content.appendChild(cancelbutton);

  var msg = document.createElement("p");
  msg.innerText = "Donate fish to get rewarded with new hat unlocks";
  content.appendChild(msg);

  document.getElementById("unlockhatmodal").classList.add("showmodal");
}

async function unlockHat(e) {
  var fishId = BigInt(e.target.dataset.fishid);
  var hat = document.getElementById("unlockselection").value;
  if (hat !== "") {
    hat = convertHatValToServer(hat);
    const actor = await iiAuth.getActor();
    var results = await actor.unlockHatOnFish(fishId, hat);
    if (results.ok !== undefined) {
      var hatselector = document.getElementById("hat_" + fishId).firstChild;
      var opt = document.createElement("option");
      hat = convertHat(hat);
      opt.value = hat.value;
      opt.innerText = hat.label;
      hatselector.appendChild(opt);
    } else {
      console.log("error trying to unlock hat");
    }
  }
  document.getElementById("unlockhatmodal").classList.remove("showmodal");
}

async function toggleDisplayTank(e) {
  e.target.disabled = true;

  var fishId = BigInt(e.target.parentElement.id.split("_")[1]);
  const actor = await iiAuth.getActor();
  var results = await actor.toggleInDisplayTank(fishId);
  if (results.ok !== undefined) {
    addRemoveFromTankOnDisplay(results.ok, fishId);
  } else {
    console.log("failed: " + results.err);
    e.target.checked = !e.target.checked;
  }

  e.target.parentElement.dataset.sortval = e.target.checked;

  e.target.disabled = false;
}

function addRemoveFromTankOnDisplay(addToTank, fishId) {
  if (addToTank === true) {
    // Add to Display
    userDisplayTank.fish.push(fishId);
    var arrIndex = userStorageTank.fish.indexOf(fishId);
    userDisplayFish.push(userStorageTank.fishMD[arrIndex]);
    loadFish(fishId, userStorageTank.fishMD[arrIndex].properties);
    // Remove from staking in future update
  } else {
    // Remove from Display
    let fishIndex = userDisplayTank.fish.indexOf(fishId);
    userDisplayTank.fish.splice(fishIndex, 1);
    userDisplayFish.splice(fishIndex, 1);
    removeFishFromTank(fishId);
  }

  tankOnDisplay = userDisplayTank;
  fishOnDisplay = userDisplayFish;
}

function syncFishMD(fishId, fishMD) {
  var fishIndex = userDisplayTank.fish.indexOf(fishId);
  if (fishIndex !== -1) {
    userDisplayFish[fishIndex] = fishMD;
  }

  fishIndex = tankOnDisplay.fish.indexOf(fishId);
  if (fishIndex !== -1) {
    fishOnDisplay[fishIndex] = fishMD;
  }

  fishIndex = userStorageTank.fish.indexOf(fishId);
  if (fishIndex !== -1) {
    userStorageTank.fishMD[fishIndex] = fishMD;
  }

}

async function login() {
  if (!(await iiAuth.isAuthenticated())) {
    await iiAuth.authenticate();
  }

  const actor = await iiAuth.getActor();
  var results = await actor.login();
  if (results.err && results.err.NOUSERFOUND === null) {
    results = await actor.createNewUser();
  }

  if (results.ok) {
    user = results.ok.user_info;
    userPrincipalId = results.ok.principalId;

    userDisplayTank = results.ok.display_tank;
    userDisplayFish = results.ok.display_fish;
    userHasGoldfish = results.ok.has_goldfish;
    if (userHasGoldfish) {
      document.getElementById("tradegoldfish").classList.remove("hidden");
    }

    userIsAdmin = results.ok.is_admin;
    if (userIsAdmin) {
      document.getElementById("navdropdown").classList.add("isAdmin");
    } else {
      document.getElementById("navdropdown").classList.remove("isAdmin");
    }
  }
}

async function logout() {
  user = undefined;
  userPrincipalId = undefined;
  userDisplayFish = undefined;
  userDisplayFish = [];
  userHasGoldfish = false;
  userIsAdmin = false;
  document.getElementById("navdropdown").classList.remove("isAdmin");

  await iiAuth.logout();
}

async function loadAdminPage() {
  // show admin panel
}

async function loadDisplayTank() {
  if (user === undefined) {
    await login();
  }

  tankOnDisplay = userDisplayTank;
  fishOnDisplay = userDisplayFish;
  goldfishOnDisplay = userHasGoldfish;
  reloadTankOnDisplay();
}

async function loadRandomTank() {
  var results = await FishTank.getRandomTank();
  if (results.ok) {
    tankOnDisplay = results.ok.tank;
    fishOnDisplay = results.ok.fish;
    goldfishOnDisplay = results.ok.has_goldfish;
    reloadTankOnDisplay();
  }
}

async function getStorageTank() {
  if (user === undefined) {
    await login();
  }

  let actor = await iiAuth.getActor();
  let result = await actor.getStorageTank(user.id);
  if (result.ok != undefined) {
    userStorageTank = result.ok;
  } else {
    console.log("Could not retrieve Storage tank");
  }
}

function reloadTankOnDisplay() {
  updateTankProperties();

  removeAllFishesFromTank();
  for (var i = 0; i < fishOnDisplay.length; i++) {
    loadFish(tankOnDisplay.fish[i], fishOnDisplay[i].properties);
  }

  if (goldfishOnDisplay) {
    loadGoldfish();
  }
}

function updateTankProperties() {
  var tank = document.getElementById("tankobj").getSVGDocument().getElementById("tank");
  tank.getElementById("water3-gradient").children[1].setAttribute("stop-color", tankOnDisplay.color_bottom);
}

function showTutorial() {
  //document.get
}

async function tradeGfClick(e) {
  tradegfbtn.disabled = true;
  tradegfbtn.innerText = "Trading...";
  const actor = await iiAuth.getActor();
  var claimResult = await actor.tradeGoldfish();
  if (claimResult.ok) {
    console.log(claimResult);
    var tankobj = document.getElementById("tankobj").getSVGDocument();
    tankobj.getElementById("tank").removeChild(tankobj.getElementById("goldfish"));
    loadFish(claimResult.ok.fishId, claimResult.ok.metadata.properties);
    userHasGoldfish = false;
    tradegfbtn.innerText = "Trade Complete";
    await getStorageTank();
    loadStorageInfo();
  } else {
    tradegfbtn.innerText = "Trade failed";
    setTimeout(() => {
      tradegfbtn.innerText = "Trade in!";
      tradegfbtn.disabled = false;
    }, 500);
  }
}

async function donateClick(e) {
  e.target.disabled = true;
  let fishId = e.target.parentElement.id.split("_")[1];
  let actor = await iiAuth.getActor();
  let result = await actor.donateFish(BigInt(fishId));
  if (result.ok) {
    if (document.getElementById("displayed_" + fishId).firstChild.checked) {
      addRemoveFromTankOnDisplay(false, fishId);
    }
    var fishrow = document.getElementById("id_" + fishId).parentElement;
    fishrow.parentElement.removeChild(fishrow);
    var fishIndex = userStorageTank.fish.indexOf(fishId);
    userStorageTank.fish.splice(fishIndex, 1);
    userStorageTank.fishMD.splice(fishIndex, 1);
  } else {
    console.log("error" + result.err);
    e.target.disabled = false;
  }
}

async function favoriteClick(e) {
  let origstate = updateFavoriteButton(e.target, undefined);
  let fishId = BigInt(e.target.parentElement.id.split("_")[1]);

  let actor = await iiAuth.getActor();
  let result = await actor.toggleFavorite(fishId);

  if (result.ok != undefined) {
    updateFavoriteButton(e.target, result.ok);
    updateFavoriteInTank(fishId, result.ok);
    updateFavoriteRelatedButtons(fishId, result.ok);
    e.target.parentElement.dataset.sortval = result.ok;
  } else {
    console.log("toggle favorite failed");
    updateFavoriteButton(e.target, origstate);
  }
}

function updateFavoriteInTank(fishid, isFavorite) {
  let fishInTankIndex = userDisplayTank.fish.indexOf(fishid);
  if (fishInTankIndex !== -1) {
    userDisplayFish[fishInTankIndex].favorite = isFavorite;
    fishInTankIndex = tankOnDisplay.fish.indexOf(fishid);
    if (fishInTankIndex !== -1) {
      fishOnDisplay[fishInTankIndex].favorite = isFavorite;
    }
  } else {
    fishInTankIndex = userStorageTank.fish.indexOf(fishid);
    userStorageTank.fishMD[fishInTankIndex].favorite = isFavorite;
  }
}

function updateFavoriteButton(btn, state) {
  if (state === true) {
    btn.innerText = "★";
    btn.title = "Click to unfavorite";
    btn.disabled = false;
  } else if (state === false) {
    btn.innerText = "☆";
    btn.title = "Click to favorite";
    btn.disabled = false;
  } else {
    btn.innerText = "...";
    btn.title = "Changing favorite...";
    btn.disabled = true;
  }
}

function updateFavoriteRelatedButtons(fishId, state) {
  var donateBtn = document.getElementById("donate_" + fishId).firstChild;
  if (donateBtn.parentElement.dataset.sortval !== "soulbound") {
    donateBtn.disabled = state;
    if (state === true) {
      donateBtn.title = "Unfavorite fish if you want to donate";
    } else {
      donateBtn.title = "Donate fish with id " + fishId;
    }
  }
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

    var mintResult = await actor.mint();
    if (mintResult.ok) {
      mintbtn.innerText = "Congrats on new Fish!";
      var fishId = mintResult.ok.fishId;
      var metadata = mintResult.ok.metadata;
      user.fish.push(fishId);
      userDisplayTank.fish.push(fishId);
      userDisplayFish.push(metadata);
      tankOnDisplay.fish.push(fishId);
      fishOnDisplay.push(metadata);
      var fishsvg = loadFish(fishId, metadata.properties);

      // load the new fish row, add to the top of the storage info list
      userStorageTank.fish.push(fishId);
      userStorageTank.fishMD.push(metadata);
      userStorageTank.inDisplay.push(fishId);
      var newRow = createInfoRow(fishId, metadata, true);
      newRow.classList.add("newstoragerow");
      var firstRow = document.querySelectorAll("#storagetablesection .storagerow")[0]
      firstRow.parentNode.insertBefore(newRow, firstRow);

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
    document.getElementById("selectedfishsection").classList.add("hidden");
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
    } else {
      tradegfbtn.classList.add("hidden");
    }

    // Show the fish info
    var fishid = fishsvg.id;
    if (fishid !== "goldfish") {
      let table = document.getElementById("selectedtablesection");
      while (table.hasChildNodes()) {
        table.removeChild(table.childNodes[0]);
      }
      fishid = BigInt(fishid.replace("fish_", ""));
      var fishdata = fishOnDisplay[tankOnDisplay.fish.indexOf(fishid)];
      table.appendChild(createHeaderInfoRow(false));
      table.appendChild(createInfoRow(fishid, fishdata, false));

      document.getElementById("selectedfishsection").classList.remove("hidden");
    }
  }
}

function formatDate(serverDate) {
  let dateObj = new Date(Number(serverDate / 1000000n));
  let formatedDate = new Intl.DateTimeFormat('en',
    {
      day: '2-digit',
      month: 'short',
      year: 'numeric'
    }).format(dateObj);

  return formatedDate;
}

function createFishInfoEle(eleId, label, value, eleClass) {
  var wrapper = document.createElement("p");
  var valueText = document.createElement("text");
  wrapper.innerText = label;
  valueText.innerText = value;
  wrapper.appendChild(valueText);
  if (eleClass !== "") {
    wrapper.classList.add(eleClass);
  }
  wrapper.id = "fishinfo" + eleId;

  return wrapper;
}

function createFishInfoColorEle(eleId, label, value, eleClass) {
  /*<p>Color #1:
  <label id="fishcolor1box" class="color-box"></label>
  <text id="fishcolor1text" class="color-box-label"></text>
   </p>*/
  var wrapper = document.createElement("p");
  var box = document.createElement("label");
  var valueText = document.createElement("text");

  wrapper.innerText = label;
  if (eleClass !== "") {
    wrapper.classList.add(eleClass);
  }
  wrapper.id = "fishinfocolor" + eleId;

  box.style.backgroundColor = value;
  box.classList.add("color-box");
  box.id = "fishinfocolor" + eleId + "box";

  valueText.innerText = value;
  valueText.classList.add("color-box-text");
  valueText.id = "fishinfocolor" + eleId + "text";

  wrapper.appendChild(box);
  wrapper.appendChild(valueText);

  return wrapper;
}

function loadFish(fishId, properties) {
  var fishesCSS = document.getElementById("tankobj").getSVGDocument().getElementById('fishes').sheet;
  var tank = document.getElementById("tankobj").getSVGDocument().getElementById("tank");
  var basefish = document.getElementById("basefishobj").getSVGDocument().getElementById("base_fish");
  let fish = basefish.cloneNode(true);

  let animationDelay = Math.random() * 5;
  let animationTime = convertSpeed(properties.speed).value * 37.5;
  let y = 0;
  while (y < .1 || y > .9) {
    y = Math.random();
  }
  y = y * 1080;

  let size = convertSize(properties.size);

  let fishPrefix = "fish_" + fishId;
  var innerhtml = fish.innerHTML;
  innerhtml = innerhtml.replaceAll("fill: eye_color;", `fill: ${properties.eye_color};`);
  innerhtml = innerhtml.replaceAll("animation-duration: 30s;", `animation-duration: ${animationTime}s;`);
  innerhtml = innerhtml.replaceAll("animation-delay: 0s;", `animation-delay: ${animationDelay}s;`);
  innerhtml = innerhtml.replaceAll("translateY(1000000px)", `translateY(${y}px)`);
  innerhtml = innerhtml.replaceAll("scale(.15)", `scale(${.15 * size.value})`);
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

  var startXPos;
  switch (size.label) {
    case "Small":
      startXPos = -9.75;
      break;
    case "Large":
      startXPos = -16.25;
      break;
    default:
      startXPos = -13;
  }

  let fishPartsRule = `#${fishPrefix} > g {
          transform: translateY(${y}px) translateX(${startXPos}%) scale(${.15 * size.value});
      }`;

  fishesCSS.insertRule(fishBGRule, 0);
  fishesCSS.insertRule(fishPartsRule, 0);
  //triggerDelayedRedraw();


  loadFishHat(fishId, convertHat(properties.hat).value);

  return fish;
}

function loadFishHat(fishId, hatVal) {
  var fish = document.getElementById("tankobj").getSVGDocument().getElementById("fish_" + fishId);
  fish.classList.remove("party_hat", "straw_hat");
  if (hatVal !== "") {
    fish.classList.add(hatVal);
  }
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

function removeFishFromTank(fishId) {
  var tank = document.getElementById("tankobj").getSVGDocument().getElementById("tank");
  var fish = document.getElementById("tankobj").getSVGDocument().getElementById("fish_" + fishId);
  tank.removeChild(fish);
}

//setTimeout(nextRandClick, 500);

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

async function importBackup(e) {
  var importtext = document.getElementById("importbackuptext").value;
  var importjson = JSON.parse(importtext);
  const actor = await iiAuth.getActor();
  var result = await actor.importBackup(importjson);
  /*if (result.ok) {
    showInfoMsg(result.ok);
  } else {
    showErrorMsg(result.err);
  }*/

  document.getElementById("importbackuptext").value = "";
}

async function exportBackup(e) {
  const actor = await iiAuth.getActor();
  var result = await actor.exportBackup();
  document.getElementById("exportbackuptext").value = JSON.stringify(result.ok);
}
// End Admin Tasks ------------------------------------------------------------------------------------------


// After loading page pull in a random tank
loadRandomTank();