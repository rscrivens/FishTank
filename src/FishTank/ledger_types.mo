module {
    public type AccountIdentifier = Text;

    public type AccountBalanceArgs = {
        account: AccountIdentifier;
    };

    public type BlockHeight = Nat64;
    public type ICPTs = {e8s : Nat64 };
    public type Memo = Nat64;
    public type SubAccount = [Nat8];
    public type TimeStamp = { timestamp_nanos : Nat64 };
    public type SendArgs = {
      to : AccountIdentifier;
      fee : ICPTs;
      memo : Memo;
      from_subaccount : ?SubAccount;
      created_at_time : ?TimeStamp;
      amount : ICPTs;
    };

    public type FaucetArgs ={
      to : AccountIdentifier;
      created_at_time : ?TimeStamp;
    };

    public type FaucetInterface = actor {
        account_balance_dfx: (AccountBalanceArgs) -> async ICPTs;
        send_dfx: (SendArgs) -> async BlockHeight;
        faucet: (FaucetArgs) -> async BlockHeight;
    };
}