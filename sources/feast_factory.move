module feast::feast_factory {

    use std::string::{Self};
    use sui::url::{Self};
    use sui::event;
    use sui::linked_table::{Self, LinkedTable};
    use sui::vec_set::{Self, VecSet};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;

    use feast::feast_config::GlobalAgencyConfig;
    // use feast::feast::FEAST;
    
    const EAgencyNameExist: u64 = 0;

    const EInvalidMaxSupply: u64 = 1;

    const EInvalidPercentRange: u64 = 2;

    const EBasePremium: u64 = 3;

    const EBalanceIsNotEnough: u64 = 4;

    const EInvalidCurrency: u64 = 5;

    // AgencyPools是Singleton,otw初始化
    public struct FEAST_FACTORY has drop {}

    fun init(_otw: FEAST_FACTORY, ctx: &mut TxContext) {
        let pools = AgencyPools {
            id: object::new(ctx),
            list: linked_table::new<ID, AgencyPoolSimpleInfo>(ctx),
            agency_name_exists: vec_set::empty<string::String>(),
            index: 0,
        };
        transfer::share_object(pools);
    }

    public struct AgencyPools has key, store {
        id: UID,
        list: LinkedTable<ID, AgencyPoolSimpleInfo>,//<agency_id, agency_pool_simple_info>
        agency_name_exists: VecSet<string::String>,//已存在的agency的名称
        index: u64,//最大index，当前有多少个AgencyPool
    }

    public struct AgencyPoolSimpleInfo has store, copy, drop {
        agency_id: ID,
        name: string::String,
        description: string::String,
        url: url::Url,
        max_supply: u64,
        // 其它信息
    }

    // Emit when create Agency
    public struct AgencyPoolMinted has copy, drop {
        agency_id: ID,
        creator: address,
        name: string::String,
        description: string::String,
        url: url::Url,
        max_supply: u64,
    }

    // 创建AgencyPool
    // TODO 目前只简单实现,100SUI创建Agency
    #[allow(lint(self_transfer))]
    public fun create_agency_pool_with_sui(
        agency_pools: &mut AgencyPools,
        config: &GlobalAgencyConfig,//全局配置信息
        // 支付信息
        payment: &mut Coin<SUI>,
        // Agency基础信息
        name: vector<u8>,//名称不可重复
        description: vector<u8>,
        url: vector<u8>,
        // 其它配置
        max_supply: u64,//最大提供
        ctx: &mut TxContext
    ) {
        //检查
        //config的currency类型必须与SUI类型一致
        let currency = string::utf8(b"SUI");
        assert!(config.currency() == currency, EInvalidCurrency);
        // 金额是否足够
        let amount = coin::value(payment);
        assert!(amount > 100, EBalanceIsNotEnough);
        //名称重复
        assert!(!agency_pools.agency_name_exists.contains(&string::utf8(name)), EAgencyNameExist);
        // 最大供应量>0
        assert!(max_supply > 0, EInvalidMaxSupply);
        // 百分比范围
        assert!(config.mint_fee_percent() < 5000, EInvalidPercentRange);
        assert!(config.burn_fee_percent() < 5000, EInvalidPercentRange);
        // 基础价格
        assert!(config.base_premium() > 0, EBasePremium);
        let sender = tx_context::sender(ctx);
        // 创建Agency
        let agency_id = feast::feast_agency::new_agency(name, description, url, max_supply, ctx);

        let poolSimpleInfo = AgencyPoolSimpleInfo{
            agency_id: agency_id,
            name: string::utf8(name),
            description: string::utf8(description),
            url: url::new_unsafe_from_bytes(url),
            max_supply: max_supply,
        };
        agency_pools.list.push_back(agency_id, poolSimpleInfo);

        //创建配置信息
        feast::feast_config::new_settings(config, agency_id, max_supply, currency, ctx);

        //事件
        event::emit(AgencyPoolMinted{
            agency_id: agency_id,
            creator: sender,
            name: string::utf8(name),
            description: string::utf8(description),
            url: url::new_unsafe_from_bytes(url),
            max_supply: max_supply,
        });

        //支付100SUI
        let paid = coin::split(payment, 100, ctx);
        transfer::public_transfer(paid, @fee_recipient);
    }

    // // 创建AgencyPool
    // #[allow(lint(self_transfer))]
    // public fun create_agency_pool_with_feast(
    //     agency_pools: &mut AgencyPools,
    //     config: &GlobalAgencyConfig,//全局配置信息
    //     // 支付信息
    //     payment: &mut Coin<FEAST>,
    //     // Agency基础信息
    //     name: vector<u8>,//名称不可重复
    //     description: vector<u8>,
    //     url: vector<u8>,
    //     // 其它配置
    //     max_supply: u64,//最大提供
    //     ctx: &mut TxContext
    // ) {
    //     //TODO 检查
    //     //config的currency类型必须与FEAST类型一致
    //     let currency = string::utf8(b"FEAST");
    //     assert!(config.currency() == currency, EInvalidCurrency);
    //     // 金额是否足够
    //     let amount = coin::value(payment);
    //     assert!(amount > 1000, EBalanceIsNotEnough);
    //     //名称重复
    //     assert!(!agency_pools.agency_name_exists.contains(&string::utf8(name)), EAgencyNameExist);
    //     // 最大供应量>0
    //     assert!(max_supply > 0, EInvalidMaxSupply);
    //     // 百分比范围
    //     assert!(config.mint_fee_percent() < 5000 , EInvalidPercentRange);
    //     assert!(config.burn_fee_percent() < 5000, EInvalidPercentRange);
    //     // 基础价格
    //     assert!(config.base_premium() > 0, EBasePremium);
    //     let sender = tx_context::sender(ctx);
    //     // 创建Agency
    //     let agency_id = feast::feast_agency::new_agency(name, description, url, max_supply, ctx);

    //     let poolSimpleInfo = AgencyPoolSimpleInfo{
    //         agency_id: agency_id,
    //         name: string::utf8(name),
    //         description: string::utf8(description),
    //         url: url::new_unsafe_from_bytes(url),
    //         max_supply: max_supply,
    //     };
    //     agency_pools.list.push_back(agency_id, poolSimpleInfo);

    //     //创建配置信息
    //     feast::feast_config::new_settings(config, agency_id, max_supply, currency, ctx);

    //     //事件
    //     event::emit(AgencyPoolMinted{
    //         agency_id: agency_id,
    //         creator: sender,
    //         name: string::utf8(name),
    //         description: string::utf8(description),
    //         url: url::new_unsafe_from_bytes(url),
    //         max_supply: max_supply,
    //     });

    //     //支付1000FEAST
    //     let paid = coin::split(payment, 1000, ctx);
    //     transfer::public_transfer(paid, @fee_recipient);
    // }


    public fun agency_id(agency_pool: &AgencyPoolSimpleInfo): ID {
        agency_pool.agency_id
    }

    public fun name(agency_pool: &AgencyPoolSimpleInfo): &string::String {
        &agency_pool.name
    }

    public fun description(agency_pool: &AgencyPoolSimpleInfo): &string::String {
        &agency_pool.description
    }

    public fun url(agency_pool: &AgencyPoolSimpleInfo): &url::Url{
        &agency_pool.url
    }

    public fun max_supply(agency_pool: &AgencyPoolSimpleInfo): u64 {
        agency_pool.max_supply
    }

}