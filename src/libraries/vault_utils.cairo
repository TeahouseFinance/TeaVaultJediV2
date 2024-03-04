mod VaultUtils {
    use starknet::ContractAddress;
    use yas_core::numbers::signed_integer::{ i32::i32 };
    use yas_core::utils::math_utils::FullMath::mul_div;
    use jediswap_v2_core::{
        jediswap_v2_pool::{ IJediSwapV2PoolDispatcher, IJediSwapV2PoolDispatcherTrait },
        libraries::{
            tick_math::TickMath::get_sqrt_ratio_at_tick,
            sqrt_price_math::SqrtPriceMath::{ Q96, Q128 },
            position::{ PositionKey }
        }
    };
    use jediswap_v2_periphery::libraries::liquidity_amounts::LiquidityAmounts;
    use tea_vault_jedi_v2::tea_vault_jedi_v2::Position;

    fn get_liquidity_for_amounts(
        pool: ContractAddress,
        tick_lower: i32,
        tick_upper: i32,
        amount0: u256,
        amount1: u256
    ) -> u128 {
        let pool_dispatcher = IJediSwapV2PoolDispatcher { contract_address: pool };
        let sqrt_price_x96 = pool_dispatcher.get_sqrt_price_X96();

        LiquidityAmounts::get_liquidity_for_amounts(
            sqrt_price_x96,
            get_sqrt_ratio_at_tick(tick_lower),
            get_sqrt_ratio_at_tick(tick_upper),
            amount0,
            amount1
        )
    }

    fn get_amounts_for_liquidity(
        pool: ContractAddress,
        tick_lower: i32,
        tick_upper: i32,
        liquidity: u128
    ) -> (u256, u256) {
        let pool_dispatcher = IJediSwapV2PoolDispatcher { contract_address: pool };
        let sqrt_price_x96 = pool_dispatcher.get_sqrt_price_X96();

        LiquidityAmounts::get_amounts_for_liquidity(
            sqrt_price_x96,
            get_sqrt_ratio_at_tick(tick_lower),
            get_sqrt_ratio_at_tick(tick_upper),
            liquidity
        )
    }

    fn position_info(
        account: ContractAddress,
        pool: ContractAddress,
        position: Position
    ) -> (u256, u256, u256, u256) {
        let pool_dispatcher = IJediSwapV2PoolDispatcher { contract_address: pool };
        let sqrt_price_x96 = pool_dispatcher.get_sqrt_price_X96();
        let fee_growth_global0_x128 = pool_dispatcher.get_fee_growth_global_0_X128();
        let fee_growth_global1_x128 = pool_dispatcher.get_fee_growth_global_1_X128();
        let tick_lower_info = pool_dispatcher.get_tick_info(position.tick_lower);
        let tick_upper_info = pool_dispatcher.get_tick_info(position.tick_upper);
        let position_key = PositionKey {
            owner: account, tick_lower: position.tick_lower, tick_upper: position.tick_upper
        };

        let position_info = pool_dispatcher.get_position_info(position_key);
        let (amount0, amount1) = LiquidityAmounts::get_amounts_for_liquidity(
            sqrt_price_x96,
            get_sqrt_ratio_at_tick(position.tick_lower),
            get_sqrt_ratio_at_tick(position.tick_upper),
            position_info.liquidity
        );
        let tick = pool_dispatcher.get_tick();
        let fee0 = position_info.tokens_owed_0.into() + position_swap_fee(
            tick,
            position.tick_lower,
            position.tick_upper,
            position_info.liquidity,
            fee_growth_global0_x128,
            position_info.fee_growth_inside_0_last_X128,
            tick_lower_info.fee_growth_outside_0_X128,
            tick_upper_info.fee_growth_outside_0_X128
        );
        let fee1 = position_info.tokens_owed_1.into() + position_swap_fee(
            tick,
            position.tick_lower,
            position.tick_upper,
            position_info.liquidity,
            fee_growth_global1_x128,
            position_info.fee_growth_inside_1_last_X128,
            tick_lower_info.fee_growth_outside_1_X128,
            tick_upper_info.fee_growth_outside_1_X128
        );

        (amount0, amount1, fee0, fee1)
    }

    fn position_swap_fee(
        tick: i32,
        tick_lower: i32,
        tick_upper: i32,
        liquidity: u128,
        fee_growth_global_x128: u256,
        fee_growth_inside_last_x128: u256,
        fee_growth_outside_x128_lower: u256,
        fee_growth_outside_x128_upper: u256
    ) -> u256 {
        let fee_growth_below_x128 = if tick >= tick_lower {
            fee_growth_outside_x128_lower
        }
        else {
            fee_growth_global_x128 - fee_growth_outside_x128_lower
        };
        let fee_growth_above_x128 = if tick < tick_upper {
            fee_growth_outside_x128_upper
        }
        else {
            fee_growth_global_x128 - fee_growth_outside_x128_upper
        };
        let fee_growth_inside_x128 = fee_growth_global_x128 - fee_growth_below_x128 - fee_growth_above_x128;

        mul_div(
            fee_growth_inside_x128 - fee_growth_inside_last_x128,
            liquidity.into(),
            Q128
        )
    }

    fn estimated_value_in_token0(pool: ContractAddress, amount0: u256, amount1: u256) -> u256 {
        let pool_dispatcher = IJediSwapV2PoolDispatcher { contract_address: pool };
        let sqrt_price_x96 = pool_dispatcher.get_sqrt_price_X96();

        amount0 + mul_div(
            amount1,
            Q96,
            mul_div(sqrt_price_x96, sqrt_price_x96, Q96)
        )
    }

    fn estimated_value_in_token1(pool: ContractAddress, amount0: u256, amount1: u256) -> u256 {
        let pool_dispatcher = IJediSwapV2PoolDispatcher { contract_address: pool };
        let sqrt_price_x96 = pool_dispatcher.get_sqrt_price_X96();

        amount1 + mul_div(
            amount0,
            mul_div(sqrt_price_x96, sqrt_price_x96, Q96),
            Q96
        )
    }
}