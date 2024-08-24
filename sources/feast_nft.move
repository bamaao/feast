module feast::feast_nft {
    use sui::url::{Self};
    use std::string::{Self};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::event;
    use sui::coin::{Self};

    const EMaxSupplyLimit: u64 = 0;

    const ENftNotExists: u64 = 1;

    // NFT相关信息
    // TODO 基础信息是自己存一份还是从Agency获取?
    public struct AppNFT has key, store {
        id: UID,
        token_id: u64,
        agency_id: ID,
        agency_name: string::String,
        name: string::String,
        description: string::String,
        url: url::Url,
    }

    // App NFT上下文信息
    // 共享对象
    public struct AgencyNFTContext has key, store {
        id: UID,
        agency_id: ID,//所属agency
        agency_name: string::String,
        income: Balance<SUI>,
        fee: Balance<SUI>,
        max_supply: u64,//最大提供
        total_supply: u64,//当前提供
        // app_nft_token_ids: vec_set<u64>,//每个NFT的token_id？需不需要跟踪每个token的Token_Id？这里存储的是每个已回收的token_id?每次burn都回收，然后mint时优先从这里获取？
        index: u64,
    }

    // ============Events===================

    public struct AppNFTMinted has copy, drop {
        object_id: ID,
        token_id: u64,
        agency_id: ID,
        creator: address,
        name: string::String,
        description: string::String,
        url: url::Url,
    }

    // AppNFT上下文
    // 共享对象
    public(package) fun init_app_nft_context(agency_id: ID, agency_name: vector<u8>, max_supply:u64, ctx: &mut TxContext) {
        let agency_nft_context = AgencyNFTContext{
            id: object::new(ctx),
            agency_id: agency_id,//所属agency
            agency_name: string::utf8(agency_name),
            income: balance::zero(),//收益
            fee: balance::zero(),//手续费
            max_supply: max_supply,//最大提供
            total_supply: 0,//当前提供
            index: 0,
        };

        transfer::share_object(agency_nft_context);
    }

    // 获取name
    public fun name(nft: &AppNFT): &string::String {
        &nft.name
    }

    // 获取description
    public fun description(nft: &AppNFT): &string::String {
        &nft.description
    }

    // 获取url
    public fun url(nft: &AppNFT): &url::Url {
        &nft.url
    }

    // 获取agency_id
    public fun agency_id(nft: &AppNFT): ID {
        nft.agency_id
    }

    #[allow(lint(self_transfer))]
    public(package) fun mint(
        agency_nft_context: &mut AgencyNFTContext,
        name: vector<u8>,
        description: vector<u8>,
        url: vector<u8>,
        ctx: &mut TxContext): u64
    {
        // 比较数量,"超过最大供应数量"
        assert!(agency_nft_context.get_max_supply() > agency_nft_context.get_total_supply(), EMaxSupplyLimit);

        let agency_id = agency_nft_context.agency_id;

        let sender = tx_context::sender(ctx);
        let token_id: u64 = agency_nft_context.index + 1;
        let nft = AppNFT {
            id: object::new(ctx),
            token_id: token_id,
            name: string::utf8(name),
            description: string::utf8(description),
            url: url::new_unsafe_from_bytes(url),
            agency_id: agency_id,
            agency_name: agency_nft_context.agency_name,
        };

        // string::String需不需要clone?
        event::emit(AppNFTMinted{
            object_id: object::id(&nft),
            token_id: token_id,
            agency_id: agency_id,
            creator: sender,
            name: nft.name,
            description: nft.description,
            url: nft.url,
        });
        transfer::public_transfer(nft, sender);

        //agency_nft_context增加total_supply
        agency_nft_context.total_supply = agency_nft_context.total_supply + 1;
        agency_nft_context.index = agency_nft_context.index + 1;

        token_id
    }

    // // 收入和手续费
    // public(package) fun income_and_fee(agency_nft_context: &mut AgencyNFTContext, income: Coin<SUI>, fee: Coin<SUI>) {
    //     coin::put(&mut agency_nft_context.income, income);
    //     coin::put(&mut agency_nft_context.fee, fee);
    // }

    // 收入和手续费
    public(package) fun income_and_fee(agency_nft_context: &mut AgencyNFTContext, income: Balance<SUI>, fee: Balance<SUI>) {
        agency_nft_context.income.join(income);
        agency_nft_context.fee.join(fee);
    }

    public(package) fun burn(
        // cap: AppNFTCap,
        agency_nft_context: &mut AgencyNFTContext,
        nft: AppNFT,
        _ctx: &mut TxContext,
     ) {
        assert!(agency_nft_context.get_total_supply() > 0, ENftNotExists);

        // 直接删除NFT
        let AppNFT{
            id,
            token_id: _,
            name: _,
            description: _,
            url: _,
            agency_id: _,
            agency_name: _,
        } = nft;

        agency_nft_context.total_supply = agency_nft_context.total_supply - 1;

        object::delete(id);
    }

    // 支出和手续费
    #[allow(lint(self_transfer))]
    public(package) fun outcome_and_fee(agency_nft_context: &mut AgencyNFTContext, recipient: &mut Option<address>, amout: u64, fee:u64, ctx: &mut TxContext) {
        let redeem_amount = agency_nft_context.income.split(amout - fee);
        let burn_fee = agency_nft_context.income.split(fee);
        agency_nft_context.fee.join(burn_fee);
        if (recipient.is_some()) {//存在收款地址则转入指定收款地址
            transfer::public_transfer(coin::from_balance(redeem_amount, ctx), option::extract(recipient));
        }else {
            // 不指定收款地址则转入交易sender
            transfer::public_transfer(coin::from_balance(redeem_amount, ctx), tx_context::sender(ctx));
        }
    }

    //转移所有权
    public fun transfer(nft: AppNFT, recipient: address, _: &mut TxContext) {
        transfer::public_transfer(nft, recipient)
    }

    // /// Update the `description` of `nft` to `new_description`
    // public fun update_description(
    //     nft: &mut AppNFT,
    //     new_description: vector<u8>,
    //     _: &mut TxContext
    // ) {
    //     nft.description = string::utf8(new_description)
    // }

    // 获取max_supply
    public fun get_max_supply(context: &AgencyNFTContext): u64 {
        context.max_supply
    }

    // 获取total_supply
    public fun get_total_supply(context: &AgencyNFTContext): u64 {
        context.total_supply
    }

    // 获取agency_id
    public fun get_agency_id(context: &AgencyNFTContext): ID {
        context.agency_id
    }

    // 提取手续费到fee_recipient地址
    public entry fun withdraw(context: &mut AgencyNFTContext, ctx: &mut TxContext) {
        // sender=tx_context::sender(ctx)
        // 取出全部余额
        let fee_amount = context.fee.withdraw_all();
        transfer::public_transfer(coin::from_balance(fee_amount, ctx), @fee_recipient);
    }
}