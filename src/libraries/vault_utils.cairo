// SPDX-License-Identifier: BUSL-1.1
// Teahouse Finance
// libraries/vault_utils.cairo

mod VaultUtils {
    use starknet::ContractAddress;
    use jediswap_v2_core::{
        jediswap_v2_pool::{ IJediSwapV2PoolDispatcher, IJediSwapV2PoolDispatcherTrait },
        libraries::{
            signed_integers::i32::i32,
            full_math::mul_div,
            tick_math::TickMath::get_sqrt_ratio_at_tick,
            sqrt_price_math::SqrtPriceMath::{ Q96, Q128 },
            position::PositionKey
        }
    };
    use jediswap_v2_periphery::libraries::liquidity_amounts::LiquidityAmounts;
    use tea_vault_jedi_v2::tea_vault_jedi_v2::Position;

    /// @notice Computes the maximum amount of liquidity received for a given amount of token0, token1, a pool address and the tick boundaries of a liquidity position.
    /// @param pool Pool address
    /// @param tick_lower Lower tick
    /// @param tick_upper Upper tick
    /// @param amount0 The amount of token0 being sent in
    /// @param amount1 The amount of token1 being sent in
    /// @return liquidity The maximum amount of liquidity received
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

    /// @notice Computes the token0 and token1 value for a given amount of liquidity, a pool address and the tick boundaries of a liquidity position.
    /// @param pool Pool address
    /// @param tick_lower Lower tick
    /// @param tick_upper Upper tick
    /// @param liquidity The liquidity being valued
    /// @return amount0 The amount of token0
    /// @return amount1 The amount of token1
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

    /// @Computes the token0 and token1 value, and unclaim swap fees for a given account, a pool address and a position.
    /// @param account Account address,
    /// @param pool Pool address
    /// @param position The position being valued
    /// @return amount0 The amount of token0
    /// @return amount1 The amount of token1
    /// @return amount0 The amount of unclaimed token0 swap fee
    /// @return amount1 The amount of unclaimed token1 swap fee
    fn position_info(
        account: ContractAddress,
        pool: ContractAddress,
        position: Position
    ) -> (u256, u256, u256, u256) {
        let pool_dispatcher = IJediSwapV2PoolDispatcher { contract_address: pool };
        let fee_growth_global0_x128 = pool_dispatcher.get_fee_growth_global_0_X128();
        let fee_growth_global1_x128 = pool_dispatcher.get_fee_growth_global_1_X128();
        let tick_lower_info = pool_dispatcher.get_tick_info(position.tick_lower);
        let tick_upper_info = pool_dispatcher.get_tick_info(position.tick_upper);
        let position_key = PositionKey {
            owner: account, tick_lower: position.tick_lower, tick_upper: position.tick_upper
        };

        let position_info = pool_dispatcher.get_position_info(position_key);
        let (amount0, amount1) = get_amounts_for_liquidity(pool, position.tick_lower, position.tick_upper, position_info.liquidity);
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

    /// @Computes the swap fee for a given pool price in tick, lower and upper tick of a liquidity position, and the fee info of a tick and the globe.
    /// @param tick Pool price in tick
    /// @param tick_lower Lower tick
    /// @param tick_upper Upper tick
    /// @param liquidity The amount of liquidity
    /// @param fee_growth_global_x128 The global fee growth of token
    /// @param fee_growth_inside_last_x128 The fee growth on the liquidity position
    /// @param fee_growth_outside_x128_lower The fee growth outside and below the liquidity position
    /// @param fee_growth_outside_x128_upper The fee growth outside and above the liquidity position
    /// @return fee_amount The unclaimed swap fee amount of token
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

    /// @notice Computes the token0 and token1 value in token0 for a given pool address, and a amount of token0 and token1.
    /// @param pool Pool address
    /// @param amount0 The amount of token0
    /// @param amount1 The amount of token1
    /// @return value0 The total value in token0
    fn estimated_value_in_token0(pool: ContractAddress, amount0: u256, amount1: u256) -> u256 {
        let pool_dispatcher = IJediSwapV2PoolDispatcher { contract_address: pool };
        let sqrt_price_x96 = pool_dispatcher.get_sqrt_price_X96();

        amount0 + mul_div(
            amount1,
            Q96,
            mul_div(sqrt_price_x96, sqrt_price_x96, Q96)
        )
    }

    /// @notice Computes the token0 and token1 value in token1 for a given pool address, and a amount of token0 and token1.
    /// @param pool Pool address
    /// @param amount0 The amount of token0
    /// @param amount1 The amount of token1
    /// @return value0 The total value in token1
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