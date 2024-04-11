// SPDX-License-Identifier: BUSL-1.1
// Teahouse Finance
// tea_vault_jedi_v2.cairo

use starknet::ContractAddress;
use jediswap_v2_core::libraries::signed_integers::{ i32::i32, i256::i256 };

#[derive(Copy, Drop, Serde, starknet::Store)]
struct FeeConfig {
    /// /// @notice The fee will be sent to this address
    treasury: ContractAddress,
    /// @notice The entry fee in 0.01 bps
    entry_fee: u32,
    /// @notice The exit fee in 0.01 bps
    exit_fee: u32,
    /// @notice The performance fee in 0.01 bps
    performance_fee: u32,
    /// @notice The annual management fee in 0.01 bps
    management_fee: u32
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct Position {
    /// @notice The lower tick of the position's tick range
    tick_lower: i32,
    /// @notice The upper tick of the position's tick range
    tick_upper: i32,
    /// @notice The owner of the position
    liquidity: u128
}

#[derive(Copy, Drop, Serde)]
struct MintCallbackData {
    /// @notice The payer for adding liquidity
    payer: ContractAddress
}

#[derive(Copy, Drop, Serde)]
struct SwapCallbackData {
    /// @notice The swap direction
    zero_for_one: bool
}

#[derive(Drop)]
enum Rounding {
    /// @notice Rounding up while performing mul_div
    Ceiling,
    /// @notice Rounding down while performing mul_div
    Floor
}

#[derive(PartialEq, Drop, Serde, starknet::Store)]
enum CallbackStatus {
    /// @notice The initial status of the callback status
    Initial,
    /// @notice The callback functions ready for being called
    Calling
}

mod Constants {
    const SECONDS_IN_A_YEAR: u256 = consteval_int!(365 * 24 * 60 * 60);
    const FEE_MULTIPLIER: u256 = consteval_int!(1000000);
    const FEE_MULTIPLIER_A_YEAR: u256 = FEE_MULTIPLIER * SECONDS_IN_A_YEAR;
    const MAX_POSITION_LENGTH: u32 = consteval_int!(5);
}

mod Errors {
    const POOL_NOT_INITIALIZED: felt252 = 'Pool is not initialized';
    const INVALID_FEE_CAP: felt252 = 'Invalid fee cap';
    const INVALID_FEE_PERCENTAGE: felt252 = 'Invalid fee percentage';
    const INVALID_SHARE_AMOUNT: felt252 = 'Invalid share amount';
    const POSITION_LENGTH_EXCEEDS_LIMIT: felt252 = 'Position length exceeds limit';
    const INVALID_PRICE_SLIPPAGE: felt252 = 'Invalid price slippage';
    const POSITION_DOES_NOT_EXIST: felt252 = 'Position does not exist';
    const ZERO_LIQUIDITY: felt252 = 'Zero liquidity';
    const SWAP_RATE_LIMIT: felt252 = 'Swap rate limit';
    const CALLER_IS_NOT_MANAGER: felt252 = 'Caller is not manager';
    const CALLER_IS_NOT_REWARD_CLAIMER: felt252 = 'Caller is not reward claimer';
    const INVALID_CALLBACK_STATUS: felt252 = 'Invalid callback status';
    const INVALID_CALLBACK_CALLER: felt252 = 'Invalid callback caller';
    const SWAP_IN_ZERO_LIQUIDITY_REGION: felt252 = 'Swap in zero liquidity region';
    const TRANSACTION_EXPIRED: felt252 = 'Transaction expired';
    const INVALID_SWAP_TOKEN: felt252 = 'Invalid swap token';
    const INVALID_SWAP_RECEIVER: felt252 = 'Invalid swap receiver';
    const INSUFFICIENT_SWAP_RESULT: felt252 = 'Insufficient swap result';
    const INVALID_TOKEN_ORDER: felt252 = 'Invalid token order';
    const INVALID_INDEX: felt252 = 'Invalid index';
    const SET_ARRAY_FAILED:felt252 = 'Set array failed';
    const APPEND_ARRAY_FAILED: felt252 = 'Append array failed';
    const POP_ARRAY_FAILED: felt252 = 'Pop array failed';
}

#[starknet::interface]
trait ITeaVaultJediV2<TContractState> {
    fn DECIMALS_MULTIPLIER(self: @TContractState) -> u256;
    fn manager(self: @TContractState) -> ContractAddress;
    fn reward_contract(self: @TContractState) -> ContractAddress;
    fn reward_claimer(self: @TContractState) -> ContractAddress;
    fn fee_config(self: @TContractState) -> FeeConfig;
    fn pool(self: @TContractState) -> ContractAddress;
    fn last_collect_management_fee(self: @TContractState) -> u64;
    fn asset_token0(self: @TContractState) -> ContractAddress;
    fn asset_token1(self: @TContractState) -> ContractAddress;
    fn get_token0_balance(self: @TContractState) -> u256;
    fn get_token1_balance(self: @TContractState) -> u256;
    fn get_pool_tokens(self: @TContractState) -> (ContractAddress, ContractAddress, u8, u8);
    fn get_pool_info(self: @TContractState) -> (u32, u256, i32);
    fn position_info_ticks(self: @TContractState, tick_lower: i32, tick_upper: i32) -> (u256, u256, u256, u256);
    fn position_info_index(self: @TContractState, index: u32) -> (u256, u256, u256, u256);
    fn all_position_info(self: @TContractState) -> (u256, u256, u256, u256);
    fn vault_all_underlying_assets(self: @TContractState) -> (u256, u256);
    fn estimated_value_in_token0(self: @TContractState) -> u256;
    fn estimated_value_in_token1(self: @TContractState) -> u256;
    fn get_liquidity_for_amounts(self: @TContractState, tick_lower: i32, tick_upper: i32, amount0: u256, amount1: u256) -> u128;
    fn get_amounts_for_liquidity(self: @TContractState, tick_lower: i32, tick_upper: i32, liquidity: u128) -> (u256, u256);
    fn get_all_positions(self: @TContractState) -> Array<Position>;
    fn set_fee_config(ref self: TContractState, fee_config: FeeConfig);
    fn assign_manager(ref self: TContractState, manager: ContractAddress);
    fn assign_reward_contract(ref self: TContractState, reward_contract: ContractAddress);
    fn assign_reward_claimer(ref self: TContractState, reward_claimer: ContractAddress);
    fn collect_management_fee(ref self: TContractState) -> u256;
    fn deposit(ref self: TContractState, shares: u256, amount0_max: u256, amount1_max: u256) -> (u256, u256);
    fn withdraw(ref self: TContractState, shares: u256, amount0_min: u256, amount1_min: u256) -> (u256, u256);
    fn add_liquidity(ref self: TContractState, tick_lower: i32, tick_upper: i32, liquidity: u128, amount0_min: u256, amount1_min: u256, deadline: u64) -> (u256, u256);
    fn remove_liquidity(ref self: TContractState, tick_lower: i32, tick_upper: i32, liquidity: u128, amount0_min: u256, amount1_min: u256, deadline: u64) -> (u256, u256);
    fn collect_position_swap_fee(ref self: TContractState, tick_lower: i32, tick_upper: i32) -> (u128, u128);
    fn collect_all_swap_fee(ref self: TContractState) -> (u128, u128);
    fn swap_input_single(ref self: TContractState, zero_for_one: bool, amount_in: u256, amount_out_min: u256, min_price_in_sqrt_price_x96: u256, deadline: u64) -> u256;
    fn swap_output_single(ref self: TContractState, zero_for_one: bool, amount_out: u256, amount_in_max: u256, max_price_in_sqrt_price_x96: u256, deadline: u64) -> u256;
    fn jediswap_v2_mint_callback(ref self: TContractState, amount0_owed: u256, amount1_owed: u256, callback_data_span: Span<felt252>);
    fn jediswap_v2_swap_callback(ref self: TContractState, amount0_delta: i256, amount1_delta: i256, callback_data_span: Span<felt252>);
    fn claim_reward(ref self: TContractState, claim_selector: felt252, amount: u128, proof: Span<felt252>, reward_token: ContractAddress, receiver: ContractAddress);
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
}

#[starknet::contract]
mod TeaVaultJediV2 {
    use super::{ FeeConfig, Position, MintCallbackData, SwapCallbackData, Rounding, CallbackStatus, Constants, Errors };
    use starknet::{
        contract_address::ContractAddress,
        info::get_block_number,
        ClassHash,
        get_block_timestamp,
        get_caller_address,
        get_contract_address,
        contract_address_to_felt252
    };
    use core::integer::{ u256_from_felt252, BoundedU128 };
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::{ UpgradeableComponent, interface::IUpgradeable } ;
    use openzeppelin::security::{ PausableComponent, ReentrancyGuardComponent };
    use openzeppelin::token::erc20::{
        ERC20Component,
        ERC20ABIDispatcher,
        interface::{ ERC20ABIDispatcherTrait, IERC20Metadata } 
    };
    use alexandria_storage::list::{ List, ListTrait };
    use jediswap_v2_core::jediswap_v2_factory::{ IJediSwapV2FactoryDispatcher, IJediSwapV2FactoryDispatcherTrait };
    use jediswap_v2_core::jediswap_v2_pool::{ IJediSwapV2PoolDispatcher, IJediSwapV2PoolDispatcherTrait };
    use jediswap_v2_core::libraries::{
        tick_math::TickMath,
        signed_integers::{ i32::i32, i256::i256, integer_trait::IntegerTrait },
        full_math::{ mul_div, mul_div_rounding_up },
        math_utils::pow
    };
    use jediswap_v2_periphery::libraries::periphery_payments::PeripheryPayments::pay;
    use tea_vault_jedi_v2::libraries::{
        vault_utils::VaultUtils::{
            get_liquidity_for_amounts,
            get_amounts_for_liquidity,
            position_info,
            estimated_value_in_token0,
            estimated_value_in_token1
        }
    };

    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);
    component!(path: ReentrancyGuardComponent, storage: reentrancy_guard, event: ReentrancyGuardEvent);
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl OwnableTwoStepImpl = OwnableComponent::OwnableTwoStepImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableCamelOnlyImpl = OwnableComponent::OwnableTwoStepCamelOnlyImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20CamelOnlyImpl = ERC20Component::ERC20CamelOnlyImpl<ContractState>;

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl PausableImpl = PausableComponent::PausableImpl<ContractState>;
    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;
    impl ReentrancyGuardInternalImpl = ReentrancyGuardComponent::InternalImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable._upgrade(new_class_hash);
        }
    }

    #[abi(embed_v0)]
    impl ERC20MetadataImpl of IERC20Metadata<ContractState> {
        fn name(self: @ContractState) -> ByteArray {
            self.erc20.name()
        }

        fn symbol(self: @ContractState) -> ByteArray {
            self.erc20.symbol()
        }
    
        fn decimals(self: @ContractState) -> u8 {
            self.DECIMALS.read()
        }
    }

    #[storage]
    struct Storage {
        DECIMALS_MULTIPLIER: u256,
        DECIMALS: u8,
        FEE_CAP: u32,
        manager: ContractAddress,
        reward_contract: ContractAddress,
        reward_claimer: ContractAddress,
        positions: List<Position>,
        fee_config: FeeConfig,
        pool: ContractAddress,
        token0: ContractAddress,
        token1: ContractAddress,
        last_swap_block: u64,
        callback_status: CallbackStatus,
        last_collect_management_fee: u64,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
        #[substorage(v0)]
        reentrancy_guard: ReentrancyGuardComponent::Storage,
        #[substorage(v0)]
        erc20: ERC20Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        TeaVaultV3PairCreated: TeaVaultV3PairCreated,
        FeeConfigChanged: FeeConfigChanged,
        ManagerChanged: ManagerChanged,
        RewardContractChanged: RewardContractChanged,
        RewardClaimerChanged: RewardClaimerChanged,
        ManagementFeeCollected: ManagementFeeCollected,
        DepositShares: DepositShares,
        WithdrawShares: WithdrawShares,
        AddLiquidity: AddLiquidity,
        RemoveLiquidity: RemoveLiquidity,
        Collect: Collect,
        CollectSwapFees: CollectSwapFees,
        Swap: Swap,
        ClaimReward: ClaimReward,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        PausableEvent: PausableComponent::Event,
        #[flat]
        ReentrancyGuardEvent: ReentrancyGuardComponent::Event,
        #[flat]
        ERC20Event: ERC20Component::Event
    }

    #[derive(Drop, starknet::Event)]
    struct TeaVaultV3PairCreated {
        #[key]
        tea_vault_address: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct FeeConfigChanged {
        #[key]
        sender: ContractAddress,
        timestamp: u64,
        fee_config: FeeConfig
    }

    #[derive(Drop, starknet::Event)]
    struct ManagerChanged {
        #[key]
        sender: ContractAddress,
        #[key]
        new_manager: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct RewardContractChanged {
        #[key]
        sender: ContractAddress,
        #[key]
        new_reward_contract: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct RewardClaimerChanged {
        #[key]
        sender: ContractAddress,
        #[key]
        new_reward_claimer: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct ManagementFeeCollected {
        shares: u256
    }

    #[derive(Drop, starknet::Event)]
    struct DepositShares {
        #[key]
        share_owner: ContractAddress,
        shares: u256,
        amount0: u256,
        amount1: u256,
        fee_amount0: u256,
        fee_amount1: u256
    }

    #[derive(Drop, starknet::Event)]
    struct WithdrawShares {
        #[key]
        share_owner: ContractAddress,
        shares: u256,
        amount0: u256,
        amount1: u256,
        fee_shares: u256
    }

    #[derive(Drop, starknet::Event)]
    struct AddLiquidity {
        #[key]
        pool: ContractAddress,
        tick_lower: i32,
        tick_upper: i32,
        liquidity: u128,
        amount0: u256,
        amount1: u256
    }

    #[derive(Drop, starknet::Event)]
    struct RemoveLiquidity {
        #[key]
        pool: ContractAddress,
        tick_lower: i32,
        tick_upper: i32,
        liquidity: u128,
        amount0: u256,
        amount1: u256
    }

    #[derive(Drop, starknet::Event)]
    struct Collect {
        #[key]
        pool: ContractAddress,
        tick_lower: i32,
        tick_upper: i32,
        amount0: u128,
        amount1: u128
    }

    #[derive(Drop, starknet::Event)]
    struct CollectSwapFees {
        #[key]
        pool: ContractAddress,
        amount0: u128,
        amount1: u128,
        fee_amount0: u256,
        fee_amount1: u256
    }

    #[derive(Drop, starknet::Event)]
    struct Swap {
        #[key]
        zero_for_one: bool,
        #[key]
        exact_input: bool,
        amount_in: u256,
        amount_out: u256
    }

    #[derive(Drop, starknet::Event)]
    struct ClaimReward {
        #[key]
        reward_token: ContractAddress,
        #[key]
        receiver: ContractAddress,
        amount: u128
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        factory: ContractAddress,
        token0: ContractAddress,
        token1: ContractAddress,
        fee_tier: u32,
        decimal_offset: u8,
        manager: ContractAddress,
        reward_contract: ContractAddress,
        reward_claimer: ContractAddress,
        fee_cap: u32,
        fee_config: FeeConfig,
        owner: ContractAddress
    ) {
        self.ownable.initializer(owner);
        self.erc20.initializer(name, symbol);

        assert(
            u256_from_felt252(contract_address_to_felt252(token0)) < u256_from_felt252(contract_address_to_felt252(token1)),
            Errors::INVALID_TOKEN_ORDER
        );

        self.DECIMALS_MULTIPLIER.write(pow(10, decimal_offset.into()));
        assert(fee_cap < Constants::FEE_MULTIPLIER.try_into().unwrap(), Errors::INVALID_FEE_CAP);
        self.FEE_CAP.write(fee_cap);
        let factory_dispatcher = IJediSwapV2FactoryDispatcher { contract_address: factory };
        let pool = factory_dispatcher.get_pool(token0, token1, fee_tier);
        assert(contract_address_to_felt252(pool) != 0, Errors::POOL_NOT_INITIALIZED);
        self.pool.write(pool);
        self.token0.write(token0);
        self.token1.write(token1);
        self.DECIMALS.write(decimal_offset + ERC20ABIDispatcher { contract_address: token0 }.decimals());
        self._set_fee_config(fee_config);
        self.manager.write(manager);
        self.reward_contract.write(reward_contract);
        self.reward_claimer.write(reward_claimer);

        self.emit(TeaVaultV3PairCreated { tea_vault_address: get_contract_address() });
    }

    #[abi(embed_v0)]
    impl TeaVaultJediV2Impl of super::ITeaVaultJediV2<ContractState> {
        fn DECIMALS_MULTIPLIER(self: @ContractState) -> u256 {
            self.DECIMALS_MULTIPLIER.read()
        }

        fn manager(self: @ContractState) -> ContractAddress {
            self.manager.read()
        }

        fn reward_contract(self: @ContractState) -> ContractAddress {
            self.reward_contract.read()
        }

        fn reward_claimer(self: @ContractState) -> ContractAddress {
            self.reward_claimer.read()
        }
        
        fn fee_config(self: @ContractState) -> FeeConfig {
            self.fee_config.read()
        }

        fn pool(self: @ContractState) -> ContractAddress {
            self.pool.read()
        }

        fn last_collect_management_fee(self: @ContractState) -> u64 {
            self.last_collect_management_fee.read()
        }

        /// @notice Get asset token0 address
        /// @return token0 Token0 address
        fn asset_token0(self: @ContractState) -> ContractAddress {
            self.token0.read()
        }

        /// @notice Get asset token1 address
        /// @return token1 Token1 address
        fn asset_token1(self: @ContractState) -> ContractAddress {
            self.token1.read()
        }

        /// @notice Get vault balance of token0
        /// @return amount Vault balance of token0
        fn get_token0_balance(self: @ContractState) -> u256 {
            self._get_token_balance(self.token0.read())
        }

        /// @notice Get vault balance of token1
        /// @return amount Vault balance of token1
        fn get_token1_balance(self: @ContractState) -> u256 {
            self._get_token_balance(self.token1.read())
        }

        /// @notice Get pool token info
        /// @return token0 Token0 address
        /// @return token1 Token1 address
        /// @return decimals0 Token0 decimals
        /// @return decimals1 Token1 decimals
        fn get_pool_tokens(self: @ContractState) -> (ContractAddress, ContractAddress, u8, u8) {
            let token0 = self.token0.read();
            let token1 = self.token1.read();
            let token0_dispatcher = ERC20ABIDispatcher { contract_address: token0 };
            let token1_dispatcher = ERC20ABIDispatcher { contract_address: token1 };

            (
                token0,
                token1,
                token0_dispatcher.decimals(),
                token1_dispatcher.decimals()
            )
        }

        /// @notice Get pool price info
        /// @return fee_tier current pool fee tier
        /// @return sqrt_price_X96 Current pool price in sqrt_price_X96
        /// @return tick Current pool price in tick
        fn get_pool_info(self: @ContractState) -> (u32, u256, i32) {
            let pool_dispatcher = IJediSwapV2PoolDispatcher { contract_address: self.pool.read() };

            (pool_dispatcher.get_fee(), pool_dispatcher.get_sqrt_price_X96(), pool_dispatcher.get_tick())
        }

        /// @notice Get position info by specifying tickLower and tickUpper of the position
        /// @param tick_lower Tick lower bound
        /// @param tick_upper Tick upper bound
        /// @return amount0 Current position token0 amount
        /// @return amount1 Current position token1 amount
        /// @return fee0 Pending fee token0 amount
        /// @return fee1 Pending fee token1 amount
        fn position_info_ticks(self: @ContractState, tick_lower: i32, tick_upper: i32) -> (u256, u256, u256, u256) {
            let positions = self.positions.read();
            let (_, position) = self._get_position_by_ticks(@positions, tick_lower, tick_upper);

            position_info(get_contract_address(), self.pool.read(), position)
        }
        
        /// @notice Get position info by specifying position index
        /// @param index Position index
        /// @return amount0 Current position token0 amount
        /// @return amount1 Current position token1 amount
        /// @return fee0 Pending fee token0 amount
        /// @return fee1 Pending fee token1 amount        
        fn position_info_index(self: @ContractState, index: u32) -> (u256, u256, u256, u256) {
            let positions = self.positions.read();
            assert(index < positions.len(), Errors::POSITION_DOES_NOT_EXIST);

            position_info(get_contract_address(), self.pool.read(), positions[index])
        }

        /// @notice Get all position info
        /// @return amount0 All positions token0 amount
        /// @return amount1 All positions token1 amount
        /// @return fee0 All positions pending fee token0 amount
        /// @return fee1 All positions pending fee token1 amount
        fn all_position_info(self: @ContractState) -> (u256, u256, u256, u256) {
            let mut total_amount0 = 0;
            let mut total_amount1 = 0;
            let mut total_fee0 = 0;
            let mut total_fee1 = 0;
            let positions = self.positions.read();
            let this = get_contract_address();
            let pool = self.pool.read();
            let mut i = 0;
            loop {
                if i == positions.len() {
                    break;
                }

                let (amount0, amount1, fee0, fee1) = position_info(this, pool, positions[i]);
                total_amount0 += amount0;
                total_amount1 += amount1;
                total_fee0 += fee0;
                total_fee1 += fee1;

                i += 1;
            };

            (total_amount0, total_amount1, total_fee0, total_fee1)
        }

        /// @notice Get underlying assets hold by this vault
        /// @return amount0 Total token0 amount
        /// @return amount1 Total token1 amount
        fn vault_all_underlying_assets(self: @ContractState) -> (u256, u256) {
            let (mut amount0, mut amount1, fee0, fee1) = self.all_position_info();
            amount0 += (fee0 + self._get_token_balance(self.token0.read()));
            amount1 += (fee1 + self._get_token_balance(self.token1.read()));

            (amount0, amount1)
        }

        /// @notice Get vault value in token0
        /// @return value0 The total value held by the vault in token0
        fn estimated_value_in_token0(self: @ContractState) -> u256 {
            let (amount0, amount1) = self.vault_all_underlying_assets();

            estimated_value_in_token0(self.pool.read(), amount0, amount1)
        }

        /// @notice Get vault value in token1
        /// @return value0 The total value held by the vault in token1
        fn estimated_value_in_token1(self: @ContractState) -> u256 {
            let (amount0, amount1) = self.vault_all_underlying_assets();

            estimated_value_in_token1(self.pool.read(), amount0, amount1)
        }

        /// @notice Calculate liquidity of a position from amount0 and amount1
        /// @param tickLower The lower tick of the position
        /// @param tickUpper The upper tick of the position
        /// @param amount0 The amount of token0
        /// @param amount1 The amount of token1
        /// @return liquidity Calculated liquidity
        fn get_liquidity_for_amounts(
            self: @ContractState,
            tick_lower: i32,
            tick_upper: i32,
            amount0: u256,
            amount1: u256
        ) -> u128 {
            get_liquidity_for_amounts(self.pool.read(), tick_lower, tick_upper, amount0, amount1)
        }

        /// @notice Calculate amount of tokens required for liquidity of a position
        /// @param tickLower The lower tick of the position
        /// @param tickUpper The upper tick of the position
        /// @param liquidity The amount of liquidity
        /// @return amount0 The amount of token0 required
        /// @return amount1 The amount of token1 required
        fn get_amounts_for_liquidity(
            self: @ContractState,
            tick_lower: i32,
            tick_upper: i32,
            liquidity: u128
        ) -> (u256, u256) {
            get_amounts_for_liquidity(self.pool.read(), tick_lower, tick_upper, liquidity)
        }

        /// @notice Get all open positions
        /// @return results Array of all holding positions
        fn get_all_positions(self: @ContractState) -> Array<Position> {
            let mut all_positions: Array<Position> = ArrayTrait::new();
            let positions = self.positions.read();
            let mut i = 0;
            loop {
                if i == positions.len() {
                    break;
                }

                all_positions.append(positions[i]);

                i += 1;
            };

            all_positions
        }

        /// @notice Set fee structure and treasury addresses
        /// @notice Only available to admins
        /// @param fee_config Fee structure to be set
        fn set_fee_config(ref self: ContractState, fee_config: FeeConfig) {
            self.reentrancy_guard.start();
            self.ownable.assert_only_owner();

            self._collect_all_swap_fee();
            self._collect_management_fee();
            self._set_fee_config(fee_config);
            self.reentrancy_guard.end();
        }

        /// @notice Assign fund manager
        /// @notice Only the owner can do this
        /// @param manager Fund manager address
        fn assign_manager(ref self: ContractState, manager: ContractAddress) {
            self.ownable.assert_only_owner();

            self.manager.write(manager);
            self.emit(ManagerChanged { sender: get_caller_address(), new_manager: manager });
        }

        /// @notice Assign reward contract
        /// @notice Only the owner can do this
        /// @param reward_contract Reward contract for DeFi spring
        fn assign_reward_contract(ref self: ContractState, reward_contract: ContractAddress) {
            self.ownable.assert_only_owner();

            self.reward_contract.write(reward_contract);
            self.emit(RewardContractChanged { sender: get_caller_address(), new_reward_contract: reward_contract });
        }

        /// @notice Assign reward claimer
        /// @notice Only the owner can do this
        /// @param reward_claimer Reward claimer for DeFi spring
        fn assign_reward_claimer(ref self: ContractState, reward_claimer: ContractAddress) {
            self.ownable.assert_only_owner();

            self.reward_claimer.write(reward_claimer);
            self.emit(RewardClaimerChanged { sender: get_caller_address(), new_reward_claimer: reward_claimer });
        }

        /// @notice Collect management fee by inflating the share token
        /// @notice Only fund manager can do this
        /// @return collected_shares Share amount collected by minting
        fn collect_management_fee(ref self: ContractState) -> u256 {
            self.reentrancy_guard.start();
            self._assert_only_manager();
    
            let fee_amount = self._collect_management_fee();
            self.reentrancy_guard.end();
            fee_amount
        }

        /// @notice Mint shares and deposit token0 and token1
        /// @param shares Share amount to be mint
        /// @param amount0_max Max token0 amount to be deposited
        /// @param amount1_max Max token1 amount to be deposited
        /// @return deposited0 Deposited token0 amount
        /// @return deposited1 Deposited token1 amount
        fn deposit(ref self: ContractState, shares: u256, amount0_max: u256, amount1_max: u256) -> (u256, u256) {
            self.pausable.assert_not_paused();
            self.reentrancy_guard.start();
            assert(shares != 0, Errors::INVALID_SHARE_AMOUNT);
            self._collect_management_fee();

            let total_shares = self.erc20.total_supply();
            let mut deposited_amount0: u256 = 0;
            let mut deposited_amount1: u256 = 0;
            let token0 = self.token0.read();
            let token1 = self.token1.read();
            let caller = get_caller_address();
            let this = get_contract_address();
            if total_shares == 0 {
                // vault is empty, default to 1:1 share to token0 ratio (offseted by _decimalOffset)
                deposited_amount0 = shares / self.DECIMALS_MULTIPLIER.read();
                pay(token0, caller, this, deposited_amount0);
            }
            else {
                self._collect_all_swap_fee();
                let mut positions = self.positions.read();
                let mut i = 0;
                loop {
                    if i == positions.len() {
                        break;
                    }

                    let mut position = positions[i];
                    let liquidity = self._fraction_of_shares(
                        position.liquidity.into(),
                        shares,
                        total_shares,
                        Rounding::Ceiling
                    ).try_into().unwrap();
                    let (amount0, amount1) = self._add_liquidity_with_callback_data(
                        position.tick_lower,
                        position.tick_upper,
                        liquidity,
                        self._get_mint_callback_data(caller)
                    );
                    deposited_amount0 += amount0;
                    deposited_amount1 += amount1;
                    position.liquidity += liquidity;
                    assert(positions.set(i, position).is_ok(), Errors::SET_ARRAY_FAILED);

                    i += 1;
                };
                let amount0 = self._fraction_of_shares(self._get_token_balance(token0), shares, total_shares, Rounding::Ceiling);
                let amount1 = self._fraction_of_shares(self._get_token_balance(token1), shares, total_shares, Rounding::Ceiling);
                if amount0 > 0 {
                    deposited_amount0 += amount0;
                    pay(token0, caller, this, amount0);
                }
                if amount1 > 0 {
                    deposited_amount1 += amount1;
                    pay(token1, caller, this, amount1);
                }
            }

            assert(deposited_amount0 != 0 || deposited_amount1 != 0, Errors::INVALID_SHARE_AMOUNT);

            // collect entry fee for users
            // do not collect entry fee for fee recipient
            let mut entry_fee_amount0 = 0;
            let mut entry_fee_amount1 = 0;
            if caller != self.fee_config.read().treasury {
                let fee_config = self.fee_config.read();
                entry_fee_amount0 = self._fraction_of_fees(deposited_amount0, fee_config.entry_fee);
                entry_fee_amount1 = self._fraction_of_fees(deposited_amount1, fee_config.entry_fee);
                if entry_fee_amount0 > 0 {
                    deposited_amount0 += entry_fee_amount0;
                    pay(token0, caller, fee_config.treasury, entry_fee_amount0);
                }
                if entry_fee_amount1 > 0 {
                    deposited_amount1 += entry_fee_amount1;
                    pay(token1, caller, fee_config.treasury, entry_fee_amount1);
                }
            }
            // slippage check
            assert((deposited_amount0 <= amount0_max) && (deposited_amount1 <= amount1_max), Errors::INVALID_PRICE_SLIPPAGE);
            self.erc20._mint(caller, shares);

            self.emit(DepositShares { 
                share_owner: caller,
                shares: shares,
                amount0: deposited_amount0,
                amount1: deposited_amount1,
                fee_amount0: entry_fee_amount0,
                fee_amount1: entry_fee_amount1
            });
            self.reentrancy_guard.end();
            (deposited_amount0, deposited_amount1)
        }

        /// @notice Burn shares and withdraw token0 and token1
        /// @param shares Share amount to be burnt
        /// @param amount0_min Min token0 amount to be withdrawn
        /// @param amount1_min Min token1 amount to be withdrawn
        /// @return withdrawn0 Withdrawn token0 amount
        /// @return withdrawn1 Withdrawn token1 amount
        fn withdraw(ref self: ContractState, mut shares: u256, amount0_min: u256, amount1_min: u256) -> (u256, u256) {
            self.pausable.assert_not_paused();
            self.reentrancy_guard.start();
            assert(shares != 0, Errors::INVALID_SHARE_AMOUNT);
            self._collect_management_fee();

            let total_shares = self.erc20.total_supply();
            let fee_config = self.fee_config.read();
            let token0 = self.token0.read();
            let token1 = self.token1.read();
            let caller = get_caller_address();
            let this = get_contract_address();

            let mut exit_fee_amount = 0;
            if caller != fee_config.treasury {
                exit_fee_amount = self._fraction_of_fees(shares, fee_config.exit_fee);
                if exit_fee_amount > 0 {
                    self.erc20._transfer(caller, fee_config.treasury, exit_fee_amount);
                    shares -= exit_fee_amount;
                }
            }
            self.erc20._burn(caller, shares);

            self._collect_all_swap_fee();
            let mut withdrawn_amount0 = self._fraction_of_shares(
                self._get_token_balance(token0),
                shares,
                total_shares,
                Rounding::Floor
            );
            let mut withdrawn_amount1 = self._fraction_of_shares(
                self._get_token_balance(token1),
                shares,
                total_shares,
                Rounding::Floor
            );
            let mut positions = self.positions.read();
            let mut i = 0;
            loop {
                if i == positions.len() {
                    break;
                }

                let mut position = positions[i];
                let liquidity: u128 = self._fraction_of_shares(
                    position.liquidity.into(),
                    shares,
                    total_shares,
                    Rounding::Floor
                ).try_into().unwrap();
                let (amount0, amount1) = self._remove_liquidity(position.tick_lower, position.tick_upper, liquidity);
                self._collect(position.tick_lower, position.tick_upper);
                withdrawn_amount0 += amount0;
                withdrawn_amount1 += amount1;

                position.liquidity -= liquidity;
                assert(positions.set(i , position).is_ok(), Errors::SET_ARRAY_FAILED);

                i += 1;
            };

            i = 0;
            loop {
                let mut positions = self.positions.read();
                if i == positions.len() {
                    break;
                }

                let position: Position = positions[i];
                if position.liquidity == 0 {
                    self._pop_position(ref positions, i);
                }
                else {
                    i += 1;
                }
            };
            // slippage check
            assert((withdrawn_amount0 >= amount0_min) && (withdrawn_amount1 >= amount1_min), Errors::INVALID_PRICE_SLIPPAGE);

            pay(token0, this, caller, withdrawn_amount0);
            pay(token1, this, caller, withdrawn_amount1);

            self.emit(WithdrawShares {
                share_owner: caller,
                shares: shares,
                amount0: withdrawn_amount0,
                amount1: withdrawn_amount1,
                fee_shares: exit_fee_amount
            });
            self.reentrancy_guard.end();
            (withdrawn_amount0, withdrawn_amount1)
        }

        /// @notice Add liquidity to a position from this vault
        /// @notice Only fund manager can do this
        /// @param tick_lower Tick lower bound
        /// @param tick_upper Tick upper bound
        /// @param liquidity Liquidity to be added to the position
        /// @param amount0_min Minimum token0 amount to be added to the position
        /// @param amount1_min Minimum token1 amount to be added to the position
        /// @param deadline Deadline of the transaction, transaction will revert if after this timestamp
        /// @return amount0 Token0 amount added to the position
        /// @return amount1 Token1 amount added to the position
        fn add_liquidity(
            ref self: ContractState,
            tick_lower: i32,
            tick_upper: i32,
            liquidity: u128,
            amount0_min: u256,
            amount1_min: u256,
            deadline: u64
        ) -> (u256, u256) {
            self.reentrancy_guard.start();
            self._assert_only_manager();
            self._check_deadline(deadline);

            let mut positions = self.positions.read();
            let (found, i, mut position) = self._find_position_by_ticks_if_exists(@positions, tick_lower, tick_upper);
            assert(found || positions.len() < Constants::MAX_POSITION_LENGTH, Errors::POSITION_LENGTH_EXCEEDS_LIMIT);

            if found {
                position.liquidity += liquidity;
                assert(positions.set(i, position).is_ok(), Errors::SET_ARRAY_FAILED);
            }
            else {
                assert(
                    positions.append(Position { tick_lower: tick_lower, tick_upper: tick_upper, liquidity: liquidity }).is_ok(),
                    Errors::SET_ARRAY_FAILED
                );
            }
            let (amount0, amount1) = self._add_liquidity(tick_lower, tick_upper, liquidity, amount0_min, amount1_min);

            self.reentrancy_guard.end();
            (amount0, amount1)
        }

        /// @notice Remove liquidity of a position from this vault
        /// @notice Only fund manager can do this
        /// @param tick_lower Tick lower bound
        /// @param tick_upper Tick upper bound
        /// @param liquidity Liquidity to be removed from the position
        /// @param amount0_min Minimum token0 amount to be removed from the position
        /// @param amount1_min Minimum token1 amount to be removed from the position
        /// @param deadline Deadline of the transaction, transaction will revert if after this timestamp
        /// @return amount0 Token0 amount removed from the position
        /// @return amount1 Token1 amount removed from the position
        fn remove_liquidity(
            ref self: ContractState,
            tick_lower: i32,
            tick_upper: i32,
            liquidity: u128,
            amount0_min: u256,
            amount1_min: u256,
            deadline: u64
        ) -> (u256, u256) {
            self.reentrancy_guard.start();
            self._assert_only_manager();
            self._check_deadline(deadline);

            let mut positions = self.positions.read();
            let (i, mut position) = self._get_position_by_ticks(@positions, tick_lower, tick_upper);
            
            if position.liquidity == liquidity {
                self._pop_position(ref positions, i);
            }
            else {
                position.liquidity -= liquidity;
                assert(positions.set(i, position).is_ok(), Errors::SET_ARRAY_FAILED);
            }
            self._collect_position_swap_fee(position);
            let (amount0, amount1) = self._remove_liquidity(tick_lower, tick_upper, liquidity);
            assert((amount0 >= amount0_min) && (amount1 >= amount1_min), Errors::INVALID_PRICE_SLIPPAGE);
            self._collect(tick_lower, tick_upper);
            
            self.reentrancy_guard.end();
            (amount0, amount1)
        }

        /// @notice Collect swap fee of a position
        /// @notice Only fund manager can do this
        /// @param tick_lower Tick lower bound
        /// @param tick_upper Tick upper bound
        /// @return amount0 Token0 amount collected from the position
        /// @return amount1 Token1 amount collected from the position
        fn collect_position_swap_fee(ref self: ContractState, tick_lower: i32, tick_upper: i32) -> (u128, u128) {
            self.reentrancy_guard.start();
            self._assert_only_manager();

            let positions = self.positions.read();
            let (_, position) = self._get_position_by_ticks(@positions, tick_lower, tick_upper);
            let (amount0, amount1) = self._collect_position_swap_fee(position);

            self.reentrancy_guard.end();
            (amount0, amount1)
        }

        /// @notice Collect swap fee of all positions
        /// @notice Only fund manager can do this
        /// @return amount0 Token0 amount collected from the positions
        /// @return amount1 Token1 amount collected from the positions
        fn collect_all_swap_fee(ref self: ContractState) -> (u128, u128) {
            self.reentrancy_guard.start();
            self._assert_only_manager();

            let (amount0, amount1) = self._collect_all_swap_fee();
            
            self.reentrancy_guard.end();
            (amount0, amount1)
        }

        /// @notice Swap tokens on the pool with exact input amount
        /// @notice Only fund manager can do this
        /// @param zero_for_one Swap direction from token0 to token1 or not
        /// @param amount_in Amount of input token
        /// @param amount_out_min Required minimum output token amount
        /// @param min_price_in_sqrt_price_x96 Minimum acceptable price in sqrt_price_x96
        /// @param deadline Deadline of the transaction, transaction will revert if after this timestamp
        /// @return amount_out Output token amount
        fn swap_input_single(
            ref self: ContractState,
            zero_for_one: bool,
            amount_in: u256,
            amount_out_min: u256,
            mut min_price_in_sqrt_price_x96: u256,
            deadline: u64
        ) -> u256 {
            let current_block = get_block_number();
            let last_swap = self.last_swap_block.read();
            assert(current_block > last_swap, Errors::SWAP_RATE_LIMIT);
            self.last_swap_block.write(current_block);
            self.reentrancy_guard.start();
            self._assert_only_manager();
            self._check_deadline(deadline);
            self.callback_status.write(CallbackStatus::Calling);

            let pool_dispatcher = IJediSwapV2PoolDispatcher { contract_address: self.pool.read() };
            if min_price_in_sqrt_price_x96 == 0 {
                if zero_for_one {
                    min_price_in_sqrt_price_x96 = TickMath::MIN_SQRT_RATIO + 1;
                }
                else {
                    min_price_in_sqrt_price_x96 = TickMath::MAX_SQRT_RATIO - 1;
                }
            }
            let (amount0, amount1) = pool_dispatcher.swap(
                get_contract_address(),
                zero_for_one,
                IntegerTrait::<i256>::new(amount_in, false),
                min_price_in_sqrt_price_x96,
                self._get_swap_callback_data(zero_for_one)
            );
            let amount_out = if zero_for_one {
                amount1.mag
            }
            else {
                amount0.mag
            };
            assert (amount_out >= amount_out_min, Errors::INVALID_PRICE_SLIPPAGE);

            self.emit(Swap { zero_for_one: zero_for_one, exact_input: true, amount_in: amount_in, amount_out: amount_out });
            self.callback_status.write(CallbackStatus::Initial);
            self.reentrancy_guard.end();
            amount_out
        }

        /// @notice Swap tokens on the pool with exact output amount
        /// @notice Only fund manager can do this
        /// @param zero_for_one Swap direction from token0 to token1 or not
        /// @param amount_out Output token amount
        /// @param amount_in_max Required maximum input token amount
        /// @param max_price_in_sqrt_price_x96 Maximum acceptable price in sqrtPriceX96
        /// @param deadline Deadline of the transaction, transaction will revert if after this timestamp
        /// @return amount_in Input token amount
        fn swap_output_single(
            ref self: ContractState,
            zero_for_one: bool,
            amount_out: u256,
            amount_in_max: u256,
            mut max_price_in_sqrt_price_x96: u256,
            deadline: u64
        ) -> u256 {
            let current_block = get_block_number();
            let last_swap = self.last_swap_block.read();
            assert(current_block > last_swap, Errors::SWAP_RATE_LIMIT);
            self.last_swap_block.write(current_block);
            self.reentrancy_guard.start();
            self._assert_only_manager();
            self._check_deadline(deadline);
            self.callback_status.write(CallbackStatus::Calling);

            let pool_dispatcher = IJediSwapV2PoolDispatcher { contract_address: self.pool.read() };
            let zero_max_price_in_sqrt_price_x96 = max_price_in_sqrt_price_x96 == 0;
            if zero_max_price_in_sqrt_price_x96 {
                if zero_for_one {
                    max_price_in_sqrt_price_x96 = TickMath::MIN_SQRT_RATIO + 1;
                }
                else {
                    max_price_in_sqrt_price_x96 = TickMath::MAX_SQRT_RATIO - 1;
                }
            }
            let (amount0, amount1) = pool_dispatcher.swap(
                get_contract_address(),
                zero_for_one,
                IntegerTrait::<i256>::new(amount_out, true),
                max_price_in_sqrt_price_x96,
                self._get_swap_callback_data(zero_for_one)
            );
            let (amount_in, amount_out_received) = if zero_for_one {
                (amount0.mag, amount1.mag)
            }
            else {
                (amount1.mag, amount0.mag)
            };

            // it's technically possible to not receive the full output amount,
            // so if no price limit has been specified, require this possibility away
            assert (!zero_max_price_in_sqrt_price_x96 || amount_out == amount_out_received, Errors::INVALID_PRICE_SLIPPAGE);
            assert (amount_in <= amount_in_max, Errors::INVALID_PRICE_SLIPPAGE);

            self.emit(Swap {zero_for_one: zero_for_one, exact_input: false, amount_in: amount_in, amount_out: amount_out});
            self.callback_status.write(CallbackStatus::Initial);
            self.reentrancy_guard.end();
            amount_in
        }

        fn jediswap_v2_mint_callback(
            ref self: ContractState,
            amount0_owed: u256,
            amount1_owed: u256,
            mut callback_data_span: Span<felt252>
        ) {
            assert(self.callback_status.read() == CallbackStatus::Calling, Errors::INVALID_CALLBACK_STATUS);
            let caller = get_caller_address();
            assert(caller == self.pool.read(), Errors::INVALID_CALLBACK_CALLER);
            
            let decoded_data = Serde::<MintCallbackData>::deserialize(ref callback_data_span).unwrap();
            if amount0_owed > 0 {
                pay(self.token0.read(), decoded_data.payer, caller, amount0_owed);
            }
            if amount1_owed > 0 {
                pay(self.token1.read(), decoded_data.payer, caller, amount1_owed);
            }
        }

        fn jediswap_v2_swap_callback(
            ref self: ContractState,
            amount0_delta: i256,
            amount1_delta: i256,
            mut callback_data_span: Span<felt252>
        ) {
            assert(self.callback_status.read() == CallbackStatus::Calling, Errors::INVALID_CALLBACK_STATUS);
            let caller = get_caller_address();
            assert(caller == self.pool.read(), Errors::INVALID_CALLBACK_CALLER);
            let zero = IntegerTrait::<i256>::new(0, false);
            assert(!(amount0_delta == zero) && !(amount1_delta == zero), Errors::SWAP_IN_ZERO_LIQUIDITY_REGION);

            let decoded_data = Serde::<SwapCallbackData>::deserialize(ref callback_data_span).unwrap();
            let (is_exact_input, amount_to_pay) = if amount0_delta > zero {
                (decoded_data.zero_for_one, amount0_delta.mag)
            } 
            else {
                (!decoded_data.zero_for_one, amount1_delta.mag)
            };

            if is_exact_input == decoded_data.zero_for_one {
                pay(self.token0.read(), get_contract_address(), caller, amount_to_pay);
            }
            else {
                pay(self.token1.read(), get_contract_address(), caller, amount_to_pay);
            }
        }

        /// @notice Claim reward token and transfer to receiver for donating vault asset back
        /// @notice Only owner can do this
        /// @param claim_selector Function selector of claiming reward token
        /// @param amount Reward amount
        /// @param proof Merkle proof for claiming reward
        /// @param reward_token Reward token contract address
        /// @param receiver Reward token receiver
        fn claim_reward(
            ref self: ContractState,
            claim_selector: felt252,
            amount: u128,
            proof: Span<felt252>,
            reward_token: ContractAddress,
            receiver: ContractAddress
        ) {
            self._assert_only_reward_claimer();
            self.reentrancy_guard.start();

            let mut calldata: Array<felt252> = ArrayTrait::new();
            Serde::serialize(@amount, ref calldata);
            Serde::serialize(@proof, ref calldata);
            let mut res = starknet::call_contract_syscall(
                address: self.reward_contract.read(),
                entry_point_selector: claim_selector,
                calldata: calldata.span(),
            );

            if res.is_ok() {
                if reward_token != self.token0.read() && reward_token != self.token1.read() {
                    pay(reward_token, get_contract_address(), receiver, amount.into());
                    self.emit(ClaimReward { reward_token: reward_token, receiver: receiver, amount: amount });
                }
                else {
                    self.emit(ClaimReward { reward_token: reward_token, receiver: get_contract_address(), amount: amount });
                }    
            }
            
            self.reentrancy_guard.end();
        }

        fn pause(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.pausable._pause();
        }

        fn unpause(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.pausable._unpause();
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _set_fee_config(ref self: ContractState, fee_config: FeeConfig) {
            let cap = self.FEE_CAP.read();
            assert(fee_config.entry_fee + fee_config.exit_fee <= cap, Errors::INVALID_FEE_PERCENTAGE);
            assert(fee_config.performance_fee <= cap, Errors::INVALID_FEE_PERCENTAGE);
            assert(fee_config.management_fee <= cap, Errors::INVALID_FEE_PERCENTAGE);

            self.fee_config.write(fee_config);
            self.emit(FeeConfigChanged { sender: get_caller_address(), timestamp: get_block_timestamp(), fee_config: fee_config });
        }
        
        fn _position_burn0_and_collect_from_pool(ref self: ContractState, position: Position) -> (u128, u128) {
            let pool_dispatcher = IJediSwapV2PoolDispatcher { contract_address: self.pool.read() };
            pool_dispatcher.burn(position.tick_lower, position.tick_upper, 0);
            self._collect(position.tick_lower, position.tick_upper)
        }

        fn _collect_position_swap_fee(ref self: ContractState, position: Position) -> (u128, u128) {
            let (amount0, amount1) = self._position_burn0_and_collect_from_pool(position);
            self._collect_performance_fee(amount0, amount1);

            (amount0, amount1)
        }

        fn _collect_all_swap_fee(ref self: ContractState) -> (u128, u128) {
            let positions = self.positions.read();
            let mut total0 = 0;
            let mut total1 = 0;
            let mut i = 0;
            loop {
                if i == positions.len() {
                    break;
                }

                let position = positions[i];
                let (amount0, amount1) = self._position_burn0_and_collect_from_pool(position);
                total0 += amount0;
                total1 += amount1;

                i += 1;
            };
            self._collect_performance_fee(total0, total1);

            (total0, total1)
        }

        fn _get_mint_callback_data(self: @ContractState, payer: ContractAddress) -> Array<felt252> {
            let mut mint_callback_data: Array<felt252> = ArrayTrait::new();
            let mint_callback_data_struct = MintCallbackData { payer: payer };
            Serde::<MintCallbackData>::serialize(@mint_callback_data_struct, ref mint_callback_data);

            mint_callback_data
        }

        fn _get_swap_callback_data(self: @ContractState, zero_for_one: bool) -> Array<felt252> {
            let mut swap_callback_data: Array<felt252> = ArrayTrait::new();
            let swap_callback_data_struct = SwapCallbackData {zero_for_one: zero_for_one};
            Serde::<SwapCallbackData>::serialize(@swap_callback_data_struct, ref swap_callback_data);

            swap_callback_data
        }

        fn _add_liquidity(
            ref self: ContractState,
            tick_lower: i32,
            tick_upper: i32,
            liquidity: u128,
            amount0_min: u256,
            amount1_min: u256,
        ) -> (u256, u256)  {
            let (amount0, amount1) = self._add_liquidity_with_callback_data(
                tick_lower,
                tick_upper,
                liquidity,
                self._get_mint_callback_data(get_contract_address())
            );
            assert(amount0 >= amount0_min && amount1 >= amount1_min, Errors::INVALID_PRICE_SLIPPAGE);

            (amount0, amount1)
        }

        fn _add_liquidity_with_callback_data(
            ref self: ContractState,
            tick_lower: i32,
            tick_upper: i32,
            liquidity: u128,
            callback_data: Array<felt252>
        ) -> (u256, u256) {
            self._check_liquidity(liquidity);
            self.callback_status.write(CallbackStatus::Calling);
            let pool = self.pool.read();
            let pool_dispatcher = IJediSwapV2PoolDispatcher { contract_address: pool };
            let (amount0, amount1) = pool_dispatcher.mint(get_contract_address(), tick_lower, tick_upper, liquidity, callback_data);
            self.callback_status.write(CallbackStatus::Initial);

            self.emit(AddLiquidity {
                pool: pool,
                tick_lower: tick_lower,
                tick_upper: tick_upper,
                liquidity: liquidity,
                amount0: amount0,
                amount1: amount1
            });  
            (amount0, amount1)
        }

        fn _remove_liquidity(ref self: ContractState, tick_lower: i32, tick_upper: i32, liquidity: u128) -> (u256, u256) {
            self._check_liquidity(liquidity);
            let pool = self.pool.read();
            let pool_dispatcher = IJediSwapV2PoolDispatcher { contract_address: pool };
            let (amount0, amount1) = pool_dispatcher.burn(tick_lower, tick_upper, liquidity);

            self.emit(RemoveLiquidity {
                pool: pool,
                tick_lower: tick_lower,
                tick_upper: tick_upper,
                liquidity: liquidity,
                amount0: amount0,
                amount1: amount1
            });
            (amount0, amount1)
        }

        fn _collect(ref self: ContractState, tick_lower: i32, tick_upper: i32) -> (u128, u128) {
            let pool = self.pool.read();
            let (amount0, amount1) = IJediSwapV2PoolDispatcher { contract_address: pool }.collect(
                get_contract_address(),
                tick_lower,
                tick_upper,
                BoundedU128::max(),
                BoundedU128::max()
            );

            self.emit(Collect {
                pool: pool,
                tick_lower: tick_lower,
                tick_upper: tick_upper,
                amount0: amount0,
                amount1: amount1
            });
            (amount0, amount1)
        }

        fn _collect_management_fee(ref self: ContractState) -> u256 {
            let time_diff = get_block_timestamp() - self.last_collect_management_fee.read();
            if time_diff > 0 {
                let fee_config = self.fee_config.read();
                let fee_times_time_diff: u256 = fee_config.management_fee.into() * time_diff.into();
                let mut denominator: u256 = if Constants::FEE_MULTIPLIER_A_YEAR > fee_times_time_diff {
                    Constants::FEE_MULTIPLIER_A_YEAR - fee_times_time_diff
                }
                else {
                    1
                };
                let collected_shares = mul_div_rounding_up(self.erc20.total_supply(), fee_times_time_diff, denominator);
                if collected_shares > 0 {
                    self.erc20._mint(fee_config.treasury, collected_shares);
                    self.emit(ManagementFeeCollected { shares: collected_shares });
                }
                self.last_collect_management_fee.write(get_block_timestamp());

                collected_shares
            }
            else {
                0
            }
        }

        fn _collect_performance_fee(ref self: ContractState, amount0: u128, amount1: u128) {
            let fee_config = self.fee_config.read();
            let performance_fee_amount0 = self._fraction_of_fees(amount0.into(), fee_config.performance_fee);
            let performance_fee_amount1 = self._fraction_of_fees(amount1.into(), fee_config.performance_fee);
            if performance_fee_amount0 > 0 {
                pay(self.token0.read(), get_contract_address(), fee_config.treasury, performance_fee_amount0);
            }
            if performance_fee_amount1 > 0 {
                pay(self.token1.read(), get_contract_address(), fee_config.treasury, performance_fee_amount1);
            }

            self.emit(CollectSwapFees {
                pool: self.pool.read(),
                amount0: amount0,
                amount1: amount1,
                fee_amount0: performance_fee_amount0,
                fee_amount1: performance_fee_amount1
            });
        }

        fn _find_position_by_ticks(
            self: @ContractState,
            positions: @List<Position>,
            tick_lower: i32,
            tick_upper: i32,
            raise_error_if_not_found: bool
        ) -> (bool, u32, Position) {
            let mut i = 0;
            let mut found = false;
            let position = loop {
                if i == positions.len() {
                    assert(!raise_error_if_not_found, Errors::POSITION_DOES_NOT_EXIST);
                    break (Position { tick_lower: tick_lower, tick_upper: tick_upper, liquidity: 0 });
                }

                let position_i: Position = positions[i];
                if (position_i.tick_lower == tick_lower) && (position_i.tick_upper == tick_upper) {
                    found = true;
                    break position_i;
                }

                i += 1;
            };

            (found, i, position)
        }

        fn _find_position_by_ticks_if_exists(
            self: @ContractState,
            positions: @List<Position>,
            tick_lower: i32,
            tick_upper: i32
        ) -> (bool, u32, Position) {
            self._find_position_by_ticks(positions, tick_lower, tick_upper, false)
        }

        fn _get_position_by_ticks(
            self: @ContractState,
            positions: @List<Position>,
            tick_lower: i32,
            tick_upper: i32 
        ) -> (u32, Position) {
            let (_, i, position) = self._find_position_by_ticks(positions, tick_lower, tick_upper, true);

            (i, position)
        }

        fn _pop_position(ref self: ContractState, ref positions: List<Position>, index: u32) {
            assert(positions.set(index, positions[positions.len() - 1]).is_ok(), Errors::SET_ARRAY_FAILED);
            assert(positions.pop_front().is_ok(), Errors::POP_ARRAY_FAILED);
        }

        fn _fraction_of_shares(
            self: @ContractState,
            total_assets: u256,
            shares: u256,
            total_shares: u256,
            rounding: Rounding
        ) -> u256 {
            match rounding {
                Rounding::Ceiling => mul_div_rounding_up(total_assets, shares, total_shares),
                Rounding::Floor => mul_div(total_assets, shares, total_shares)
            }
        }

        fn _fraction_of_fees(self: @ContractState, base_amount: u256, fee: u32) -> u256 {
            mul_div_rounding_up(base_amount, fee.into(), Constants::FEE_MULTIPLIER)
        }

        fn _get_token_balance(self: @ContractState, token: ContractAddress) -> u256 {
            let dispatcher = ERC20ABIDispatcher { contract_address: token };

            dispatcher.balance_of(get_contract_address())
        }

        fn _assert_only_manager(self: @ContractState) {
            assert(get_caller_address() == self.manager.read(), Errors::CALLER_IS_NOT_MANAGER);
        }

        fn _assert_only_reward_claimer(self: @ContractState) {
            assert(get_caller_address() == self.reward_claimer.read(), Errors::CALLER_IS_NOT_REWARD_CLAIMER);
        }

        fn _check_liquidity(self: @ContractState, liquidity: u128) {
            assert(liquidity != 0, Errors::ZERO_LIQUIDITY);
        }

        fn _check_deadline(self: @ContractState, deadline: u64) {
            assert(deadline >= get_block_timestamp(), Errors::TRANSACTION_EXPIRED);
        }
    }
}
