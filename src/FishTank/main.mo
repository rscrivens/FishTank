import Array "mo:base/Array";
import Bool "mo:base/Bool";
import Buffer "mo:base/Buffer";
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
import T "types";
import Time "mo:base/Time";
import Result "mo:base/Result";
import F "ledger_types";

actor class DRC721() {
    private stable let _name : Text = "Fish Tank";
    private stable let _symbol : Text = "FT";
    private stable var donateKey : ?Principal = null;
    private stable var workaround : [(T.FishProps, T.FishSize, T.FishSpeed, T.TransferEvent, T.BodyType, T.UserId, T.HatAcc)] = [];

    private stable var donated_fish : Nat = 0;
    private stable var adopted_fish : Nat = 0;

    private stable var fishEntries : [T.FishMetadata] = [];
    private stable var userEntries : [(T.UserKey, T.UserInfo)] = [];
    private stable var userIdKeyEntries : [Text] = [];
    private stable var displayTankEntries : [T.DisplayTank] = [];
    private stable var stakingTankEntries : [T.StakingTank] = [];
    private stable var goldfishAirDropEntries : [(T.UserId, Bool)] = [];
    private stable var adoptableFishEntries: [(T.FishId, Nat)] = [];

    private let fish_buff = Buffer.Buffer<T.FishMetadata>(0);
    private let userIdKey_buff = Buffer.Buffer<Text>(0);
    private let display_tank_buff = Buffer.Buffer<T.DisplayTank>(0);
    private let staking_tank_buff = Buffer.Buffer<T.StakingTank>(0);
    private let users_hash : HashMap.HashMap<T.UserKey, T.UserInfo> = HashMap.fromIter<T.UserKey, T.UserInfo>(userEntries.vals(), 10, Principal.equal, Principal.hash);
    private let goldfishAirDrops : HashMap.HashMap<T.UserId, Bool> = HashMap.fromIter<T.UserId, Bool>(goldfishAirDropEntries.vals(), 10, Nat.equal, Hash.hash);
    private let adoptable_fish_hash : HashMap.HashMap<T.FishId, Nat> = HashMap.fromIter<T.FishId, Nat>(adoptableFishEntries.vals(), 10, Nat.equal, Hash.hash);

    private var finite : Random.Finite = Random.Finite(Blob.fromArray([]));

    /* Admin vars */
    private stable var adminsEntries : [Text] = ["4tplt-gs3ay-72gw5-7kr63-brwrd-nonyu-xxkhs-l3ljg-4xj24-ahvmk-pqe"];
    private stable var analyticsEntries : [{name:Text; params: ?[Text]; date:Nat}] = [];
    private let analytics_buff = Buffer.Buffer<{name:Text; params: ?[Text]; date:Nat}>(10);
    private stable var logs : Text = "";

    /*************************** Query Functions *********************************/
    public shared query func getBalance(u_key : T.UserKey) : async Result.Result<Nat,T.ErrorCode> {
        return _getBalance(u_key);
    };

    public shared query func getDisplayTank(u_id : T.UserId) : async Result.Result<{tank:T.DisplayTank;fish:[T.FishMetadata]},T.ErrorCode> {
        return _getDisplayTank(u_id);
    };

    public shared query func getOwner(fishId : T.FishId) : async Result.Result<Text,T.ErrorCode> {
        return _getOwner(fishId);
    };

    public shared query func getServerStats() : async Result.Result<T.ServerStats,T.ErrorCode> {
        return #ok({
            adopted_fish = adopted_fish;
            adoptable_fish = adoptable_fish_hash.size();
            donated_fish = donated_fish;
            minted_fish = fish_buff.size();
            users = users_hash.size();
        });
    };

    public shared query func getStakingTank(u_id : T.UserId) : async Result.Result<{tank:T.StakingTank;fish:[T.FishMetadata]},T.ErrorCode> {
        return _getStakingTank(u_id);
    };

    public shared query func getStorageTank(u_id : T.UserId) : async Result.Result<{fish:[T.FishId];fishMD:[T.FishMetadata];inDisplay:[T.FishId];inStaking:[T.FishId]},T.ErrorCode> {
        return _getStorageTank(u_id);
    };

    public shared query func getUserInfo(u_key : T.UserKey) : async Result.Result<T.UserInfo,T.ErrorCode> {
        return _getUserInfo(u_key);
    };

    public shared query func name() : async Text {
        return _name;
    };

    public shared query func symbol() : async Text {
        return _symbol;
    };
  
    public shared query (msg) func login() : async Result.Result<T.LoggedInUserDetails,T.ErrorCode>{
        if(Principal.isAnonymous(msg.caller)) {
            return #err(#LOGINREQUIRED);
        };

        return _login(msg.caller);
    };

    /*************************** Update Functions *********************************/
    public shared(msg) func toggleInDisplayTank(fishId:T.FishId) : async Result.Result<Bool,T.ErrorCode>{
        if(Principal.isAnonymous(msg.caller)) {
            return #err(#LOGINREQUIRED);
        };
        
        return _toggleInDisplayTank(msg.caller, fishId);
    };

    public shared(msg) func toggleInStakingTank(fishId:T.FishId) : async Result.Result<Bool,T.ErrorCode>{
        if(Principal.isAnonymous(msg.caller)) {
            return #err(#LOGINREQUIRED);
        };

        return _toggleInStakingTank(msg.caller, fishId);
    };

