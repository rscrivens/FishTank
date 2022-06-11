import Principal "mo:base/Principal";

module {
    public type UserKey = Principal;
    public type UserId  = Nat;
    public type FishId = Nat;

    public type LoggedInUserDetails = {
        principalId         : Text;
        display_tank        : DisplayTank;
        display_fish        : [FishMetadata];
        has_goldfish        : Bool;
        user_info           : UserInfo;
        is_admin            : Bool;
    };

    public type UserInfo = {
        id                  : UserId;
        achievements        : [Text];
        created_date        : Nat;
        fish                : [FishId];
        fish_accs           : [Text];
        tank_accs           : [Text];
        wallets             : [{wallet:Text; id:Principal}];
        last_login          : Nat;
        login_streak        : Nat;
    };

    public type FishMetadata = {
        favorite            : Bool;
        level               : Nat;
        name                : Text;
        owner_history       : [TransferEvent];
        properties          : FishProps;
        transferrable       : Bool;
    };

    public type TransferEvent = {
        time                : Nat;
        from                : ?UserKey;
        to                  : UserKey;
    };

    public type FishProps = {
        acc_hat             : Text;
        body_type           : BodyType;
        color_1             : Text;
        color_2             : Text;
        color_3             : Text;
        eye_color           : Text;
        speed               : Nat;
        size                : Nat;
    };

    public type BodyType = {
        #GOLDFISH;
    };

    public type DisplayTank = {
        fish                : [FishId];
        color_bottom        : Text;
        color_bg            : Text;
        acc_left            : Text;
        acc_right           : Text;
        effect              : Text;
    };

    public type StorageTank = {
        fish                : [FishId];
    };

    public type Backup = {
        fishEntries             : [FishMetadata];
        displayTankEntries      : [DisplayTank];
        storageTankEntries      : [StorageTank];
        userEntries             : [(UserKey, UserInfo)];
        goldfishAirDropEntries  : [(UserId, Bool)];
        adoptableFishEntries    : [(FishId, Nat)];

        adminsEntries           : [Text];
        donateKey               : ?Principal;
        logs                    : Text;
    };

    public type ErrorCode = {
        #GOLDFISHCLAIMED;
        #NOGOLDFISH;
        #NOUSERFOUND;
        #NOFISHFOUND;
        #LOGINREQUIRED;
        #NOTAUTHORIZED;
        #NOTYETIMPLEMENTED;
        #INVALIDNAME;
    };
}