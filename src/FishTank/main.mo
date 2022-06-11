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
    private stable var workaround : [(T.FishProps, T.TransferEvent, T.BodyType, T.UserId)] = [];

    private stable var fishEntries : [T.FishMetadata] = [];
    private stable var userEntries : [(T.UserKey, T.UserInfo)] = [];
    private stable var displayTankEntries : [T.DisplayTank] = [];
    private stable var storageTankEntries : [T.StorageTank] = [];
    private stable var goldfishAirDropEntries : [(T.UserId, Bool)] = [];
    private stable var adoptableFishEntries: [(T.FishId, Nat)] = [];

    private let fish_buff = Buffer.Buffer<T.FishMetadata>(0);
    private let display_tank_buff = Buffer.Buffer<T.DisplayTank>(0);
    private let storage_tank_buff = Buffer.Buffer<T.StorageTank>(0);
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

    public shared query func getOwner(fishId : T.FishId) : async Result.Result<T.UserKey,T.ErrorCode> {
        return _getOwner(fishId);
    };

    public shared query func getStorageTank(u_id : T.UserId) : async Result.Result<{tank:T.StorageTank;fish:[T.FishMetadata]},T.ErrorCode> {
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
    public shared(msg) func addToDisplayTank(fishId:T.FishId) : async Result.Result<Text,T.ErrorCode>{
        if(Principal.isAnonymous(msg.caller)) {
            return #err(#LOGINREQUIRED);
        };
        
        return _addToDisplayTank(msg.caller, fishId);
    };

    public shared(msg) func addToStorageTank(fishId:T.FishId) : async Result.Result<Text,T.ErrorCode>{
        if(Principal.isAnonymous(msg.caller)) {
            return #err(#LOGINREQUIRED);
        };

        return _addToStorageTank(msg.caller, fishId);
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
/*
    public shared(msg) func donate(fishId:T.FishId) : async Result.Result<{fish_acc: Text},T.ErrorCode>{
        if(Principal.isAnonymous(msg.caller)) {
            return #err(#LOGINREQUIRED);
        };

        return await _donate(msg.caller, fishId);
    };
*/

    public shared (msg) func createNewUser() : async Result.Result<T.LoggedInUserDetails,T.ErrorCode>{
        if(Principal.isAnonymous(msg.caller)) {
            return #err(#LOGINREQUIRED);
        };

        var new_user = _createNewUser(msg.caller);
        return _login(msg.caller);
    };

    public shared func getRandomTank() : async Result.Result<{tank:T.DisplayTank;fish:[T.FishMetadata];has_goldfish:Bool},T.ErrorCode> {
        return await _getRandomTank();
    };

    public shared(msg) func mint() : async Result.Result<{fishId:T.FishId; metadata:T.FishMetadata},T.ErrorCode>{
        if(Principal.isAnonymous(msg.caller)) {
            return #err(#LOGINREQUIRED);
        };

        _log("Trying to mint: " # Principal.toText(msg.caller));

        // Need to implement payment before minting

        return await _mint(msg.caller, true);
    };

    public shared(msg) func setFishName(fishId:T.FishId, name:Text) : async Result.Result<Text,T.ErrorCode>{
        if(Principal.isAnonymous(msg.caller)) {
            return #err(#LOGINREQUIRED);
        };

        return _setFishName(msg.caller, fishId, name);
    };

    public shared(msg) func toggleFavorite(fishId:T.FishId) : async Result.Result<Text,T.ErrorCode>{
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
                storage_tank_buff.clear();

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

    private func _getOwner(fishId : T.FishId) : Result.Result<T.UserKey, T.ErrorCode> {
        switch(fish_buff.getOpt(fishId)){
            case(null){
                return #err(#NOFISHFOUND);
            };
            case(?fish){
                return #ok(fish.owner_history[fish.owner_history.size()].to);
            };
        };
    };

    private func _getStorageTank(u_id : T.UserId) : Result.Result<{tank:T.StorageTank;fish:[T.FishMetadata]},T.ErrorCode> {
        switch(storage_tank_buff.getOpt(u_id)){
            case(null){
                return #err(#NOUSERFOUND);
            };
            case(?storage_tank){

                let fish_metadata:[T.FishMetadata] = _getFishMetadata(storage_tank.fish);
                return #ok({tank=storage_tank;fish=fish_metadata});
            };
        };
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

    private func _addToDisplayTank(u_key: T.UserKey, fishId: T.FishId) : Result.Result<Text, T.ErrorCode>{
        if(_isOwner(u_key, fishId)){
            return #err(#NOTAUTHORIZED);
        };

        switch(users_hash.get(u_key)){
            case (null){
                return #err(#NOUSERFOUND);
            };
            case (?user){
                // Remove from storage tank
                let new_storage_fish = Array.filter(storage_tank_buff.get(user.id).fish, func(id:T.FishId):Bool{ return id != fishId});
                let new_storage_tank : T.StorageTank = {
                    fish = new_storage_fish;
                };
                storage_tank_buff.put(user.id, new_storage_tank);

                // Add to display tank if not already in there
                let cur_display_tank = display_tank_buff.get(user.id);
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

                        display_tank_buff.put(user.id, new_display_tank);
                        return #ok("Added");
                    };
                    case(_){
                        return #ok("Already added");
                    };
                };
            };
        };
    };

    private func _addToStorageTank(u_key: T.UserKey, fishId: T.FishId) : Result.Result<Text, T.ErrorCode>{
        if(_isOwner(u_key, fishId)){
            return #err(#NOTAUTHORIZED);
        };

        switch(users_hash.get(u_key)){
            case (null){
                return #err(#NOUSERFOUND);
            };
            case (?user){
                // Remove from display tank
                let cur_display_tank = display_tank_buff.get(user.id);
                let new_display_fish = Array.filter(cur_display_tank.fish, func(id:T.FishId):Bool{ return id != fishId});
                let new_display_tank : T.DisplayTank = {
                    acc_left = cur_display_tank.acc_left;
                    acc_right = cur_display_tank.acc_right;
                    color_bg = cur_display_tank.color_bg;
                    color_bottom = cur_display_tank.color_bottom;
                    effect = cur_display_tank.effect;
                    fish = new_display_fish;
                };
                display_tank_buff.put(user.id, new_display_tank);

                // Add to storage tank if not already in there
                let cur_storage_tank = storage_tank_buff.get(user.id);
                let cur_storage_fish = cur_storage_tank.fish;
                switch(Array.find(cur_storage_fish, func(id: T.FishId):Bool{ id == fishId; })){
                    case (null){
                        let new_storage_fish : Buffer.Buffer<T.FishId> = Buffer.Buffer(cur_storage_fish.size() + 1);
                        for (x in cur_storage_fish.vals()) {
                            new_storage_fish.add(x);
                        };
                        new_storage_fish.add(fishId);

                        let new_storage_tank : T.StorageTank = {
                            fish = new_storage_fish.toArray();
                        };

                        storage_tank_buff.put(user.id, new_storage_tank);
                        return #ok("Added");
                    };
                    case(_){
                        return #ok("Already added");
                    };
                };
            };
        };
    };

    private func _createNewUser(u_key: T.UserKey) : async T.UserInfo {
        let new_user : T.UserInfo = {
            id = users_hash.size();
            achievements = [];
            created_date = Int.abs(Time.now());
            fish = [];
            fish_accs = [];
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

        let new_storage_tank: T.StorageTank = {
            fish = [];
        };

        users_hash.put(u_key, new_user);
        display_tank_buff.add(new_display_tank);
        storage_tank_buff.add(new_storage_tank);

        goldfishAirDrops.put(new_user.id, true);
        _log("Added goldfish record with true");
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
                if(_isOwner(u_key, fish_id)){
                    return #err(#NOTAUTHORIZED);
                };

                if(name.size() > 15){
                    return #err(#INVALIDNAME);
                };

                var new_fish = _editFish(fish, null, null, ?name, null, null, null);
                fish_buff.put(fish_id, new_fish);

                return #ok(name);
            };
        };
    };

    private func _toggleFavorite(u_key: T.UserKey, fish_id:T.FishId) : Result.Result<Text,T.ErrorCode> {
        switch(fish_buff.getOpt(fish_id)){
            case(null){
                return #err(#NOFISHFOUND);
            };
            case(?fish){
                if(_isOwner(u_key, fish_id)){
                    return #err(#NOTAUTHORIZED);
                };

                var new_fish = _editFish(fish, ?(not fish.favorite), null, null, null, null, null);
                fish_buff.put(fish_id, new_fish);

                return #ok("Favorited = " # Bool.toText(new_fish.favorite));
            };
        };
    };

    private func _editFish(existing: T.FishMetadata, favorite:?Bool, level:?Nat, name:?Text, owner_history:?[T.TransferEvent], 
    properties:?T.FishProps, transferrable:?Bool) : T.FishMetadata {
        /*
        var new_favorite : Bool = switch(favorite){ case(null){existing.favorite}; case(?n){ n };};
        var new_level : Nat = switch(level){ case(null){ existing.level }; case(?n){ n };};
        var new_name : Text =  switch(name){ case(null){ existing.name }; case(?n){ n };};
        var new_owner_history : [T.TransferEvent] = switch(owner_history){ case(null){ existing.owner_history }; case(?n){ n };};
        var new_properties : T.FishProps = switch(properties){ case(null){ existing.properties }; case(?n){ n };};
        var new_transferrable : Bool = switch(transferrable){ case(null){existing.transferrable}; case(?n){ n };};
*/
        let new_fish : T.FishMetadata =  {
            favorite = switch(favorite){ case(null){existing.favorite}; case(?n){ n };};
            level = switch(level){ case(null){ existing.level }; case(?n){ n };};
            name = switch(name){ case(null){ existing.name }; case(?n){ n };};
            owner_history = switch(owner_history){ case(null){ existing.owner_history }; case(?n){ n };};
            properties = switch(properties){ case(null){ existing.properties }; case(?n){ n };};
            transferrable = switch(transferrable){ case(null){existing.transferrable}; case(?n){ n };};
        };

        return new_fish;
    };

    private func _editUserInfo(existing: T.UserInfo, achievements: ?[Text]/*achivements*/, fish: ?[T.FishId], fish_accs: ?[Text],
    last_login: ?Nat, login_streak: ?Nat, tank_accs : ?[Text], wallets: ?[{id:Principal; wallet: Text}] ) : T.UserInfo{
        let new_user_info : T.UserInfo = {
            achievements = switch(achievements){ case(null){existing.achievements}; case(?n){ n };};
            created_date = existing.created_date;
            fish = switch(fish){ case(null){existing.fish}; case(?n){ n };};
            fish_accs = switch(fish_accs){ case(null){existing.fish_accs}; case(?n){ n };};
            id = existing.id;
            last_login = switch(last_login){ case(null){existing.last_login}; case(?n){ n };};
            login_streak = switch(login_streak){ case(null){existing.login_streak}; case(?n){ n };};
            tank_accs = switch(tank_accs){ case(null){existing.tank_accs}; case(?n){ n };};
            wallets = switch(wallets){ case(null){existing.wallets}; case(?n){ n };};
        };

        return new_user_info;
    };
    
    private func _isOwner(u_key: T.UserKey, fish_id: T.FishId) : Bool  {
        var fish = fish_buff.get(fish_id);
        return Principal.equal(u_key, fish.owner_history[fish.owner_history.size()].to)
    };

    private func _getRandomTank() : async Result.Result<{tank:T.DisplayTank;fish:[T.FishMetadata];has_goldfish:Bool},T.ErrorCode> {
        if(display_tank_buff.size() < 1 ){
            return #err(#NOUSERFOUND);
        };

        var display_tank_index : Nat = await _largerand(display_tank_buff.size());
        _log("Random display tank Index: " # Nat.toText(display_tank_index) # "/" # Nat.toText(display_tank_buff.size()));

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
                return await _mint(p, false);
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

    private func _mint(to : Principal, transferrable : Bool) : async Result.Result<{fishId:T.FishId; metadata:T.FishMetadata}, T.ErrorCode> {
        let id = fish_buff.size();
        let fish: T.FishMetadata = {
            favorite = false;
            level = 0;
            name = "";
            owner_history = Array.make<T.TransferEvent>({
                from = null;
                to = to;
                time = Int.abs(Time.now());
            });
            properties: T.FishProps = {
                acc_hat = "";
                body_type = #GOLDFISH;
                color_1 = await _get_random_color1();
                color_2 = await _get_random_color2();
                color_3 = await _get_random_color3();
                eye_color = "";
                speed = await _get_random_speed();
                size = await _get_random_size();
            };
            transferrable = transferrable;
        };

        // need to add metadata to fish
        // add fish to users fish list
        // add fish to display tank
        fish_buff.add(fish);
        
        let result = _addToDisplayTank(to, id);        
        
        return #ok({fishId=id; metadata=fish});
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

    private func _get_random_speed() : async Nat {
        return (100);
    };

    private func _get_random_size() : async Nat {
        return (100);
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

    private func _exportBackup(): Result.Result<T.Backup, T.ErrorCode>{
        return #ok({
            userEntries = Iter.toArray(users_hash.entries());
            fishEntries = fish_buff.toArray();
            displayTankEntries = display_tank_buff.toArray();
            storageTankEntries = storage_tank_buff.toArray();
            goldfishAirDropEntries = Iter.toArray(goldfishAirDrops.entries());
            adoptableFishEntries = Iter.toArray(adoptable_fish_hash.entries());
            donateKey = donateKey;
            adminsEntries = adminsEntries;
            logs = logs;
        });
    };

    private func _importBackup(backup: T.Backup): Result.Result<Text,T.ErrorCode> {
        for(key in users_hash.keys()){ users_hash.delete(key); };
        for(val in backup.userEntries.vals()){ users_hash.put(val.0,val.1); };

        for(key in goldfishAirDrops.keys()){ goldfishAirDrops.delete(key); };
        for(val in backup.goldfishAirDropEntries.vals()){ goldfishAirDrops.put(val.0,val.1); };

        for(key in adoptable_fish_hash.keys()){ adoptable_fish_hash.delete(key); };
        for(val in backup.adoptableFishEntries.vals()){ adoptable_fish_hash.put(val.0,val.1); };

        fish_buff.clear();
        for (fish in backup.fishEntries.vals()) { fish_buff.add(fish); };
        display_tank_buff.clear();
        for (tank in backup.displayTankEntries.vals()) { display_tank_buff.add(tank); };
        storage_tank_buff.clear();
        for (tank in backup.storageTankEntries.vals()) { storage_tank_buff.add(tank); };

        adminsEntries := backup.adminsEntries;
        donateKey := backup.donateKey;

        return #ok("imported backup");
    };

    system func preupgrade() {
        fishEntries := fish_buff.toArray();
        displayTankEntries := display_tank_buff.toArray();
        storageTankEntries := storage_tank_buff.toArray();
        userEntries := Iter.toArray(users_hash.entries());
        goldfishAirDropEntries := Iter.toArray(goldfishAirDrops.entries());
        adoptableFishEntries := Iter.toArray(adoptable_fish_hash.entries());
    };

    system func postupgrade() {
        for (fish in fishEntries.vals()) {
            fish_buff.add(fish);
        };
        fishEntries := [];

        for (disp in displayTankEntries.vals()) {
            display_tank_buff.add(disp);
        };
        displayTankEntries := [];

        for (stor in storageTankEntries.vals()) {
            storage_tank_buff.add(stor);
        };
        storageTankEntries := [];
        
        userEntries := [];
        goldfishAirDropEntries := [];
        adoptableFishEntries := [];
    };
};