/*
    public shared(msg) func adopt(fishId:T.FishId) : async Result.Result<{fishId:T.FishId; metadata:T.FishMetadata},T.ErrorCode>{
        if(Principal.isAnonymous(msg.caller)) {
            return #err(#LOGINREQUIRED);
        };

        return await _adopt(msg.caller, fishId);
    };

    public shared(msg) func adoptInit() : async Result.Result<{fishIds:[T.FishId]; metadata:[T.FishMetadata]},T.ErrorCode>{
        if(Principal.isAnonymous(msg.caller)) {
            return #err(#LOGINREQUIRED);
        };

        return await _adoptInit(msg.caller);
    };
*/

    public shared(msg) func donateFish(fishId:T.FishId) : async Result.Result<{fish_hat: T.HatAcc},T.ErrorCode>{
        if(Principal.isAnonymous(msg.caller)) {
            return #err(#LOGINREQUIRED);
        };

        return await _donateFish(msg.caller, fishId);
    };

    public shared(msg) func unlockHatOnFish(fishId:T.FishId, hat:T.HatAcc) : async Result.Result<{fish_hats:[T.HatAcc];fishMD:T.FishMetadata},T.ErrorCode>{
        if(Principal.isAnonymous(msg.caller)) {
            return #err(#LOGINREQUIRED);
        };

        return await _unlockHatOnFish(msg.caller, fishId, hat);
    };

    public shared (msg) func createNewUser() : async Result.Result<T.LoggedInUserDetails,T.ErrorCode>{
        if(Principal.isAnonymous(msg.caller)) {
            return #err(#LOGINREQUIRED);
        };

        var new_user = await _createNewUser(msg.caller);
        return _login(msg.caller);
    };

    public shared func getRandomTank() : async Result.Result<{tank:T.DisplayTank;fish:[T.FishMetadata];has_goldfish:Bool},T.ErrorCode> {
        return await _getRandomTank();
    };

    public shared(msg) func mint() : async Result.Result<{fishId:T.FishId; metadata:T.FishMetadata},T.ErrorCode>{
        if(Principal.isAnonymous(msg.caller)) {
            return #err(#LOGINREQUIRED);
        };

        // _log("Trying to mint: " # Principal.toText(msg.caller));

        // Need to implement payment before minting

        return await _mint(msg.caller, false);
    };

    public shared(msg) func setFishName(fishId:T.FishId, name:Text) : async Result.Result<Text,T.ErrorCode>{
        if(Principal.isAnonymous(msg.caller)) {
            return #err(#LOGINREQUIRED);
        };

        return _setFishName(msg.caller, fishId, name);
    };

    public shared(msg) func setFishHat(fishId:T.FishId, hat:T.HatAcc) : async Result.Result<T.FishMetadata,T.ErrorCode>{
        if(Principal.isAnonymous(msg.caller)) {
            return #err(#LOGINREQUIRED);
        };

        return _setFishHat(msg.caller, fishId, hat);
    };

    public shared(msg) func toggleFavorite(fishId:T.FishId) : async Result.Result<Bool,T.ErrorCode>{
        if(Principal.isAnonymous(msg.caller)) {
            return #err(#LOGINREQUIRED);
        };

        return _toggleFavorite(msg.caller, fishId);
    };

    public shared(msg) func tradeGoldfish() : async Result.Result<{fishId:T.FishId; metadata:T.FishMetadata},T.ErrorCode> {
        if(Principal.isAnonymous(msg.caller)) {
            return #err(#LOGINREQUIRED);
        };

        return await _tradeGoldfish(msg.caller);
    };

