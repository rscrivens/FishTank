import Principal "mo:base/Principal";
import TP "token_prop_type";

module {
    public type TokenAddress = Principal;
    public type TokenId = Nat;

    public type TokenMetadata = {
        properties          : TP.TokenProperties;
        minted_at           : Nat64;
        minted_by           : Principal;
        transferred_at      : ?Nat64;
        transferred_by      : ?Principal;
    };
}