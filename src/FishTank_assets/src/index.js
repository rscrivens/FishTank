import { FishTank } from "../../declarations/FishTank";

document.querySelector("form").addEventListener("submit", async (e) => {
  e.preventDefault();
  const button = e.target.querySelector("button");

  const uri = document.getElementById("uri").value.toString();

  button.setAttribute("disabled", true);

  const nftId = await FishTank.mint(uri);

  button.removeAttribute("disabled");

  document.getElementById("nftid").innerText = nftId;

  const nftMetaData = await FishTank.tokenMetaData(nftId);
  document.getElementById("nftmetadata").innerText = JSON.stringify(nftMetaData);

  return false;
});
