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
        soul_bound          : Bool;
    };

    public type TransferEvent = {
        time                : Nat;
        from                : ?Text;
        to                  : Text;
    };

    public type FishProps = {
        acc_hat             : Text;
        body_type           : BodyType;
        color_1             : Text;
        color_2             : Text;
        color_3             : Text;
        eye_color           : Text;
        speed               : FishSpeed;
        size                : FishSize;
    };

    public type FishSpeed = {
        #SLOW;
        #AVERAGE;
        #FAST;
    };

    public type FishSize = {
        #SMALL;
        #AVERAGE;
        #LARGE;
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

    public type StakingTank = {
        fish                : [FishId];
        color_bottom        : Text;
        color_bg            : Text;
        acc_left            : Text;
        acc_right           : Text;
        effect              : Text;
    };

    public type Backup = {
        fishEntries             : [FishMetadata];
        userIdKeyEntries        : [Text];
        displayTankEntries      : [DisplayTank];
        stakingTankEntries      : [StakingTank];
        userEntries             : [(Text, UserInfo)];
        goldfishAirDropEntries  : [(UserId, Bool)];
        adoptableFishEntries    : [(FishId, Nat)];

        adminsEntries           : [Text];
        donateKey               : ?Text;
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
        #FISHISFAVORITED;
        #FISHISSOULBOUND;
    };
};