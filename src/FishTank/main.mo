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
import TP "token_prop_type";
import Time "mo:base/Time";

actor class DRC721(_name : Text, _symbol : Text) {
    private stable var tokenPk : Nat = 0;

    private stable var tokenFishEntries : [(T.TokenId, T.TokenMetadata)] = [];
    private stable var ownersEntries : [(T.TokenId, Principal)] = [];
    private stable var balancesEntries : [(Principal, Nat)] = [];
    private stable var tokenApprovalsEntries : [(T.TokenId, Principal)] = [];
    private stable var operatorApprovalsEntries : [(Principal, [Principal])] = [];

    private let tokenFishes : HashMap.HashMap<T.TokenId, T.TokenMetadata> = HashMap.fromIter<T.TokenId, T.TokenMetadata>(tokenFishEntries.vals(), 10, Nat.equal, Hash.hash);
    private let owners : HashMap.HashMap<T.TokenId, Principal> = HashMap.fromIter<T.TokenId, Principal>(ownersEntries.vals(), 10, Nat.equal, Hash.hash);
    private let balances : HashMap.HashMap<Principal, Nat> = HashMap.fromIter<Principal, Nat>(balancesEntries.vals(), 10, Principal.equal, Principal.hash);
    private let tokenApprovals : HashMap.HashMap<T.TokenId, Principal> = HashMap.fromIter<T.TokenId, Principal>(tokenApprovalsEntries.vals(), 10, Nat.equal, Hash.hash);
    private let operatorApprovals : HashMap.HashMap<Principal, [Principal]> = HashMap.fromIter<Principal, [Principal]>(operatorApprovalsEntries.vals(), 10, Principal.equal, Principal.hash);
    
    private var finite : Random.Finite = Random.Finite(Blob.fromArray([]));

    public shared func balanceOf(p : Principal) : async ?Nat {
        return balances.get(p);
    };

    public shared func ownerOf(tokenId : T.TokenId) : async ?Principal {
        return _ownerOf(tokenId);
    };


    public shared query func tokenMetaData(tokenId : T.TokenId) : async ?T.TokenMetadata {
        return _tokenMetaData(tokenId);
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

    public shared(msg) func mint() : async Nat {
        tokenPk += 1;
        await _mint(msg.caller, tokenPk);
        return tokenPk;
    };


    // Internal

    private func _ownerOf(tokenId : T.TokenId) : ?Principal {
        return owners.get(tokenId);
    };

    private func _tokenMetaData(tokenId : T.TokenId) : ?T.TokenMetadata {
        return tokenFishes.get(tokenId);
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

    private func _mint(to : Principal, tokenId : Nat) : async () {
        assert not _exists(tokenId);

        let fish: T.TokenMetadata = {
            minted_at = Nat64.fromNat(Int.abs(Time.now()));
            minted_by = to;
            properties: TP.TokenProperties = {
                color_1 = await _get_random_color1();
                color_2 = await _get_random_color2();
            };
            transferred_by = null;
            transferred_at = null;
        };
        
        _incrementBalance(to);
        owners.put(tokenId, to);
        tokenFishes.put(tokenId, fish);
    };

    private func _burn(tokenId : Nat) {
        let owner = Option.unwrap(_ownerOf(tokenId));

        _removeApprove(tokenId);
        _decrementBalance(owner);

        ignore owners.remove(tokenId);
    };

    private func _rand(max: Nat) : async Nat{
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
        let i : Nat = await _rand(colors_for_1.size());
        return (colors_for_1[i]);
    };

    private func _get_random_color2() : async Text {
        let i : Nat = await _rand(colors_for_2.size());
        return (colors_for_2[i]);
    };

    private let colors_for_1 : [Text] = [
        "hsl(0, 70%, 50%)", /*red*/
        "hsl(200, 50%, 50%)", /*blue*/
        "hsl(155, 30%, 50%)" /*green*/
    ];

    private let colors_for_2 : [Text] = [
        "hsl(0, 70%, 50%)", /*red*/
        "hsl(200, 50%, 50%)", /*blue*/
        "hsl(155, 30%, 50%)" /*green*/
    ];

    system func preupgrade() {
        tokenFishEntries := Iter.toArray(tokenFishes.entries());
        ownersEntries := Iter.toArray(owners.entries());
        balancesEntries := Iter.toArray(balances.entries());
        tokenApprovalsEntries := Iter.toArray(tokenApprovals.entries());
        operatorApprovalsEntries := Iter.toArray(operatorApprovals.entries());
        
    };

    system func postupgrade() {
        tokenFishEntries := [];
        ownersEntries := [];
        balancesEntries := [];
        tokenApprovalsEntries := [];
        operatorApprovalsEntries := [];
    };
};