module feast::feast_agency {
    use sui::url::{Self, Url};
    use std::string::{Self};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self};

    use feast::feast_config::AgencyPoolSettings;

    use feast::feast_nft::AgencyNFTContext;
    use feast::feast_nft::AppNFT;

    const EBalanceIsNotEnough: u64 = 0;

    const EAgencyIdNotEqual: u64 = 1;

    // Agency信息
    public struct Agency has key, store {
        id: UID,
        name: string::String,
        description: string::String,
        url: Url,
    }

    // 从Factory创建Agency
    #[allow(lint(self_transfer))]
    public(package) fun new_agency(
        name: vector<u8>,
        description: vector<u8>,
        url: vector<u8>,
        max_supply: u64,
        ctx: &mut TxContext
     ): ID {
        let agency = Agency{
            id: object::new(ctx),
            name: string::utf8(name),
            description: string::utf8(description),
            url: url::new_unsafe_from_bytes(url),
        };

        let agency_id = object::id(&agency);
        //初始化AppNFT上下文环境
        feast::feast_nft::init_app_nft_context(agency_id, name, max_supply, ctx);

        // 转移所有权
        transfer::public_transfer(agency, tx_context::sender(ctx));

        agency_id
    }

    // transfer，Agency具有NFT功能
    public fun transfer(
        agency: Agency, recipient: address, _: &mut TxContext) {
        transfer::public_transfer(agency, recipient)
    }

    // =========交易池相关==============

    // 返回token_id还是object_id?
    public fun wrap(
        settings: &AgencyPoolSettings, 
        agency_nft_context: &mut AgencyNFTContext, 
        // payment: Option<Coin<SUI>>, //未实现
        // feastPayment: Option<Coin<FEAST>>, //未实现
        payment: &mut Coin<SUI>,
        name: vector<u8>, 
        description: vector<u8>,
        url: vector<u8>,
        // recipient: Option<address>,
        ctx: &mut TxContext): u64
    {
        // 校验
        // agency_id一致
        assert!(settings.settings_agency_id() == agency_nft_context.get_agency_id(), EAgencyIdNotEqual);
        // 获取报价
        let sold = agency_nft_context.get_total_supply();
        let (premium, mint_fee) = get_wrap_oracle(settings, sold);

        assert!(payment.value() > (premium + mint_fee), EBalanceIsNotEnough);

        let mut total_amount = balance::split(coin::balance_mut(payment), (premium + mint_fee));
        // 手续费
        let mint_fee_amount = balance::split(&mut total_amount, mint_fee);

        // let premium_amount = coin::split(payment, premium, ctx);
        // let mint_fee_amount = coin::split(payment, mint_fee, ctx);
        
        // mint
        let token_id = feast::feast_nft::mint(
            agency_nft_context,
            name,
            description,
            url,
            ctx,
        );

        // feast::feast_nft::income_and_fee(agency_nft_context, premium_amount, mint_fee_amount);

        // 清算
        feast::feast_nft::income_and_fee(agency_nft_context, total_amount, mint_fee_amount);

        token_id
    }

    // 返回(价格,费用)
    public fun get_wrap_oracle(settings: &AgencyPoolSettings, input: u64):(u64, u64) {
        let premium = settings.settings_base_premium() + input * settings.settings_base_premium() / 100;
        let fee = premium * settings.settings_mint_fee_percent() / 10000;
        (premium, fee)
    }

    // unwrap
    public fun unwrap(
        settings: &AgencyPoolSettings, 
        agency_nft_context: &mut AgencyNFTContext,  
        app_nft: AppNFT, 
        recipient: &mut Option<address>,
        ctx: &mut TxContext)
    {
        // 校验
        // agency_id一致
        assert!(settings.settings_agency_id() == agency_nft_context.get_agency_id(), EAgencyIdNotEqual);
        // 获取报价
        let sold = agency_nft_context.get_total_supply();
        // TODO 需不需要校验preminum > burn_fee?
        let (premium, burn_fee) = get_unwrap_oracle(settings, sold);

        // burn
        feast::feast_nft::burn(
            agency_nft_context,
            app_nft,
            ctx,
        );

        // 清算
        feast::feast_nft::outcome_and_fee(agency_nft_context, recipient, premium, burn_fee, ctx);
    }

    // 返回(价格,费用)
    public fun get_unwrap_oracle(settings: &AgencyPoolSettings, input: u64): (u64, u64) {
        let premium = settings.settings_base_premium() + input * settings.settings_base_premium() / 100;
        let fee = premium * settings.settings_mint_fee_percent() / 10000;
        (premium, fee)
    }

}