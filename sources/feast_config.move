module feast::feast_config {
    use std::string::{Self};

    public struct GlobalAgencyConfig has key, store {
        id: UID,
        // 其它配置
        currency: string::String,//采用哪种Coin来筹造NFT，支持SUI或者FEAST两种类型。
        base_premium: u64,//基础价格
        fee_recipient: address,//mint和burn手续费收款地址,可配置还是采用默认地址?
        min_fee_percent: u16,//mint手续费利率
        burn_fee_percent: u16,//burn手续费利率
    }

    // Agency代理的APP NFT初始配置信息
    // 共享对象
    public struct AgencyPoolSettings has key, store {
        id: UID,
        agency_id: ID,//所属agency
        max_supply: u64,//最大提供
        // 其它配置
        currency: std::string::String,//采用哪种类型来筹造NFT，支持SUI或者Feast两种类型。
        base_premium: u64,//基础价格
        fee_recipient: address,//mint和burn手续费收款地址
        mint_fee_percent: u16,//mint手续费利率
        burn_fee_percent: u16,//burn手续费利率
    }

    public struct SuperAdminCap has key, store {
        id: UID,
    }

    //otw模式,config共享，但只能管理员才能操作
    public struct FEAST_CONFIG has drop {}

    // otw初始化配置
    // 目前只支持sui和feast
    fun init(_otw: FEAST_CONFIG, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);

        let config1 = GlobalAgencyConfig {
                id: object::new(ctx),
                currency: string::utf8(b"SUI"),
                base_premium: 100,
                fee_recipient: @fee_recipient,
                min_fee_percent: 10,
                burn_fee_percent: 10,
        };
        transfer::share_object(config1);

        let config2 = GlobalAgencyConfig {
            id: object::new(ctx),
            currency: string::utf8(b"FEAST"),
            base_premium: 100,
            fee_recipient: @fee_recipient,
            min_fee_percent: 10,
            burn_fee_percent: 10,
        };
        transfer::share_object(config2);

        transfer::public_transfer(
            SuperAdminCap {
                id: object::new(ctx)
            }, sender);
    }

    // 创建配置
    // 共享对象
    public(package) fun new_settings(config: &GlobalAgencyConfig, agency_id: ID, max_supply: u64, currency: string::String, ctx: &mut TxContext) {
        let settings = AgencyPoolSettings{
            id: object::new(ctx),
            agency_id: agency_id,//所属agency
            // 其它配置
            max_supply: max_supply,//最大提供
            currency: currency,//采用哪种货币
            base_premium: config.base_premium(),//基础价格
            fee_recipient: config.fee_recipient(),//mint和burn手续费收款地址
            mint_fee_percent: config.mint_fee_percent(),//mint手续费利率
            burn_fee_percent: config.burn_fee_percent(),//burn手续费利率
        };
        transfer::share_object(settings);
    }

    // ============GlobalAgencyConfig==============

    public fun currency(config: &GlobalAgencyConfig): &std::string::String{
        &config.currency
    }

    public fun base_premium(config: &GlobalAgencyConfig): u64 {
        config.base_premium
    }

    public fun fee_recipient(config: &GlobalAgencyConfig): address {
        config.fee_recipient
    }

    public fun mint_fee_percent(config: &GlobalAgencyConfig): u16 {
        config.min_fee_percent
    }

    public fun burn_fee_percent(config: &GlobalAgencyConfig): u16 {
        config.burn_fee_percent
    }

    // ========AgencyPoolSettings================

    public fun settings_agency_id(settings: &AgencyPoolSettings): ID {
        settings.agency_id
    }

    public fun settings_max_supply(settings: &AgencyPoolSettings): ID {
        settings.agency_id
    }

    public fun settings_currency(settings: &AgencyPoolSettings): &string::String {
        &settings.currency
    }

    public fun settings_base_premium(settings: &AgencyPoolSettings): u64 {
        settings.base_premium
    }

    public fun settings_fee_recipient(settings: &AgencyPoolSettings): address {
        settings.fee_recipient
    }

    public fun settings_mint_fee_percent(settings: &AgencyPoolSettings): u64 {
        settings.mint_fee_percent as u64
    }

    public fun settings_burn_fee_percent(settings: &AgencyPoolSettings): u64 {
        settings.burn_fee_percent as u64
    }

    // todo!()其它操作配置的操作

}