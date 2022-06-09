import { idlFactory, canisterId } from "../../declarations/FishTank";
import { Actor, HttpAgent } from "@dfinity/agent";
import { AuthClient } from "@dfinity/auth-client";

var authClient;

async function init() {
  authClient = await AuthClient.create();
  await authClient?.isAuthenticated();
}

async function getActor() {
  const isAuthed = await authClient.isAuthenticated();
  if(!isAuthed){
    await authenticate();
  }

  const identity = await authClient.getIdentity();
  const actor = Actor.createActor(idlFactory, {
    agent: new HttpAgent({
      identity,
    }),
    canisterId,
  });

  return actor;
}

async function getIdentity() {
  return await authClient?.getIdentity();
}

async function isAuthenticated() {
  return await authClient?.isAuthenticated();
}

async function authenticate() {
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

async function logout() {
  return await authClient?.logout();
}

export {
  init,
  authenticate,
  isAuthenticated,
  getActor,
  getIdentity,
  logout,
};