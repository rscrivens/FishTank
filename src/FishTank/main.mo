import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Float "mo:base/Float";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Random "mo:base/Random";
import T "dip721_types";
import Time "mo:base/Time";
import Result "mo:base/Result";

actor class DRC721(_name : Text, _symbol : Text) {
    private stable var tokenPk : Nat = 0;
    private stable var workaround : [T.TokenProps] = [];
    private stable var tokenFishEntries : [(T.TokenId, T.TokenMetadata)] = [];
    private stable var ownersEntries : [(T.TokenId, Principal)] = [];
    private stable var balancesEntries : [(Principal, Nat)] = [];
    private stable var profilesEntries : [(Principal, T.Profile)] = [];
    private stable var tokenApprovalsEntries : [(T.TokenId, Principal)] = [];
    private stable var operatorApprovalsEntries : [(Principal, [Principal])] = [];

    private let tokenFishes : HashMap.HashMap<T.TokenId, T.TokenMetadata> = HashMap.fromIter<T.TokenId, T.TokenMetadata>(tokenFishEntries.vals(), 10, Nat.equal, Hash.hash);
    private let owners : HashMap.HashMap<T.TokenId, Principal> = HashMap.fromIter<T.TokenId, Principal>(ownersEntries.vals(), 10, Nat.equal, Hash.hash);
    private let balances : HashMap.HashMap<Principal, Nat> = HashMap.fromIter<Principal, Nat>(balancesEntries.vals(), 10, Principal.equal, Principal.hash);
    private let profiles : HashMap.HashMap<Principal, T.Profile> = HashMap.fromIter<Principal, T.Profile>(profilesEntries.vals(), 10, Principal.equal, Principal.hash);
    private let tokenApprovals : HashMap.HashMap<T.TokenId, Principal> = HashMap.fromIter<T.TokenId, Principal>(tokenApprovalsEntries.vals(), 10, Nat.equal, Hash.hash);
    private let operatorApprovals : HashMap.HashMap<Principal, [Principal]> = HashMap.fromIter<Principal, [Principal]>(operatorApprovalsEntries.vals(), 10, Principal.equal, Principal.hash);
    
    private var finite : Random.Finite = Random.Finite(Blob.fromArray([]));

    private var logs : Text = "";

    public shared func balanceOf(p : Principal) : async ?Nat {
        return balances.get(p);
    };

    public shared func ownerOf(tokenId : T.TokenId) : async ?Principal {
        return _ownerOf(tokenId);
    };

    public shared query (msg) func getProfile() : async Result.Result<T.Profile,Text> {
        if(Principal.toText(msg.caller) == "2vxsx-fae") {
            return #err("NOANON");
        };

        return _getProfile(msg.caller);
    };

    public shared (msg) func createProfile() : async Result.Result<T.Profile, Text> {
        if(Principal.toText(msg.caller) == "2vxsx-fae") {
            return #err("NOANON");
        };

        return #ok(await _createProfile(msg.caller));
    };

    public shared query func tokenMetaData(tokenId : T.TokenId) : async ?T.TokenMetadata {
        return _tokenMetaData(tokenId);
    };

    public shared query (msg) func allOwnedTokens() : async [(T.TokenId, T.TokenMetadata)] {
        if(Principal.toText(msg.caller) == "2vxsx-fae") {
            return [];
        };
        return _allOwnedTokens(msg.caller);
    };

    public shared func randomOwnerAll() : async (T.Profile, [(T.TokenId, T.TokenMetadata)]) {
        return await _randomOwnerAll();
    };

    public shared query func name() : async Text {
        return _name;
    };

    public shared query func symbol() : async Text {
        return _symbol;
    };

    public shared func isApprovedForAll(owner : Principal, opperator : Principal) : async Bool {
        return _isApprovedForAll(owner, opperator);
    };

    public shared(msg) func approve(to : Principal, tokenId : T.TokenId) : async () {
        switch(_ownerOf(tokenId)) {
            case (?owner) {
                
                 assert to != owner;
                 assert msg.caller == owner or _isApprovedForAll(owner, msg.caller);
                 _approve(to, tokenId);
            };
            case (null) {
                throw Error.reject("No owner for token")
            };
        }
    };

    public shared func getApproved(tokenId : Nat) : async Principal {
        switch(_getApproved(tokenId)) {
            case (?v) { return v };
            case null { throw Error.reject("None approved")}
        }
    };

    public shared(msg) func setApprovalForAll(op : Principal, isApproved : Bool) : () {
        assert msg.caller != op;

        switch (isApproved) {
            case true {
                switch (operatorApprovals.get(msg.caller)) {
                    case (?opList) {
                        var array = Array.filter<Principal>(opList,func (p) { p != op });
                        array := Array.append<Principal>(array, [op]);
                        operatorApprovals.put(msg.caller, array);
                    };
                    case null {
                        operatorApprovals.put(msg.caller, [op]);
                    };
                };
            };
            case false {
                switch (operatorApprovals.get(msg.caller)) {
                    case (?opList) {
                        let array = Array.filter<Principal>(opList, func(p) { p != op });
                        operatorApprovals.put(msg.caller, array);
                    };
                    case null {
                        operatorApprovals.put(msg.caller, []);
                    };
                };
            };
        };
        
    };

    public shared(msg) func transferFrom(from : Principal, to : Principal, tokenId : Nat) : () {
        assert _isApprovedOrOwner(msg.caller, tokenId);

        _transfer(from, to, tokenId);
    };

    public shared(msg) func mint(block_height: Nat64) : async Result.Result<(Nat, T.TokenMetadata),Text>{
        if(Principal.toText(msg.caller) == "2vxsx-fae") {
            return #err("You need to log in to mint.");
        };

        _log("Recieved block_height: " # Nat64.toText(block_height));
        _log("Trying to mint: " # Principal.toText(msg.caller));
        return await _mint(block_height, msg.caller);
    };

    public shared query func getLogs(): async Text{
        return logs;
    };

    public shared func resetAllState(): async () {
        for(k in tokenFishes.keys()) { tokenFishes.delete(k); };
        for(k in owners.keys()) { owners.delete(k); };
        for(k in balances.keys()) { balances.delete(k); };
        for(k in profiles.keys()) { profiles.delete(k); };
        for(k in tokenApprovals.keys()) { tokenApprovals.delete(k); };
        for(k in operatorApprovals.keys()) { operatorApprovals.delete(k); };
    };

    // Internal

    private func _ownerOf(tokenId : T.TokenId) : ?Principal {
        return owners.get(tokenId);
    };

    private func _getProfile(p : Principal) : Result.Result<T.Profile, Text> {
        switch(profiles.get(p)){
            case(null){
                return #err("NOPROFILE");
            };
            case(?pro){
                return #ok(pro);
            };
        };

    };
    private func _createProfile(p: Principal) : async T.Profile {
        let profile : T.Profile = {
            tank_color = await _get_random_tankcolor();
        };

        profiles.put(p, profile);
        return (profile);
    };

    private func _tokenMetaData(tokenId : T.TokenId) : ?T.TokenMetadata {
        return tokenFishes.get(tokenId);
    };

    private func _allOwnedTokens(p : Principal) : [(T.TokenId, T.TokenMetadata)] {
        var ret_arr: [var (T.TokenId, T.TokenMetadata)] = [var];
        switch(balances.get(p)){
            case(null){
                return [];
            };
            case(?n){
                ret_arr := Array.init<(T.TokenId, T.TokenMetadata)>(n, (
                    0,
                    {
                        minted_at = 0;
                        minted_by = p;
                        properties: T.TokenProps = {
                            color_1 = "";
                            color_2 = "";
                            color_3 = "";
                        };
                        transferred_by = null;
                        transferred_at = null;
                    })
                );
            };
        };
            
        var count: Nat = 0;
        Iter.iterate(owners.entries(), func((k : T.TokenId, v : Principal), index: Nat) {
            if(Principal.equal(p,v)){
                switch(tokenFishes.get(k)){
                    case(null){};
                    case(?md){
                        ret_arr[count] := (k,md);
                        count+=1;
                    };
                };
            };
        });
        return (Array.freeze(ret_arr));
    };

    private func _randomOwnerAll() : async (T.Profile, [(T.TokenId, T.TokenMetadata)]) {
        var principalIndex : Nat = await _largerand(balances.size());
        _log("Random Principal Index: " # Nat.toText(principalIndex) # "/" # Nat.toText(balances.size()));
        let p : Principal = Iter.toArray(balances.keys())[principalIndex];
        var profile : T.Profile = {
            tank_color = "darkblue";
        };

        switch(profiles.get(p)){
            case(null){
            };
            case(?pro){
                profile:= pro;
            };
        };
        return (profile, _allOwnedTokens(p));
    };

    private func _isApprovedForAll(owner : Principal, opperator : Principal) : Bool {
        switch (operatorApprovals.get(owner)) {
            case(?whiteList) {
                for (allow in whiteList.vals()) {
                    if (allow == opperator) {
                        return true;
                    };
                };
            };
            case null {return false;};
        };
        return false;
    };

    private func _approve(to : Principal, tokenId : Nat) : () {
        tokenApprovals.put(tokenId, to);
    };

    private func _removeApprove(tokenId : Nat) : () {
        let _ = tokenApprovals.remove(tokenId);
    };

    private func _exists(tokenId : Nat) : Bool {
        return Option.isSome(owners.get(tokenId));
    };

    private func _getApproved(tokenId : Nat) : ?Principal {
        assert _exists(tokenId) == true;
        switch(tokenApprovals.get(tokenId)) {
            case (?v) { return ?v };
            case null {
                return null;
            };
        }
    };

    private func _hasApprovedAndSame(tokenId : Nat, spender : Principal) : Bool {
        switch(_getApproved(tokenId)) {
            case (?v) {
                return v == spender;
            };
            case null { return false}
        }
    };

    private func _isApprovedOrOwner(spender : Principal, tokenId : Nat) : Bool {
        assert _exists(tokenId);
        let owner = Option.unwrap(_ownerOf(tokenId));
        return spender == owner or _hasApprovedAndSame(tokenId, spender) or _isApprovedForAll(owner, spender);
    };

    private func _transfer(from : Principal, to : Principal, tokenId : Nat) : () {
        assert _exists(tokenId);
        assert Option.unwrap(_ownerOf(tokenId)) == from;

        // Bug in HashMap https://github.com/dfinity/motoko-base/pull/253/files
        // this will throw unless you patch your file
        _removeApprove(tokenId);

        _decrementBalance(from);
        _incrementBalance(to);
        owners.put(tokenId, to);
    };

    private func _incrementBalance(address : Principal) {
        switch (balances.get(address)) {
            case (?v) {
                balances.put(address, v + 1);
            };
            case null {
                balances.put(address, 1);
            }
        }
    };

    private func _decrementBalance(address : Principal) {
        switch (balances.get(address)) {
            case (?v) {
                balances.put(address, v - 1);
            };
            case null {
                balances.put(address, 0);
            }
        }
    };

    let ledgerCanisterId : Text = "yeeiw-3qaaa-aaaah-qcvmq-cai";
    type sendparams = {
            to : Text;
            fee : {e8s: Nat64};
            memo : Nat;
            from_subaccount : ?Nat8;
            created_at_time : ?{ timestamp_nanos : Nat64 };
            amount : {e8s: Nat64};
        };

    

    private func _mint(block_height: Nat64, to : Principal) : async Result.Result<(Nat, T.TokenMetadata), Text> {
        /*let AMOUNT_X_10: Nat64 = 10;
        let PROPER_FEEE: Nat64 = 1;
        let ledger_canister : actor {
            send_dfx : (sendparams) -> async Nat64;
        } = to(ledgerCanisterId);

        let block : Nat64 = await ledger_canister.send_dfx({
            memo=0; 
            amount={
                e8s=AMOUNT_X_10;
            };
            fee={
                e8s=PROPER_FEEE;
                };
            from_subaccount=null;
            to="ltboi-5ke46-b3jbd-phuth-6k6xe-iitgq-hsxqn-ik4ty-z5gdj-sgtf7-5qe";
            created_at_time=null;
            });
        _log("Transaction block:" # Nat64.toText(block));*/
        tokenPk += 1;
        assert not _exists(tokenPk);
        let fish: T.TokenMetadata = {
            minted_at = Nat64.fromNat(Int.abs(Time.now()));
            minted_by = to;
            properties: T.TokenProps = {
                color_1 = await _get_random_color1();
                color_2 = await _get_random_color2();
                color_3 = await _get_random_color3();
            };
            transferred_by = null;
            transferred_at = null;
        };
        
        _incrementBalance(to);
        owners.put(tokenPk, to);
        tokenFishes.put(tokenPk, fish);
        return #ok(tokenPk, fish);
    };

    private func _burn(tokenId : Nat) {
        let owner = Option.unwrap(_ownerOf(tokenId));

        _removeApprove(tokenId);
        _decrementBalance(owner);

        ignore owners.remove(tokenId);
    };

    private func _log(msg: Text) : () {
        logs:= logs # "\n" # msg;
    };

    private func _largerand(max: Nat) : async Nat{
        return await _rand(max, 31, 2147483647);
    };

    private func _smallrand(max: Nat) : async Nat{
        return await _rand(max, 7, 127);
    };

    private func _rand(max: Nat, range_p: Nat8, maxRand: Float) : async Nat{
        let range_p : Nat8 = 7;

        var next: ?Nat = finite.range(range_p);
        if(next == null){
            var b: Blob = await Random.blob();
            finite := Random.Finite(b);
            next := finite.range(range_p);
            Debug.print("created new Finite");
        };

        Debug.print("rand: " # Nat.toText(Option.get(next, 0)));

        let maxRand : Float = 127;
        var randPercent : Float = Float.fromInt(Option.get(next, 0)) / maxRand;
        var randNormalized : Float = Float.floor(randPercent * Float.fromInt(max));
        var rand_return : Nat = Int.abs(Float.toInt(randNormalized));

        // takes care of the case where random was exactly maxRand, this helps keep the spread the same from 0 to (max - 1);
        if(rand_return == max){
            rand_return -= 1;
        };

        return (rand_return);
    };

    private func _get_random_color1() : async Text {
        let i : Nat = await _smallrand(colors_for_1.size());
        return (colors_for_1[i]);
    };

    private func _get_random_color2() : async Text {
        let i : Nat = await _smallrand(colors_for_2.size());
        return (colors_for_2[i]);
    };

    private func _get_random_color3() : async Text {
        let i : Nat = await _smallrand(colors_for_3.size());
        return (colors_for_3[i]);
    };

    private func _get_random_tankcolor() : async Text {
        let i : Nat = await _smallrand(colors_for_tank.size());
        return (colors_for_tank[i]);
    };

    private let colors_for_1 : [Text] = [
        /*pastels*/
        "#ABDEE6",
        "#CBAACB",
        "#FFFFB5",
        "#FFCCB6",
        "#97C1A9",
        /*bright*/
        "#FFBF65",
        "#4DD091",
        "#FF60A8",
        "#4DD091",
        "#C05780",
        /*neutral*/
        "#74737A",
        "#EADCC3",
        "#DFE6E6",
        "#1F3D51",
        "#B4C9C7",
        /*Gemstones*/
        "#F12761",
        "#005245",
        "#00ACA5",
        "#187B30",
        "#9E1C5C"
    ];

    private let colors_for_2 : [Text] = [
         /*pastels*/
        "#ABDEE6",
        "#CBAACB",
        "#FFFFB5",
        "#FFCCB6",
        "#97C1A9",
        /*bright*/
        "#FFBF65",
        "#4DD091",
        "#FF60A8",
        "#4DD091",
        "#C05780",
        /*neutral*/
        "#74737A",
        "#EADCC3",
        "#DFE6E6",
        "#1F3D51",
        "#B4C9C7",
        /*Gemstones*/
        "#F12761",
        "#005245",
        "#00ACA5",
        "#187B30",
        "#9E1C5C"
    ];

    private let colors_for_3 : [Text] = [
         /*pastels*/
        "#ABDEE6",
        "#CBAACB",
        "#FFFFB5",
        "#FFCCB6",
        "#97C1A9",
        /*bright*/
        "#FFBF65",
        "#4DD091",
        "#FF60A8",
        "#4DD091",
        "#C05780",
        /*neutral*/
        "#74737A",
        "#EADCC3",
        "#DFE6E6",
        "#1F3D51",
        "#B4C9C7",
        /*Gemstones*/
        "#F12761",
        "#005245",
        "#00ACA5",
        "#187B30",
        "#9E1C5C"
    ];

        private let colors_for_tank : [Text] = [
         /*pastels*/
        "#ABDEE6",
        "#CBAACB",
        "#FFFFB5",
        "#FFCCB6",
        "#97C1A9",
        /*bright*/
        "#FFBF65",
        "#4DD091",
        "#FF60A8",
        "#4DD091",
        "#C05780",
        /*neutral*/
        "#74737A",
        "#EADCC3",
        "#DFE6E6",
        "#1F3D51",
        "#B4C9C7",
        /*Gemstones*/
        "#F12761",
        "#005245",
        "#00ACA5",
        "#187B30",
        "#9E1C5C"
    ];

    system func preupgrade() {
        tokenFishEntries := Iter.toArray(tokenFishes.entries());
        ownersEntries := Iter.toArray(owners.entries());
        balancesEntries := Iter.toArray(balances.entries());
        profilesEntries := Iter.toArray(profiles.entries());
        tokenApprovalsEntries := Iter.toArray(tokenApprovals.entries());
        operatorApprovalsEntries := Iter.toArray(operatorApprovals.entries());
    };

    system func postupgrade() {
        tokenFishEntries := [];
        ownersEntries := [];
        balancesEntries := [];
        profilesEntries := [];
        tokenApprovalsEntries := [];
        operatorApprovalsEntries := [];
    };
};