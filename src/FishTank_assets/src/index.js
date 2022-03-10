import { FishTank } from "../../declarations/FishTank";
import { Principal } from "@dfinity/principal";

document.querySelector("form").addEventListener("submit", async (e) => {
  e.preventDefault();
  const button = e.target.querySelector("button");

  button.setAttribute("disabled", true);

  const mintId = await FishTank.mint();

  button.removeAttribute("disabled");

  document.getElementById("nftid").innerText = mintId;

  const nftMetaData = (await FishTank.tokenMetaData(mintId))[0];

  document.getElementById("nftmetadata").innerText = `Minted at: ${nftMetaData.minted_at}
  Minted by: ${nftMetaData.minted_by}
  Color 1: ${nftMetaData.properties.color_1}
  Color 2: ${nftMetaData.properties.color_2}`;

  loadFish(mintId, nftMetaData.properties);

  return false;
});

function loadFish(fishId, properties) {
  var fishesCSS = document.getElementById("tankobj").getSVGDocument().getElementById('fishes').sheet;
  var tank = document.getElementById("tankobj").getSVGDocument().getElementById("tank");
  var basefish = document.getElementById("basefishobj").getSVGDocument().getElementById("base_fish");
  let fish = basefish.cloneNode(true);
  let fishPrefix = "fish_" + fishId;
  fish.innerHTML = fish.innerHTML.replaceAll("base_fish", fishPrefix);
  fish.id = fishPrefix;
  fish.getElementById(fishPrefix + "_linear-gradient").children[0].setAttribute("stop-color",properties.color_1)
  fish.getElementById(fishPrefix + "_linear-gradient").children[2].setAttribute("stop-color",properties.color_2)
  let fishBGRule = `#${fishPrefix} g:first-of-type rect{
          fill: transparent;
      }`;
  let x = 0;
  while (x < .1 || x > .9) {
    x = Math.random();
  }
  x = x * 1920;

  let y = 0;
  while (y < .1 || y > .9) {
    y = Math.random();
  }
  y = y * 1080;

  let fishPartsRule = `#${fishPrefix} g {
          transform: translateY(${y}px) translateX(${x}px) scale(${.1});
      }`;

  fishesCSS.insertRule(fishBGRule, 0);
  fishesCSS.insertRule(fishPartsRule, 0);
  tank.appendChild(fish);
}

function removeFish(mintId)