/*
    public shared func isApprovedForAll(owner : Principal, opperator : Principal) : async Bool {
        return _isApprovedForAll(owner, opperator);
    };

    public shared(msg) func approve(to : Principal, tokenId : T.FishId) : async () {
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
*/
    /*********************** ADMIN **********************/
    public shared(msg) func airdropGoldfish(rate:Float) : async Result.Result<Text, T.ErrorCode> {
        switch(_verifyAdmin(msg.caller)){
            case(#err(t)){ return #err(t)};
            case(#ok(t)){
                return await _airdropGoldfish(rate);
            };
        };
    };

    public shared(msg) func getLogs(): async Result.Result<Text, T.ErrorCode> {
        switch(_verifyAdmin(msg.caller)){
            case(#err(t)){ return #err(t)};
            case(#ok(t)){
                return #ok(logs);
            };
        };
    };

    public shared(msg) func exportBackup(): async Result.Result<T.Backup, T.ErrorCode>{
        switch(_verifyAdmin(msg.caller)){
            case(#err(t)){ return #err(t)};
            case(#ok(t)){
                return _exportBackup();
            };
        };
    };

    public shared(msg) func importBackup(backup:T.Backup): async Result.Result<Text, T.ErrorCode>{
        switch(_verifyAdmin(msg.caller)){
            case(#err(t)){ return #err(t)};
            case(#ok(t)){
                return _importBackup(backup);
            };
        };
    };

    public shared(msg) func resetAllState(): async Result.Result<(), T.ErrorCode> {
        switch(_verifyAdmin(msg.caller)){
            case(#err(t)){ return #err(t)};
            case(#ok(t)){
                for(k in users_hash.keys()) { users_hash.delete(k); };
                for(k in goldfishAirDrops.keys()) { goldfishAirDrops.delete(k); };
                for(k in adoptable_fish_hash.keys()) { adoptable_fish_hash.delete(k); };
                fish_buff.clear();
                display_tank_buff.clear();
                staking_tank_buff.clear();
                userIdKey_buff.clear();
                donated_fish := 0;
                adopted_fish := 0;

                return #ok();
            };
        };
    };

    public shared(msg) func addAdmin(principal: Text): async Result.Result<Text, T.ErrorCode> {
        switch(_verifyAdmin(msg.caller)){
            case(#err(t)){ return #err(t)};
            case(#ok(t)){
                return _addAdmin(principal);
            };
        };
    };

    public shared(msg) func removeAdmin(principal: Text): async Result.Result<Text, T.ErrorCode> {
        switch(_verifyAdmin(msg.caller)){
            case(#err(t)){ return #err(t)};
            case(#ok(t)){
                return _removeAdmin(principal);
            };
        };
    };

    public shared(msg) func getAdmins(): async Result.Result<[Text],T.ErrorCode>{
        switch(_verifyAdmin(msg.caller)){
            case(#err(t)){ return #err(t)};
            case(#ok(t)){
                return #ok(adminsEntries);
            };
        };
    };

    public shared(msg) func getAnalytics(): async Result.Result<[{name:Text; params: ?[Text]; date:Nat}], T.ErrorCode>{
        switch(_verifyAdmin(msg.caller)){
            case(#err(t)){ return #err(t)};
            case(#ok(t)){
                return _getAnalytics();
            };
        };
    };

    public shared(msg) func clearAnalytics(): async Result.Result<(), T.ErrorCode>{
        switch(_verifyAdmin(msg.caller)){
            case(#err(t)){ return #err(t)};
            case(#ok(t)){
                return _clearAnalytics();
            };
        };
    };
    
    /*************************** Private Admin Functions *********************************/
    private func _verifyAdmin(p: Principal): Result.Result<Text, T.ErrorCode> {
        let found = Array.find<Text>(adminsEntries, func(a){ return Principal.toText(p) == a; });
        switch(found){
            case (null){
                return #err(#NOTAUTHORIZED);
            };
            case (_){
                return #ok("Authorized");
            };
        };
    };

    private func _addAdmin(p: Text): Result.Result<Text, T.ErrorCode> {
        let found = Array.find<Text>(adminsEntries, func(a){ return p == a; });
        switch(found){
            case (null){
                let admins_buff = Buffer.Buffer<Text>(1);
                for (admin in adminsEntries.vals()) { admins_buff.add(admin); };
                admins_buff.add(p);
                adminsEntries := admins_buff.toArray();
                return #ok("Added");
            };
            case (_){
                return #ok("Already exists");
            };
        };
    };

    private func _removeAdmin(p: Text): Result.Result<Text, T.ErrorCode> {
        let found = Array.find<Text>(adminsEntries, func(a){ return p == a; });
        switch(found){
            case (null){
                return #ok("Not found");
            };
            case (_){
                let admins_buff = Buffer.Buffer<Text>(1);
                for (admin in adminsEntries.vals()) {
                    if(admin != p){
                        admins_buff.add(admin);
                    };
                };
                adminsEntries := admins_buff.toArray();
                return #ok("Removed");
            };
        };
    };

    private func _getAnalytics(): Result.Result<[{name:Text; params: ?[Text]; date:Nat}], T.ErrorCode> {
        return #err(#NOTYETIMPLEMENTED);
    };

    private func _clearAnalytics(): Result.Result<(), T.ErrorCode> {
        return #err(#NOTYETIMPLEMENTED);
    };

    /*************************** Private Query Functions *********************************/
    private func _getBalance(u_key : T.UserKey) : Result.Result<Nat,T.ErrorCode> {
        switch(users_hash.get(u_key)){
            case(null){
                return #err(#NOUSERFOUND);
            };
            case(?user_info){
                return #ok(user_info.fish.size());
            };
        };
    };

    private func _getFishMetadata(fishIds: [T.FishId]) : [T.FishMetadata]{
        let fish:[T.FishMetadata] = Array.tabulate<T.FishMetadata>(fishIds.size(), func (i:Nat) {
            return fish_buff.get(fishIds.get(i));
        });

        return fish;
    };

    private func _getDisplayTank(u_id : T.UserId) : Result.Result<{tank:T.DisplayTank;fish:[T.FishMetadata];has_goldfish:Bool},T.ErrorCode> {
        switch(display_tank_buff.getOpt(u_id)){
            case(null){
                return #err(#NOUSERFOUND);
            };
            case(?display_tank){
                let fish_metadata:[T.FishMetadata] = _getFishMetadata(display_tank.fish);
                var has_gf = false;
                switch(goldfishAirDrops.get(u_id)){
                    case(null){};
                    case(?ad){
                        has_gf := ad;
                    };
                };
                return #ok({tank=display_tank;fish=fish_metadata;has_goldfish=has_gf});
            };
        };
    };

    private func _getOwner(fishId : T.FishId) : Result.Result<Text, T.ErrorCode> {
        switch(fish_buff.getOpt(fishId)){
            case(null){
                return #err(#NOFISHFOUND);
            };
            case(?fish){
                return #ok(fish.owner_history[fish.owner_history.size()].to);
            };
        };
    };

    private func _getStakingTank(u_id : T.UserId) : Result.Result<{tank:T.StakingTank;fish:[T.FishMetadata]},T.ErrorCode> {
        switch(staking_tank_buff.getOpt(u_id)){
            case(null){
                return #err(#NOUSERFOUND);
            };
            case(?staking_tank){

                let fish_metadata:[T.FishMetadata] = _getFishMetadata(staking_tank.fish);
                return #ok({tank=staking_tank;fish=fish_metadata});
            };
        };
    };

    private func _getStorageTank(u_id : T.UserId) : Result.Result<{fish:[T.FishId];fishMD:[T.FishMetadata];inDisplay:[T.FishId];inStaking:[T.FishId]},T.ErrorCode> {
        let stakedFish : [T.FishId] = switch(staking_tank_buff.getOpt(u_id)){
            case(null){
                return #err(#NOUSERFOUND);
            };
            case(?staking_tank){
                staking_tank.fish;
            };
        };

        let displayedFish : [T.FishId] = switch(display_tank_buff.getOpt(u_id)){
            case(null){
                return #err(#NOUSERFOUND);
            };
            case(?display_tank){
                display_tank.fish;
            };
        };

        let user : T.UserInfo = switch(users_hash.get(Principal.fromText(userIdKey_buff.get(u_id)))){
            case(null){
                return #err(#NOUSERFOUND);
            };
            case(?user){
                user;
            };
        };

        let fish_metadata:[T.FishMetadata] = _getFishMetadata(user.fish);
        return #ok({fish=user.fish;fishMD=fish_metadata; inDisplay=displayedFish;inStaking=stakedFish});
    };

    private func _getUserInfo(u_key : T.UserKey) : Result.Result<T.UserInfo, T.ErrorCode> {
        switch(users_hash.get(u_key)){
            case(null){
                return #err(#NOUSERFOUND);
            };
            case(?user_info){
                return #ok(user_info);
            };
        };
    };

    /*************************** Private Update Functions *********************************/

    private func _toggleInDisplayTank(u_key: T.UserKey, fishId: T.FishId) : Result.Result<Bool, T.ErrorCode>{
        if(not _isOwner(u_key, fishId)){
            return #err(#NOTAUTHORIZED);
        };

        let user = switch(users_hash.get(u_key)){
            case (null){
                return #err(#NOUSERFOUND);
            };
            case (?user){
                user;
            };
        };

        switch(Array.find(display_tank_buff.get(user.id).fish, func(id: T.FishId):Bool{ id == fishId; })){
            case(null){
                _removeFromStakingTank(user.id, fishId);
                _addToDisplayTank(user.id, fishId);
                return #ok(true);
            };
            case(_){
                _removeFromDisplayTank(user.id, fishId);
                return #ok(false);
            };
        };
    };

    private func _toggleInStakingTank(u_key: T.UserKey, fishId: T.FishId) : Result.Result<Bool, T.ErrorCode>{
        return #err (#NOTYETIMPLEMENTED);
        
        if(not _isOwner(u_key, fishId)){
            return #err(#NOTAUTHORIZED);
        };

        let user = switch(users_hash.get(u_key)){
            case (null){
                return #err(#NOUSERFOUND);
            };
            case (?user){
                user;
            };
        };
        
        switch(Array.find(staking_tank_buff.get(user.id).fish, func(id: T.FishId):Bool{ id == fishId; })){
            case(null){
                _removeFromDisplayTank(user.id, fishId);
                _addToStakingTank(user.id, fishId);
                return #ok(true);
            };
            case(_){
                _removeFromStakingTank(user.id, fishId);
                return #ok(false);
            };
        };
    };
    
    private func _removeFromDisplayTank(u_id: T.UserId, fishId: T.FishId) : () {
        let cur_display_tank = display_tank_buff.get(u_id);
        let new_display_fish = Array.filter(cur_display_tank.fish, func(id:T.FishId):Bool{ return id != fishId});
        let new_display_tank : T.DisplayTank = {
            acc_left = cur_display_tank.acc_left;
            acc_right = cur_display_tank.acc_right;
            color_bg = cur_display_tank.color_bg;
            color_bottom = cur_display_tank.color_bottom;
            effect = cur_display_tank.effect;
            fish = new_display_fish;
        };
        display_tank_buff.put(u_id, new_display_tank);
    };

    private func _addToDisplayTank(u_id: T.UserId, fishId: T.FishId) {
        let cur_display_tank = display_tank_buff.get(u_id);
        let cur_display_fish = cur_display_tank.fish;
        switch(Array.find(cur_display_fish, func(id: T.FishId):Bool{ id == fishId; })){
            case (null){
                let new_display_fish : Buffer.Buffer<T.FishId> = Buffer.Buffer(cur_display_fish.size() + 1);
                for (x in cur_display_fish.vals()) {
                    new_display_fish.add(x);
                };
                new_display_fish.add(fishId);

                let new_display_tank : T.DisplayTank = {
                    acc_left = cur_display_tank.acc_left;
                    acc_right = cur_display_tank.acc_right;
                    color_bg = cur_display_tank.color_bg;
                    color_bottom = cur_display_tank.color_bottom;
                    effect = cur_display_tank.effect;
                    fish = new_display_fish.toArray();
                };

                display_tank_buff.put(u_id, new_display_tank);
            };
            case(_){
            };
        };
    };

    private func _removeFromStakingTank(u_id: T.UserId, fishId: T.FishId) : () {
        let cur_staking_tank = staking_tank_buff.get(u_id);
        let new_staking_fish = Array.filter(cur_staking_tank.fish, func(id:T.FishId):Bool{ return id != fishId});
        let new_staking_tank : T.StakingTank = {
            acc_left = cur_staking_tank.acc_left;
            acc_right = cur_staking_tank.acc_right;
            color_bg = cur_staking_tank.color_bg;
            color_bottom = cur_staking_tank.color_bottom;
            effect = cur_staking_tank.effect;
            fish = new_staking_fish;
        };
        staking_tank_buff.put(u_id, new_staking_tank);
    };

    private func _addToStakingTank(u_id: T.UserId, fishId: T.FishId) {
        let cur_staking_tank = staking_tank_buff.get(u_id);
        let cur_staking_fish = cur_staking_tank.fish;
        switch(Array.find(cur_staking_fish, func(id: T.FishId):Bool{ id == fishId; })){
            case (null){
                let new_staking_fish : Buffer.Buffer<T.FishId> = Buffer.Buffer(cur_staking_fish.size() + 1);
                for (x in cur_staking_fish.vals()) {
                    new_staking_fish.add(x);
                };
                new_staking_fish.add(fishId);

                let new_staking_tank : T.StakingTank = {
                    acc_left = cur_staking_tank.acc_left;
                    acc_right = cur_staking_tank.acc_right;
                    color_bg = cur_staking_tank.color_bg;
                    color_bottom = cur_staking_tank.color_bottom;
                    effect = cur_staking_tank.effect;
                    fish = new_staking_fish.toArray();
                };

                staking_tank_buff.put(u_id, new_staking_tank);
            };
            case(_){
            };
        };
    };

    private func _createNewUser(u_key: T.UserKey) : async T.UserInfo {
        let new_user : T.UserInfo = {
            id = users_hash.size();
            achievements = [];
            created_date = Int.abs(Time.now());
            fish = [];
            fish_hats = [];
            tank_accs = [];
            wallets = [];
            last_login = Int.abs(Time.now());
            login_streak = 1;
        };

        let new_display_tank : T.DisplayTank = {
            fish = [];
            color_bottom = "";
            color_bg = "";
            acc_left = "";
            acc_right = "";
            effect = "";
        };
        // tank_color = await _get_random_tankcolor();

        let new_staking_tank: T.StakingTank = {
            fish = [];
            color_bottom = "";
            color_bg = "";
            acc_left = "";
            acc_right = "";
            effect = "";
        };

        users_hash.put(u_key, new_user);
        userIdKey_buff.add(Principal.toText(u_key));
        display_tank_buff.add(new_display_tank);
        staking_tank_buff.add(new_staking_tank);

        goldfishAirDrops.put(new_user.id, true);
        // _log("Added goldfish record with true");
        return (new_user);
    };

    private func _login(u_key:T.UserKey) : Result.Result<T.LoggedInUserDetails,T.ErrorCode>{
        switch(users_hash.get(u_key)){
            case(null){
                return #err(#NOUSERFOUND);
            };
            case(?user){
                // check if login streak should be reset or increased
                let now : Nat = Int.abs(Time.now());
                var new_login_streak = user.login_streak + 1;

                let new_user_info : T.UserInfo = _editUserInfo(user, null, null,  null, ?now, ?new_login_streak, null, null);

                let display_res = switch(_getDisplayTank(user.id)) {
                    case (#err(error)){ return #err(error); };
                    case (#ok(res)){ res; };
                };

                users_hash.put(u_key, new_user_info);

                let is_admin = switch(_verifyAdmin(u_key)){
                    case(#ok(res)){
                        true;
                    };
                    case(#err(error)){
                        false;
                    };
                };

                return #ok({
                    principalId = Principal.toText(u_key);
                    display_tank = display_res.tank;
                    display_fish = display_res.fish;
                    has_goldfish = display_res.has_goldfish;
                    user_info = new_user_info;
                    is_admin = is_admin;
                });
            };
        };
    };

    private func _setFishName(u_key: T.UserKey, fish_id:T.FishId, name:Text) : Result.Result<Text,T.ErrorCode> {
        switch(fish_buff.getOpt(fish_id)){
            case(null){
                return #err(#NOFISHFOUND);
            };
            case(?fish){
                let fish = fish_buff.get(fish_id);
                if(not _isOwner(u_key, fish_id)){
                    return #err(#NOTAUTHORIZED);
                };

                if(name.size() > 15){
                    return #err(#INVALIDNAME);
                };

                var new_fish = _editFish(fish, null, null, ?name, null, null, null, null);
                fish_buff.put(fish_id, new_fish);

                return #ok(name);
            };
        };
    };

    private func _donateFish(u_key: T.UserKey, fish_id:T.FishId) : async Result.Result<{fish_hat: T.HatAcc}, T.ErrorCode> {
        let fish : T.FishMetadata = switch(fish_buff.getOpt(fish_id)){
            case(null){
                return #err(#NOFISHFOUND);
            };
            case(?fish){
                fish;
            };
        };
        
        if(not _isOwner(u_key, fish_id)){
            return #err(#NOTAUTHORIZED);
        };

        if(fish.favorite == true) {
            return #err(#FISHISFAVORITED);
        };

        if(fish.soul_bound == true) {
            return #err(#FISHISSOULBOUND);
        };

        let user = switch(users_hash.get(u_key)){case(null){return #err(#NOUSERFOUND)};case(?u){u};};

        // Remove from Display tank if there
        _removeFromDisplayTank(user.id, fish_id);

        // Remove fish from user and add a random hat reward
        let new_fishIds = Array.filter(user.fish, func(id:T.FishId):Bool{ return id != fish_id});
        let new_hat = await _get_random_hat();
        let new_hats = Array.tabulate(user.fish_hats.size() + 1, func (index:Nat): T.HatAcc{
            if(index != user.fish_hats.size()){
                user.fish_hats[index];
            } else {
                new_hat;
            };
        });
        let new_user_info : T.UserInfo = _editUserInfo(user, null, ?new_fishIds, ?new_hats, null, null, null, null);
        users_hash.put(u_key, new_user_info);

        // Update fish history
        let new_transfer_event : T.TransferEvent = {
            time=Int.abs(Time.now());
            from=?fish.owner_history[fish.owner_history.size()-1].to;
            to="adoption";
        };

        let new_owner_history = Array.tabulate(fish.owner_history.size() + 1, func (index:Nat): T.TransferEvent{
            if(index != fish.owner_history.size()){
                fish.owner_history[index];
            } else {
                new_transfer_event;
            };
        });
        var new_fish = _editFish(fish, null, ?(fish.level + 1), null, ?new_owner_history, null, null, null);
        fish_buff.put(fish_id, new_fish);

        // transfer fish to adoptable fish buffer
        adoptable_fish_hash.put(fish_id,0);

        donated_fish+=1;
        return #ok({fish_hat= new_hat});
    };

    private func _unlockHatOnFish(u_key: T.UserKey, fish_id:T.FishId, hat:T.HatAcc) : async Result.Result<{fish_hats:[T.HatAcc];fishMD:T.FishMetadata}, T.ErrorCode> {
        let fish : T.FishMetadata = switch(fish_buff.getOpt(fish_id)){
            case(null){ return #err(#NOFISHFOUND); };
            case(?fish){ fish; };
        };
        
        if(not _isOwner(u_key, fish_id)){
            return #err(#NOTAUTHORIZED);
        };

        let user = switch(users_hash.get(u_key)){case(null){return #err(#NOUSERFOUND)};case(?u){u};};
        
        // Check if hat is already unlocked for this fish
        switch(Array.find(fish.unlocked_hats, func(unlocked_hat: T.HatAcc): Bool { unlocked_hat == hat;})){
            case (null) { };
            case (_) { return #err(#ALREADYUNLOCKED);};
        };

        // Remove the unlock accessory from user list
        var removed = false;
        let new_hats = Array.filter(user.fish_hats, func(u_hat:T.HatAcc):Bool{
            if(removed == true){
                return true;
            };

            let toBeRemoved: Bool = (hat == u_hat);
            if(toBeRemoved){
                removed := true;
            };

            return not toBeRemoved;
        });

        // Check an unlock was found(removed)
        if(removed == false){ return #err(#NOUNLOCKAVAILABLE) };

        let new_user_info : T.UserInfo = _editUserInfo(user, null, null, ?new_hats, null, null, null, null);
        users_hash.put(u_key, new_user_info);

        // Add the accessory to the unlocked hats array
        let new_fish_prop : T.FishProps = _editFishProperties(fish.properties, ?hat);
        let new_unlocked_hats : [T.HatAcc] = Array.tabulate(fish.unlocked_hats.size() + 1, func (index:Nat): T.HatAcc{
            if(index != fish.unlocked_hats.size()){
                fish.unlocked_hats[index];
            } else {
                hat;
            };
        });
        let new_fish : T.FishMetadata = _editFish(fish, null, null, null, null, null, null, ?new_unlocked_hats);
        fish_buff.put(fish_id, new_fish);

        return #ok({fish_hats=new_hats; fishMD=new_fish});
    };

    private func _setFishHat(u_key: T.UserKey, fish_id:T.FishId, hat:T.HatAcc) : Result.Result<T.FishMetadata, T.ErrorCode> {
        let fish : T.FishMetadata = switch(fish_buff.getOpt(fish_id)){
            case(null){ return #err(#NOFISHFOUND); };
            case(?fish){ fish; };
        };
        
        if(not _isOwner(u_key, fish_id)){
            return #err(#NOTAUTHORIZED);
        };

        let user = switch(users_hash.get(u_key)){case(null){return #err(#NOUSERFOUND)};case(?u){u};};
        
        // Check if hat is unlocked for this fish
        switch(Array.find(fish.unlocked_hats, func(unlocked_hat: T.HatAcc): Bool { unlocked_hat == hat;})){
            case (null) { return #err(#NOTUNLOCKED)};
            case (_) { };
        };

        let new_fish_prop : T.FishProps = _editFishProperties(fish.properties, ?hat);
        let new_fish : T.FishMetadata = _editFish(fish, null, null, null, null, ?new_fish_prop, null, null);
        fish_buff.put(fish_id, new_fish);

        return #ok(new_fish);
    };

    private func _toggleFavorite(u_key: T.UserKey, fish_id:T.FishId) : Result.Result<Bool,T.ErrorCode> {
        let fish = switch(fish_buff.getOpt(fish_id)){
            case(null){
                return #err(#NOFISHFOUND);
            };
            case(?fish){
                fish;
            };
        };

        if(not _isOwner(u_key, fish_id)){
            return #err(#NOTAUTHORIZED);
        };

        var new_fish = _editFish(fish, ?(not fish.favorite), null, null, null, null, null, null);
        fish_buff.put(fish_id, new_fish);

        return #ok(new_fish.favorite);
    };

    private func _editFish(existing: T.FishMetadata, favorite:?Bool, level:?Nat, name:?Text, owner_history:?[T.TransferEvent], 
    properties:?T.FishProps, soul_bound:?Bool, unlocked_hats:?[T.HatAcc]) : T.FishMetadata {
        let new_fish : T.FishMetadata =  {
            favorite = switch(favorite){ case(null){existing.favorite}; case(?n){ n };};
            level = switch(level){ case(null){ existing.level }; case(?n){ n };};
            name = switch(name){ case(null){ existing.name }; case(?n){ n };};
            owner_history = switch(owner_history){ case(null){ existing.owner_history }; case(?n){ n };};
            properties = switch(properties){ case(null){ existing.properties }; case(?n){ n };};
            soul_bound = switch(soul_bound){ case(null){existing.soul_bound}; case(?n){ n };};
            unlocked_hats = switch(unlocked_hats){ case(null){existing.unlocked_hats}; case(?n){ n };};
        };

        return new_fish;
    };

    private func _editUserInfo(existing: T.UserInfo, achievements: ?[Text], fish: ?[T.FishId], fish_hats: ?[T.HatAcc],
    last_login: ?Nat, login_streak: ?Nat, tank_accs : ?[Text], wallets: ?[{id:Principal; wallet: Text}] ) : T.UserInfo{
        let new_user_info : T.UserInfo = {
            achievements = switch(achievements){ case(null){existing.achievements}; case(?n){ n };};
            created_date = existing.created_date;
            fish = switch(fish){ case(null){existing.fish}; case(?n){ n };};
            fish_hats = switch(fish_hats){ case(null){existing.fish_hats}; case(?n){ n };};
            id = existing.id;
            last_login = switch(last_login){ case(null){existing.last_login}; case(?n){ n };};
            login_streak = switch(login_streak){ case(null){existing.login_streak}; case(?n){ n };};
            tank_accs = switch(tank_accs){ case(null){existing.tank_accs}; case(?n){ n };};
            wallets = switch(wallets){ case(null){existing.wallets}; case(?n){ n };};
        };

        return new_user_info;
    };

    private func _editFishProperties(existing: T.FishProps, hat: ?T.HatAcc ) : T.FishProps{
        let new_fish_props : T.FishProps = {
            hat = switch(hat){ case(null){existing.hat}; case(?n){ n };};
            body_type = existing.body_type;
            color_1 = existing.color_1;
            color_2 = existing.color_2;
            color_3 = existing.color_3;
            eye_color = existing.eye_color;
            size = existing.size;
            speed = existing.speed;
        };

        return new_fish_props;
    };
    
    private func _isOwner(u_key: T.UserKey, fish_id: T.FishId) : Bool  {
        switch(users_hash.get(u_key)){
            case(null){
                _log("user not found in isOwner");
                return false;
            };
            case(?user){
                switch(Array.find<T.FishId>(user.fish,func(user_fish_id:T.FishId){
                    return fish_id == user_fish_id;
                })){
                    case(null){ _log("User is not the owner in isOwner"); return false; };
                    case(_){ return true; };
                };
            };
        };
    };

    private func _getRandomTank() : async Result.Result<{tank:T.DisplayTank;fish:[T.FishMetadata];has_goldfish:Bool},T.ErrorCode> {
        if(display_tank_buff.size() < 1 ){
            return #err(#NOUSERFOUND);
        };

        var display_tank_index : Nat = await _largerand(display_tank_buff.size());
        // _log("Random display tank Index: " # Nat.toText(display_tank_index) # "/" # Nat.toText(display_tank_buff.size()));

        return _getDisplayTank(display_tank_index);
    };

    private func _airdropGoldfish(drop_percent: Float) : async Result.Result<Text, T.ErrorCode>{
        // need to clear old airdrop hash
        for(k in goldfishAirDrops.keys()) { goldfishAirDrops.delete(k); };

        let p_array = Iter.toArray(users_hash.keys());

        // get updated count to be dropped
        var airdropcount : Nat = Int.abs(Float.toInt(Float.ceil(Float.fromInt(p_array.size()) * drop_percent)));

        while ( goldfishAirDrops.size() < airdropcount) {
            var index : Nat = await _largerand(p_array.size());
            let u_id = switch(users_hash.get(p_array[index])){case(null){return #err(#NOUSERFOUND)}; case(?u){u.id;};};
            switch(goldfishAirDrops.get(u_id)){
                case(null){
                    goldfishAirDrops.put(u_id, true);
                };
                case(?ad){
                    _log("Duplicate airdrop profile generated:" # Nat.toText(u_id));
                };
            };
        };

        return #ok("");
    };

    private func _tradeGoldfish(p : Principal) : async Result.Result<{fishId:T.FishId; metadata:T.FishMetadata},T.ErrorCode> {
        let u_id = switch(users_hash.get(p)){case(null){return #err(#NOUSERFOUND)}; case(?u){u.id;};};
        var airDrop: ?Bool = goldfishAirDrops.get(u_id);
        switch(airDrop){
            case(null){
                return #err(#NOGOLDFISH);
            };
            case(?aD){
                if(aD == false){
                    return #err(#GOLDFISHCLAIMED);
                };

                // claim the fish
                goldfishAirDrops.put(u_id,false);
                return await _mint(p, true);
            };
        };
    };

    /*private func _allOwnedTokens(p : Principal) : {fish:[{id:T.TokenId; metadata:T.TokenMetadata}]; hasGoldfish: Bool} {
        var ret_arr: [var {id:T.TokenId; metadata:T.TokenMetadata}] = [var];
        switch(balances.get(p)){
            case(null){
            };
            case(?n){
                ret_arr := Array.init<{id:T.TokenId; metadata:T.TokenMetadata}>(n, {
                    id=0;
                    metadata={
                        minted_at = 0;
                        minted_by = p;
                        properties: T.TokenProps = {
                            color_1 = "";
                            color_2 = "";
                            color_3 = "";
                        };
                        transferrable = false;
                        transferred_by = null;
                        transferred_at = null;
                    }}
                );
            };
        };
            
        var count: Nat = 0;
        Iter.iterate(owners.entries(), func((k : T.TokenId, v : Principal), index: Nat) {
            if(Principal.equal(p,v)){
                switch(tokenFishes.get(k)){
                    case(null){};
                    case(?md){
                        ret_arr[count] := {id=k;metadata=md};
                        count+=1;
                    };
                };
            };
        });

        var has_gold_fish : Bool = false;
        
        switch(goldfishAirDrops.get(p)){
            case(null){
                _log("no goldfish record");
            };
            case(?hasgf){
                _log("has goldfish record");
                has_gold_fish:= hasgf;
            };
        };
        return {fish=(Array.freeze(ret_arr)); hasGoldfish=has_gold_fish};
    };*/

    /*

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
    */

    private func _mint(u_key : T.UserKey, soul_bound : Bool) : async Result.Result<{fishId:T.FishId; metadata:T.FishMetadata}, T.ErrorCode> {
        let id = fish_buff.size();
        let fish: T.FishMetadata = {
            favorite = false;
            level = 0;
            name = "";
            owner_history = Array.make<T.TransferEvent>({
                from = null;
                to = Principal.toText(u_key);
                time = Int.abs(Time.now());
            });
            properties: T.FishProps = {
                hat = #NONE;
                body_type = #GOLDFISH;
                color_1 = await _get_random_color1();
                color_2 = await _get_random_color2();
                color_3 = await _get_random_color3();
                eye_color = await _get_random_eyecolor();
                speed = await _get_random_speed();
                size = await _get_random_size();
            };
            soul_bound = soul_bound;
            unlocked_hats = [#NONE];
        };

        // need to add metadata to fish
        // add fish to users fish list
        // add fish to display tank
        fish_buff.add(fish);
        let user = switch(users_hash.get(u_key)){case(null){return #err(#NOUSERFOUND)};case(?u){u};};
        let new_fish = Array.tabulate(user.fish.size() + 1, func (index:Nat): T.FishId{
            if(index != user.fish.size()){
                user.fish[index];
            } else {
                id;
            };
        });
        let new_user_info : T.UserInfo = _editUserInfo(user, null, ?new_fish,  null, null, null, null, null);
        users_hash.put(u_key, new_user_info);
        _addToDisplayTank(new_user_info.id, id);
        
        return #ok({fishId=id; metadata=fish});
    };

    private func _log(msg: Text) : () {
        Debug.print(msg);
        logs:= logs # "\n" # msg;
    };

    private func _largerand(max: Nat) : async Nat{
        return await _rand(max, 31, 2147483647);
    };

    private func _smallrand(max: Nat) : async Nat{
        return await _rand(max, 7, 127);
    };

    private func _rand(max: Nat, range_p: Nat8, maxRand: Float) : async Nat{
        // let range_p : Nat8 = 7;

        var next: ?Nat = finite.range(range_p);
        if(next == null){
            var b: Blob = await Random.blob();
            finite := Random.Finite(b);
            next := finite.range(range_p);
            Debug.print("created new Finite");
        };

        Debug.print("rand: " # Nat.toText(Option.get(next, 0)));

        // let maxRand : Float = 127;
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

    private func _get_random_eyecolor() : async Text {
        let i : Nat = await _smallrand(colors_for_eyes.size());
        return (colors_for_eyes[i]);
    };

    private func _get_random_tankcolor() : async Text {
        let i : Nat = await _smallrand(colors_for_tank.size());
        return (colors_for_tank[i]);
    };

    private func _get_random_speed() : async T.FishSpeed {
        let i : Nat = await _smallrand(speed_for_fish.size());
        return (speed_for_fish[i]);
    };

    private func _get_random_size() : async T.FishSize {
        let i : Nat = await _smallrand(sizes_for_fish.size());
        return (sizes_for_fish[i]);
    };

    private func _get_random_hat() : async T.HatAcc {
        let i : Nat = await _smallrand(hats_for_fish.size());
        return (hats_for_fish[i]);
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

    private let colors_for_eyes : [Text] = [
        "#e61919",
        "#0dbd25",
        "#0d48bd",
        "#a80dbd",
        "#000000",
        "#c0c0c0",
        "#E0AA3E"
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

    private let sizes_for_fish : [T.FishSize] = [
        #SMALL,
        #AVERAGE,
        #AVERAGE,
        #AVERAGE,
        #LARGE
    ];

    private let speed_for_fish : [T.FishSpeed] = [
        #SLOW,
        #AVERAGE,
        #AVERAGE,
        #AVERAGE,
        #FAST
    ];

    private let hats_for_fish : [T.HatAcc] = [
        #PARTY,
        #STRAW
    ];

    private func _exportBackup(): Result.Result<T.Backup, T.ErrorCode>{
        let users : [(T.UserKey, T.UserInfo)] = Iter.toArray(users_hash.entries());
        let export_users : [(Text, T.UserInfo)] = Array.tabulate<(Text,T.UserInfo)>(users.size(), func(index: Nat){
            return (Principal.toText(users[index].0),users[index].1);
        });

        let export_donate_key : ?Text = switch(donateKey){
            case(null){ null };
            case(?d){
                ?Principal.toText(d);
            };
        };

        return #ok({
            userEntries = export_users;
            fishEntries = fish_buff.toArray();
            userIdKeyEntries = userIdKey_buff.toArray();
            displayTankEntries = display_tank_buff.toArray();
            stakingTankEntries = staking_tank_buff.toArray();
            goldfishAirDropEntries = Iter.toArray(goldfishAirDrops.entries());
            adoptableFishEntries = Iter.toArray(adoptable_fish_hash.entries());
            adopted_fish = adopted_fish;
            donated_fish = donated_fish;
            donateKey = export_donate_key;
            adminsEntries = adminsEntries;
            logs = logs;
        });
    };

    private func _importBackup(backup: T.Backup): Result.Result<Text,T.ErrorCode> {
        for(key in users_hash.keys()){ users_hash.delete(key); };
        for(val in backup.userEntries.vals()){ users_hash.put(Principal.fromText(val.0),val.1); };

        for(key in goldfishAirDrops.keys()){ goldfishAirDrops.delete(key); };
        for(val in backup.goldfishAirDropEntries.vals()){ goldfishAirDrops.put(val.0,val.1); };

        for(key in adoptable_fish_hash.keys()){ adoptable_fish_hash.delete(key); };
        for(val in backup.adoptableFishEntries.vals()){ adoptable_fish_hash.put(val.0,val.1); };

        fish_buff.clear();
        for (fish in backup.fishEntries.vals()) { fish_buff.add(fish); };
        userIdKey_buff.clear();
        for (idkey in backup.userIdKeyEntries.vals()) { userIdKey_buff.add(idkey); };
        display_tank_buff.clear();
        for (tank in backup.displayTankEntries.vals()) { display_tank_buff.add(tank); };
        staking_tank_buff.clear();
        for (tank in backup.stakingTankEntries.vals()) { staking_tank_buff.add(tank); };

        adopted_fish := backup.adopted_fish;
        donated_fish := backup.donated_fish;
        adminsEntries := backup.adminsEntries;
        switch(backup.donateKey){
            case(null){ };
            case(?d){
                donateKey := ?Principal.fromText(d);
            };
        };
        logs := backup.logs;

        return #ok("imported backup");
    };

    system func preupgrade() {
        fishEntries := fish_buff.toArray();
        userIdKeyEntries := userIdKey_buff.toArray();
        displayTankEntries := display_tank_buff.toArray();
        stakingTankEntries := staking_tank_buff.toArray();
        userEntries := Iter.toArray(users_hash.entries());
        goldfishAirDropEntries := Iter.toArray(goldfishAirDrops.entries());
        adoptableFishEntries := Iter.toArray(adoptable_fish_hash.entries());
    };

    system func postupgrade() {
        for (fish in fishEntries.vals()) {
            fish_buff.add(fish);
        };
        fishEntries := [];

        for (idkey in userIdKeyEntries.vals()) {
            userIdKey_buff.add(idkey);
        };
        userIdKeyEntries := [];

        for (disp in displayTankEntries.vals()) {
            display_tank_buff.add(disp);
        };
        displayTankEntries := [];

        for (stor in stakingTankEntries.vals()) {
            staking_tank_buff.add(stor);
        };
        stakingTankEntries := [];
        
        userEntries := [];
        goldfishAirDropEntries := [];
        adoptableFishEntries := [];
    };
};