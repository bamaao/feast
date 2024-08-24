/// Module: feast
module feast::feast {
    // use std::ascii::{Self};
    
    use sui::coin::{Self, TreasuryCap};
    // use sui::url::{Self};

    public struct FEAST has drop {}

    const TOTAL_SUPPLY: u64 = 1_000_000_000_000;

    public struct Gomi has key {
        id: UID,
        treasury_cap: TreasuryCap<FEAST>
    }

    #[allow(lint(freeze_wrapped))]
    fun init(
        witness: FEAST,
        ctx: &mut TxContext,
    ) {
        let (mut treasury_cap, metadata) = coin::create_currency(
            witness,
            0,
            b"FEAST",
            b"FEAST",
            b"The utility token of the feast ecosystem.",
            option::none(),
            ctx
        );

        coin::mint_and_transfer(
            &mut treasury_cap,
            TOTAL_SUPPLY,
            tx_context::sender(ctx),
            ctx,
        );

        let gomi = Gomi {
            id: object::new(ctx),
            treasury_cap: treasury_cap,
        };
        
        transfer::freeze_object(gomi);
        transfer::public_freeze_object(metadata);
    }
}
