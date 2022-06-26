import Principal "mo:base/Principal";

module {
    public type UserKey = Principal;
    public type UserId  = Nat;
    public type FishId = Nat;

    public type ServerStats = {
        users               : Nat;
        minted_fish         : Nat;
        donated_fish        : Nat;
        adopted_fish        : Nat;
        adoptable_fish      : Nat;
    };

    public type LoggedInUserDetails = {
        principalId         : Text;
        display_tank        : DisplayTank;
        display_fish        : [FishMetadata];
        has_goldenfish        : Bool;
        user_info           : UserInfo;
        is_admin            : Bool;
    };

    public type UserInfo = {
        id                  : UserId;
        achievements        : [Text];
        created_date        : Nat;
        fish                : [FishId];
        fish_hats           : [HatAcc];
        tank_accs           : [Text];
        wallets             : [{wallet:Text; id:Principal}];
        last_login          : Nat;
        login_streak        : Nat;
        num_minted          : Nat;
        num_donated         : Nat;
        num_adopted         : Nat;
    };

    public type UserInfoVariant = {
        #USERINFO_ACHIEVEMENTS  : [Text];
        #USERINFO_FISH          : [FishId];
        #USERINFO_FISH_HATS     : [HatAcc];
        #USERINFO_TANK_ACCS     : [Text];
        #USERINFO_WALLETS       : [{wallet:Text; id:Principal}];
        #USERINFO_LAST_LOGIN    : Nat;
        #USERINFO_LOGIN_STREAK  : Nat;
        #USERINFO_NUM_MINTED    : Nat;
        #USERINFO_NUM_DONATED   : Nat;
        #USERINFO_NUM_ADOPTED   : Nat;
    };

    public type UserInfoOld = {
        id                  : UserId;
        achievements        : [Text];
        created_date        : Nat;
        fish                : [FishId];
        fish_hats           : [HatAcc];
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
        unlocked_hats       : [HatAcc];
    };

    public type FishMetadataVariant = {
        #FISHMD_FAVORITE        : Bool;
        #FISHMD_LEVEL           : Nat;
        #FISHMD_NAME            : Text;
        #FISHMD_OWNER_HISTORY   : [TransferEvent];
        #FISHMD_PROPERTIES      : FishProps;
        #FISHMD_UNLOCKED_HATS   : [HatAcc]
    };

    public type TransferEvent = {
        time                : Nat;
        from                : ?Text;
        to                  : Text;
    };

    public type FishProps = {
        hat                 : HatAcc;
        body_type           : BodyType;
        color_1             : Text;
        color_2             : Text;
        color_3             : Text;
        eye_color           : Text;
        speed               : FishSpeed;
        size                : FishSize;
    };

    public type FishPropsVariant = {
        #FISHPROP_HAT: HatAcc;
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

    public type HatAcc = {
        #NONE;
        #PARTY;
        #STRAW;
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

    public type DisplayTankVariant = {
        #DISPLAYTANK_FISH           : [FishId];
        #DISPLAYTANK_COLOR_BOTTOM   : Text;
        #DISPLAYTANK_COLOR_BG       : Text;
        #DISPLAYTANK_ACC_LEFT       : Text;
        #DISPLAYTANK_ACC_RIGHT      : Text;
        #DISPLAYTANK_EFFECT         : Text;
    };

    public type StakingTank = {
        fish                : [FishId];
        color_bottom        : Text;
        color_bg            : Text;
        acc_left            : Text;
        acc_right           : Text;
        effect              : Text;
    };

    public type StakingTankVariant = {
        #STAKINGTANK_FISH           : [FishId];
        #STAKINGTANK_COLOR_BOTTOM   : Text;
        #STAKINGTANK_COLOR_BG       : Text;
        #STAKINGTANK_ACC_LEFT       : Text;
        #STAKINGTANK_ACC_RIGHT      : Text;
        #STAKINGTANK_EFFECT         : Text;
    };

    public type Backup = {
        fishEntries             : [FishMetadata];
        userIdKeyEntries        : [Text];
        displayTankEntries      : [DisplayTank];
        stakingTankEntries      : [StakingTank];
        userEntries             : [(Text, UserInfo)];
        goldenfishAirDropEntries: [(UserId, Bool)];
        adoptableFishEntries    : [(FishId, Nat)];

        donated_fish            : Nat;
        adopted_fish            : Nat;

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
        #ALREADYUNLOCKED;
        #NOTUNLOCKED;
        #NOUNLOCKAVAILABLE;
    };
};