import T "types";

module {
    public func _editFish(existing: T.FishMetadata, new_vals: [T.FishMetadataVariant]) : T.FishMetadata {
        var favorite = existing.favorite;
        var level = existing.level;
        var name = existing.name;
        var owner_history = existing.owner_history;
        var properties = existing.properties;
        var soul_bound = existing.soul_bound;
        var unlocked_hats = existing.unlocked_hats;

        for(new_val in new_vals.vals()){
            switch(new_val){
                case(#FISHMD_FAVORITE(val)){ favorite:=val;};
                case(#FISHMD_LEVEL(val)){ level:=val;};
                case(#FISHMD_NAME(val)){ name:=val;};
                case(#FISHMD_OWNER_HISTORY(val)){ owner_history:=val;};
                case(#FISHMD_PROPERTIES(val)){ properties:=val;};
                case(#FISHMD_UNLOCKED_HATS(val)){ unlocked_hats:=val;};
            };
        };

        return {
            favorite = favorite;
            level = level;
            name = name;
            owner_history = owner_history;
            properties = properties;
            soul_bound = soul_bound;
            unlocked_hats = unlocked_hats;
        };
    };

    public func _editUserInfo(existing: T.UserInfo, new_vals: [T.UserInfoVariant]): T.UserInfo {
        var id : T.UserId = existing.id;
        var achievements : [Text] = existing.achievements;
        var created_date : Nat = existing.created_date;
        var fish : [T.FishId] = existing.fish;
        var fish_hats : [T.HatAcc] = existing.fish_hats;
        var tank_accs : [Text] = existing.tank_accs;
        var wallets : [{wallet:Text; id:Principal}] = existing.wallets;
        var last_login : Nat = existing.last_login;
        var login_streak : Nat = existing.login_streak;
        var num_minted : Nat = existing.num_minted;
        var num_donated : Nat = existing.num_donated;
        var num_adopted : Nat = existing.num_adopted;

        for(new_val in new_vals.vals()){
            switch(new_val){
                case(#USERINFO_ACHIEVEMENTS(val)){ achievements:=val;};
                case(#USERINFO_FISH(val)){ fish:=val;};
                case(#USERINFO_FISH_HATS(val)){ fish_hats:=val;};
                case(#USERINFO_TANK_ACCS(val)){ tank_accs:=val;};
                case(#USERINFO_WALLETS(val)){ wallets:=val;};
                case(#USERINFO_LAST_LOGIN(val)){ last_login:=val;};
                case(#USERINFO_LOGIN_STREAK(val)){ login_streak:=val;};
                case(#USERINFO_NUM_ADOPTED(val)){ num_adopted:=val;};
                case(#USERINFO_NUM_DONATED(val)){ num_donated:=val;};
                case(#USERINFO_NUM_MINTED(val)){ num_minted:=val;};
            };
        };

        return {
            id = id;
            achievements = achievements;
            created_date = created_date;
            fish = fish;
            fish_hats = fish_hats;
            tank_accs = tank_accs;
            wallets = wallets;
            last_login = last_login;
            login_streak = login_streak;
            num_minted = num_minted;
            num_donated = num_donated;
            num_adopted = num_adopted;
        }
    };

    public func _editFishProperties(existing: T.FishProps, new_vals: [T.FishPropsVariant]): T.FishProps {
        var hat = existing.hat;
        var body_type = existing.body_type;
        var color_1 = existing.color_1;
        var color_2 = existing.color_2;
        var color_3 = existing.color_3;
        var eye_color = existing.eye_color;
        var size = existing.size;
        var speed = existing.speed;

        for(new_val in new_vals.vals()){
            switch(new_val){
                case(#FISHPROP_HAT(val)){ hat:=val;};
            };
        };

        return {
            hat = hat;
            body_type = body_type;
            color_1 = color_1;
            color_2 = color_2;
            color_3 = color_3;
            eye_color = eye_color;
            size = size;
            speed = speed;
        };
    };

    public func _editDisplayTank(existing: T.DisplayTank, new_vals:[T.DisplayTankVariant]): T.DisplayTank {
        var fish = existing.fish;
        var color_bottom = existing.color_bottom;
        var color_bg = existing.color_bg;
        var acc_left = existing.acc_left;
        var acc_right = existing.acc_right;
        var effect = existing.effect;

        for(new_val in new_vals.vals()){
            switch(new_val){
                case(#DISPLAYTANK_ACC_LEFT(val)){ acc_left:=val;};
                case(#DISPLAYTANK_ACC_RIGHT(val)){ acc_right:=val;};
                case(#DISPLAYTANK_COLOR_BG(val)){ color_bg:=val;};
                case(#DISPLAYTANK_COLOR_BOTTOM(val)){ color_bottom:=val;};
                case(#DISPLAYTANK_EFFECT(val)){ effect:=val;};
                case(#DISPLAYTANK_FISH(val)){ fish:=val;};
            };
        };

        return {
            fish = fish;
            color_bottom = color_bottom;
            color_bg = color_bg;
            acc_left = acc_left;
            acc_right = acc_right;
            effect = effect;
        };
    };
    
    public func _editStakingTank(existing: T.StakingTank, new_vals:[T.StakingTankVariant]): T.StakingTank {
        var fish = existing.fish;
        var color_bottom = existing.color_bottom;
        var color_bg = existing.color_bg;
        var acc_left = existing.acc_left;
        var acc_right = existing.acc_right;
        var effect = existing.effect;

        for(new_val in new_vals.vals()){
            switch(new_val){
                case(#STAKINGTANK_ACC_LEFT(val)){ acc_left:=val;};
                case(#STAKINGTANK_ACC_RIGHT(val)){ acc_right:=val;};
                case(#STAKINGTANK_COLOR_BG(val)){ color_bg:=val;};
                case(#STAKINGTANK_COLOR_BOTTOM(val)){ color_bottom:=val;};
                case(#STAKINGTANK_EFFECT(val)){ effect:=val;};
                case(#STAKINGTANK_FISH(val)){ fish:=val;};
            };
        };

        return {
            fish = fish;
            color_bottom = color_bottom;
            color_bg = color_bg;
            acc_left = acc_left;
            acc_right = acc_right;
            effect = effect;
        };
    };
};