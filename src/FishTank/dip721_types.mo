import Principal "mo:base/Principal";

module {
    public type TokenAddress = Principal;
    public type TokenId = Nat;

    public type TokenMetadata = {
        properties          : TokenProps;
        minted_at           : Nat64;
        minted_by           : Principal;
        transferrable       : Bool;
        transferred_at      : ?Nat64;
        transferred_by      : ?Principal;
    };

    public type TokenProps = {
        color_1             : Text;
        color_2             : Text;
        color_3             : Text;
    };

    public type Profile = {
        tank_color          : Text;
    }
}