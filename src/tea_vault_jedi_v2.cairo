use starknet::ContractAddress;
use yas_core::numbers::signed_integer::{ i32::i32, i256::i256 };

#[derive(Copy, Drop, Serde, starknet::Store)]
struct FeeConfig {
    treasury: ContractAddress,
    entry_fee: u32,
    exit_fee: u32,
    performance_fee: u32,
    management_fee: u32
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct Position {
    tick_lower: i32,
    tick_upper: i32,
    liquidity: u128
}

#[derive(Copy, Drop, Serde)]
struct MintCallbackData {
    payer: ContractAddress
}

#[derive(Copy, Drop, Serde)]
struct SwapCallbackData {
    zero_for_one: bool
}

#[derive(PartialEq, Drop, Serde, starknet::Store)]
enum CallbackStatus {
    Initial,
    Calling
}

mod Constants {
    const SECONDS_IN_A_YEAR: u256 = consteval_int!(365 * 24 * 60 * 60);
    const FEE_MULTIPLIER: u256 = consteval_int!(1000000);
    const MAX_POSITION_LENGTH: u8 = consteval_int!(5);
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
    const INVALID_CALLBACK_STATUS: felt252 = 'Invalid callback status';
    const INVALID_CALLBACK_CALLER: felt252 = 'Invalid callback caller';
    const SWAP_IN_ZERO_LIQUIDITY_REGION: felt252 = 'Swap in zero liquidity region';
    const TRANSACTION_EXPIRED: felt252 = 'Transaction expired';
    const INVALID_SWAP_TOKEN: felt252 = 'Invalid swap token';
    const INVALID_SWAP_RECEIVER: felt252 = 'Invalid swap receiver';
    const INSUFFICIENT_SWAP_RESULT: felt252 = 'Insufficient swap result';
    const INVALID_TOKEN_ORDER: felt252 = 'Invalid token order';
    const INVALID_INDEX: felt252 = 'Invalid index';
}

#[starknet::interface]
trait ITeaVaultJediV2<TContractState> {
    fn DECIMALS_MULTIPLIER(self: @TContractState) -> u256;
    fn manager(self: @TContractState) -> ContractAddress;
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
    fn position_info_index(self: @TContractState, index: u8) -> (u256, u256, u256, u256);
    fn all_position_info(self: @TContractState) -> (u256, u256, u256, u256);
    fn vault_all_underlying_assets(self: @TContractState) -> (u256, u256);
    fn estimated_value_in_token0(self: @TContractState) -> u256;
    fn estimated_value_in_token1(self: @TContractState) -> u256;
    fn get_liquidity_for_amounts(self: @TContractState, tick_lower: i32, tick_upper: i32, amount0: u256, amount1: u256) -> u128;
    fn get_amounts_for_liquidity(self: @TContractState, tick_lower: i32, tick_upper: i32, liquidity: u128) -> (u256, u256);
    fn get_all_positions(self: @TContractState) -> Array<Position>;
    fn set_fee_config(ref self: TContractState, fee_config: FeeConfig);
    fn assign_manager(ref self: TContractState, manager: ContractAddress);
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
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
}

#[starknet::contract]
mod TeaVaultJediV2 {
    use super::{ FeeConfig, Position, MintCallbackData, SwapCallbackData, CallbackStatus, Constants, Errors };
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
    use yas_core::numbers::signed_integer::{ i32::i32, i256::i256, integer_trait::IntegerTrait };
    use yas_core::utils::math_utils::{ FullMath::{ mul_div, mul_div_rounding_up }, pow };
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin::security::{ PausableComponent, ReentrancyGuardComponent };
    use openzeppelin::token::erc20::{
        ERC20Component,
        ERC20ABIDispatcher,
        interface::{ ERC20ABIDispatcherTrait, IERC20Metadata } 
    };
    use jediswap_v2_core::jediswap_v2_factory::{ IJediSwapV2FactoryDispatcher, IJediSwapV2FactoryDispatcherTrait };
    use jediswap_v2_core::jediswap_v2_pool::{ IJediSwapV2PoolDispatcher, IJediSwapV2PoolDispatcherTrait };
    use jediswap_v2_core::libraries::tick_math::TickMath;
    use jediswap_v2_periphery::libraries::periphery_payments::PeripheryPayments::pay;
    use tea_vault_jedi_v2::libraries::{
        ownable::OwnableComponent,
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
        fn name(self: @ContractState) -> felt252 {
            self.erc20.name()
        }

        fn symbol(self: @ContractState) -> felt252 {
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
        position_length: u8,
        positions: LegacyMap<u8, Position>,
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
        ManagementFeeCollected: ManagementFeeCollected,
        DepositShares: DepositShares,
        WithdrawShares: WithdrawShares,
        AddLiquidity: AddLiquidity,
        RemoveLiquidity: RemoveLiquidity,
        Collect: Collect,
        CollectSwapFees: CollectSwapFees,
        Swap: Swap,
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

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: felt252,
        symbol: felt252,
        factory: ContractAddress,
        token0: ContractAddress,
        token1: ContractAddress,
        fee_tier: u32,
        decimal_offset: u8,
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
        
        fn fee_config(self: @ContractState) -> FeeConfig {
            self.fee_config.read()
        }

        fn pool(self: @ContractState) -> ContractAddress {
            self.pool.read()
        }

        fn last_collect_management_fee(self: @ContractState) -> u64 {
            self.last_collect_management_fee.read()
        }

        fn asset_token0(self: @ContractState) -> ContractAddress {
            self.token0.read()
        }

        fn asset_token1(self: @ContractState) -> ContractAddress {
            self.token1.read()
        }

        fn get_token0_balance(self: @ContractState) -> u256 {
            self._get_token_balance(self.token0.read())
        }

        fn get_token1_balance(self: @ContractState) -> u256 {
            self._get_token_balance(self.token1.read())
        }

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

        fn get_pool_info(self: @ContractState) -> (u32, u256, i32) {
            let pool_dispatcher = IJediSwapV2PoolDispatcher { contract_address: self.pool.read() };

            (pool_dispatcher.get_fee(), pool_dispatcher.get_sqrt_price_X96(), pool_dispatcher.get_tick())
        }

        fn position_info_ticks(self: @ContractState, tick_lower: i32, tick_upper: i32) -> (u256, u256, u256, u256) {
            let position_length = self.position_length.read();
            let mut i: u8 = 0;
            let mut find = false;
            let (amount0, amount1, fee0, fee1) = loop {
                if i == position_length {
                    break (0, 0, 0, 0);
                }

                let position = self.positions.read(i);
                if (position.tick_lower == tick_lower) && (position.tick_upper == tick_upper) {
                    find = true;
                    break position_info(get_contract_address(), self.pool.read(), position);
                }

                i += 1;
            };

            assert(find, Errors::POSITION_DOES_NOT_EXIST);
            (amount0, amount1, fee0, fee1)
        }
        
        fn position_info_index(self: @ContractState, index: u8) -> (u256, u256, u256, u256) {
            assert(index < self.position_length.read(), Errors::POSITION_DOES_NOT_EXIST);

            position_info(get_contract_address(), self.pool.read(), self.positions.read(index))
        }

        fn all_position_info(self: @ContractState) -> (u256, u256, u256, u256) {
            let mut total_amount0 = 0;
            let mut total_amount1 = 0;
            let mut total_fee0 = 0;
            let mut total_fee1 = 0;
            let position_length = self.position_length.read();
            let this = get_contract_address();
            let pool = self.pool.read();
            let mut i: u8 = 0;
            loop {
                if i == position_length {
                    break;
                }

                let (amount0, amount1, fee0, fee1) = position_info(this, pool, self.positions.read(i));
                total_amount0 += amount0;
                total_amount1 += amount1;
                total_fee0 += fee0;
                total_fee1 += fee1;

                i += 1;
            };

            (total_amount0, total_amount1, total_fee0, total_fee1)
        }

        fn vault_all_underlying_assets(self: @ContractState) -> (u256, u256) {
            let (mut amount0, mut amount1, fee0, fee1) = self.all_position_info();
            amount0 += (fee0 + self._get_token_balance(self.token0.read()));
            amount1 += (fee1 + self._get_token_balance(self.token1.read()));

            (amount0, amount1)
        }

        fn estimated_value_in_token0(self: @ContractState) -> u256 {
            let (amount0, amount1) = self.vault_all_underlying_assets();

            estimated_value_in_token0(self.pool.read(), amount0, amount1)
        }

        fn estimated_value_in_token1(self: @ContractState) -> u256 {
            let (amount0, amount1) = self.vault_all_underlying_assets();

            estimated_value_in_token1(self.pool.read(), amount0, amount1)
        }

        fn get_liquidity_for_amounts(
            self: @ContractState,
            tick_lower: i32,
            tick_upper: i32,
            amount0: u256,
            amount1: u256
        ) -> u128 {
            get_liquidity_for_amounts(self.pool.read(), tick_lower, tick_upper, amount0, amount1)
        }

        fn get_amounts_for_liquidity(
            self: @ContractState,
            tick_lower: i32,
            tick_upper: i32,
            liquidity: u128
        ) -> (u256, u256) {
            get_amounts_for_liquidity(self.pool.read(), tick_lower, tick_upper, liquidity)
        }

        fn get_all_positions(self: @ContractState) -> Array<Position> {
            let mut all_positions: Array<Position> = ArrayTrait::new();
            let position_length = self.position_length.read();
            let mut i: u8 = 0;
            loop {
                if i == position_length {
                    break;
                }

                all_positions.append(self.positions.read(i));

                i += 1;
            };

            all_positions
        }

        fn set_fee_config(ref self: ContractState, fee_config: FeeConfig) {
            self.reentrancy_guard.start();
            self.ownable.assert_only_owner();

            self._collect_all_swap_fee();
            self._collect_management_fee();
            self._set_fee_config(fee_config);
            self.reentrancy_guard.end();
        }

        fn assign_manager(ref self: ContractState, manager: ContractAddress) {
            self.ownable.assert_only_owner();

            self.manager.write(manager);
            self.emit(ManagerChanged { sender: get_caller_address(), new_manager: manager });
        }

        fn collect_management_fee(ref self: ContractState) -> u256 {
            self.reentrancy_guard.start();
            self._assert_only_manager();
    
            let fee_amount = self._collect_management_fee();
            self.reentrancy_guard.end();
            fee_amount
        }

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
                let position_length = self.position_length.read();
                let mut i: u8 = 0;
                loop {
                    if i == position_length {
                        break;
                    }

                    let mut position = self.positions.read(i);
                    let liquidity = mul_div_rounding_up(position.liquidity.into(), shares, total_shares).try_into().unwrap();
                    let (amount0, amount1) = self._add_liquidity_with_callback_data(
                        position.tick_lower,
                        position.tick_upper,
                        liquidity,
                        self._get_mint_callback_data(caller)
                    );
                    deposited_amount0 += amount0;
                    deposited_amount1 += amount1;
                    position.liquidity += liquidity;
                    self.positions.write(i, position);

                    i += 1;
                };
                let amount0 = mul_div_rounding_up(self._get_token_balance(token0), shares, total_shares);
                let amount1 = mul_div_rounding_up(self._get_token_balance(token1), shares, total_shares);
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
            let fee_config = self.fee_config.read();
            let mut entry_fee_amount0 = 0;
            let mut entry_fee_amount1 = 0;
            if caller != fee_config.treasury {
                entry_fee_amount0 = mul_div_rounding_up(deposited_amount0, fee_config.entry_fee.into(), Constants::FEE_MULTIPLIER);
                entry_fee_amount1 = mul_div_rounding_up(deposited_amount1, fee_config.entry_fee.into(), Constants::FEE_MULTIPLIER);
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
                exit_fee_amount = mul_div_rounding_up(shares, fee_config.exit_fee.into(), Constants::FEE_MULTIPLIER);
                if exit_fee_amount > 0 {
                    self.erc20._transfer(caller, fee_config.treasury, exit_fee_amount);
                    shares -= exit_fee_amount;
                }
            }
            self.erc20._burn(caller, shares);

            self._collect_all_swap_fee();
            let mut withdrawn_amount0 = mul_div(self._get_token_balance(token0), shares, total_shares);
            let mut withdrawn_amount1 = mul_div(self._get_token_balance(token1), shares, total_shares);
            let position_length = self.position_length.read();
            let mut i: u8 = 0;
            loop {
                if i == position_length {
                    break;
                }

                let mut position = self.positions.read(i);
                let liquidity: u128 = mul_div(position.liquidity.into(), shares, total_shares).try_into().unwrap();
                let (amount0, amount1) = self._remove_liquidity(position.tick_lower, position.tick_upper, liquidity);
                self._collect(position.tick_lower, position.tick_upper);
                withdrawn_amount0 += amount0;
                withdrawn_amount1 += amount1;

                position.liquidity -= liquidity;
                self.positions.write(i , position);

                i += 1;
            };

            i = 0;
            loop {
                let position_length = self.position_length.read();
                if i == position_length {
                    break;
                }

                if self.positions.read(i).liquidity == 0 {
                    self.positions.write(i, self.positions.read(position_length - 1));
                    self.position_length.write(position_length - 1);
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

            let position_length = self.position_length.read();
            let mut find = false;
            let mut i: u8 = 0;
            let (mut amount0, mut amount1) = loop {
                if i == position_length {
                    break (0, 0);
                }

                let mut position = self.positions.read(i);
                if (position.tick_lower == tick_lower) && (position.tick_upper == tick_upper) {
                    let (add0, add1) = self._add_liquidity(tick_lower, tick_upper, liquidity, amount0_min, amount1_min);
                    position.liquidity += liquidity;
                    self.positions.write(i, position);
                    find = true;
                    break (add0, add1);
                }

                i += 1;
            };

            if !find {
                assert(i < Constants::MAX_POSITION_LENGTH, Errors::POSITION_LENGTH_EXCEEDS_LIMIT);
                let (add0, add1) = self._add_liquidity(tick_lower, tick_upper, liquidity, amount0_min, amount1_min);
                amount0 = add0;
                amount1 = add1;
                self.positions.write(i, Position { tick_lower: tick_lower, tick_upper: tick_upper, liquidity: liquidity });
                self.position_length.write(position_length + 1);
            }
            self.reentrancy_guard.end();
            (amount0, amount1)
        }

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

            let position_length = self.position_length.read();
            let mut i = 0;
            let mut find = false;
            let (amount0, amount1) = loop {
                if i == position_length {
                    break (0, 0);
                }

                let mut position = self.positions.read(i);
                if (position.tick_lower == tick_lower) && (position.tick_upper == tick_upper) {
                    self._collect_position_swap_fee(position);

                    let (remove0, remove1) = self._remove_liquidity(tick_lower, tick_upper, liquidity);
                    assert((remove0 >= amount0_min) && (remove1 >= amount1_min), Errors::INVALID_PRICE_SLIPPAGE);
                    self._collect(tick_lower, tick_upper);

                    if position.liquidity == liquidity {
                        self.positions.write(i, self.positions.read(position_length - 1));
                        self.position_length.write(position_length - 1);
                    }
                    else {
                        position.liquidity -= liquidity;
                        self.positions.write(i, position);
                    }
                    find = true;
                    break (remove0, remove1);
                }

                i += 1;
            };
            assert(find, Errors::POSITION_DOES_NOT_EXIST);
            self.reentrancy_guard.end();
            (amount0, amount1)
        }

        fn collect_position_swap_fee(ref self: ContractState, tick_lower: i32, tick_upper: i32) -> (u128, u128) {
            self.reentrancy_guard.start();
            self._assert_only_manager();

            let position_length = self.position_length.read();
            let mut i = 0;
            let mut find = false;
            let (amount0, amount1) = loop {
                if i == position_length {
                    break (0, 0);
                }

                let position = self.positions.read(i);
                if (position.tick_lower == tick_lower) && (position.tick_upper == tick_upper) {
                    find = true;
                    break self._collect_position_swap_fee(position);
                }

                i += 1;
            };
            assert(find, Errors::POSITION_DOES_NOT_EXIST);
            self.reentrancy_guard.end();
            (amount0, amount1)
        }

        fn collect_all_swap_fee(ref self: ContractState) -> (u128, u128) {
            self.reentrancy_guard.start();
            self._assert_only_manager();

            let (amount0, amount1) = self._collect_all_swap_fee();
            self.reentrancy_guard.end();
            (amount0, amount1)
        }

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

            self.emit(Swap {zero_for_one: zero_for_one, exact_input: true, amount_in: amount_in, amount_out: amount_out});
            self.last_swap_block.write(current_block);
            self.callback_status.write(CallbackStatus::Initial);
            self.reentrancy_guard.end();
            amount_out
        }

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
            self.last_swap_block.write(current_block);
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

        fn _collect_position_swap_fee(ref self: ContractState, position: Position) -> (u128, u128) {
            let pool_dispatcher = IJediSwapV2PoolDispatcher { contract_address: self.pool.read() };
            pool_dispatcher.burn(position.tick_lower, position.tick_upper, 0);
            let (amount0, amount1) = self._collect(position.tick_lower, position.tick_upper);
            self._collect_performance_fee(amount0, amount1);

            (amount0, amount1)
        }

        fn _collect_all_swap_fee(ref self: ContractState) -> (u128, u128) {
            let pool_dispatcher = IJediSwapV2PoolDispatcher { contract_address: self.pool.read() };
            let position_length = self.position_length.read();
            let mut total0 = 0;
            let mut total1 = 0;
            let mut i: u8 = 0;
            loop {
                if i == position_length {
                    break;
                }

                let position = self.positions.read(i);
                pool_dispatcher.burn(position.tick_lower, position.tick_upper, 0);
                let (amount0, amount1) = self._collect(position.tick_lower, position.tick_upper);
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
                let fee_multiplier_a_year: u256 = Constants::FEE_MULTIPLIER * Constants::SECONDS_IN_A_YEAR;
                let mut denominator: u256 = if fee_multiplier_a_year > fee_times_time_diff {
                    fee_multiplier_a_year - fee_times_time_diff
                }
                else {
                    1
                };
                let collected_shares = mul_div_rounding_up(self.total_supply(), fee_times_time_diff, denominator);
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
            let performance_fee_amount0 = mul_div_rounding_up(
                amount0.into(),
                fee_config.performance_fee.into(),
                Constants::FEE_MULTIPLIER
            );
            let performance_fee_amount1 = mul_div_rounding_up(
                amount1.into(),
                fee_config.performance_fee.into(),
                Constants::FEE_MULTIPLIER
            );
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

        fn _get_token_balance(self: @ContractState, token: ContractAddress) -> u256 {
            let dispatcher = ERC20ABIDispatcher { contract_address: token };

            dispatcher.balance_of(get_contract_address())
        }

        fn _assert_only_manager(self: @ContractState) {
            assert(get_caller_address() == self.manager.read(), Errors::CALLER_IS_NOT_MANAGER);
        }

        fn _check_liquidity(self: @ContractState, liquidity: u128) {
            assert(liquidity != 0, Errors::ZERO_LIQUIDITY);
        }

        fn _check_deadline(self: @ContractState, deadline: u64) {
            assert(deadline >= get_block_timestamp(), Errors::TRANSACTION_EXPIRED);
        }
    }
}
