use starknet::{ ContractAddress, info::get_block_number };
use core::integer::{ BoundedU256, BoundedU64 };
use openzeppelin::{token::erc20::{ ERC20ABIDispatcher, interface::ERC20ABIDispatcherTrait }};
use yas_core::{
    numbers::signed_integer::i32::i32Impl,
    utils::math_utils::pow
};
use jediswap_v2_core::{
    jediswap_v2_factory::{ IJediSwapV2FactoryDispatcher, IJediSwapV2FactoryDispatcherTrait, JediSwapV2Factory },
    jediswap_v2_pool::{ IJediSwapV2PoolDispatcher, IJediSwapV2PoolDispatcherTrait }
};
use tea_vault_jedi_v2::tea_vault_jedi_v2::{
    ITeaVaultJediV2Dispatcher,
    ITeaVaultJediV2DispatcherTrait,
    FeeConfig,
    Constants
};
use snforge_std::{ declare, CheatTarget, ContractClassTrait, start_prank, stop_prank, start_roll, stop_roll, start_warp, stop_warp };

use super::utils::{ owner, manager, user, invalid_address, new_owner, token_0_1, is_close_to };


fn setup_factory() -> (ContractAddress, ContractAddress) {
    let owner = owner();
    let pool_class = declare('JediSwapV2Pool');

    let factory_class = declare('JediSwapV2Factory');
    let mut factory_constructor_calldata = Default::default();
    Serde::serialize(@owner, ref factory_constructor_calldata);
    Serde::serialize(@pool_class.class_hash, ref factory_constructor_calldata);
    let factory = factory_class.deploy(@factory_constructor_calldata).unwrap();
    
    (owner, factory)
}

fn create_pool(
    factory: ContractAddress,
    token0: ContractAddress,
    token1: ContractAddress,
    fee: u32
) -> ContractAddress {
    let factory_dispatcher = IJediSwapV2FactoryDispatcher { contract_address: factory };
    factory_dispatcher.create_pool(token0, token1, fee);
    let pool_address = factory_dispatcher.get_pool(token0, token1, fee);
    let pool_dispatcher = IJediSwapV2PoolDispatcher { contract_address: pool_address };

    // initialize pool: price0_1 = 4, price1_0 = 0.25
    // 2 ** 97 = 158456325028528675187087900672, tick = 13863
    pool_dispatcher.initialize(79228162514264337593543950336);

    pool_address
}

fn setup() -> (
    ITeaVaultJediV2Dispatcher,
    ERC20ABIDispatcher,
    ERC20ABIDispatcher,
    IJediSwapV2FactoryDispatcher,
    IJediSwapV2PoolDispatcher
) {
    let (owner, factory) = setup_factory();
    let (token0, token1) = token_0_1();
    let pool_address = create_pool(factory, token0, token1, 3000);

    let name = 'Test Vault';
    let symbol = 'TVault';
    let fee_tier = 3000;
    let decimal_offset = 0;
    let fee_cap = 999999;
    let fee_config = FeeConfig{
        treasury: owner,
        entry_fee: 0,
        exit_fee: 0,
        performance_fee: 0,
        management_fee: 0
    };

    let mut constructor_calldata = Default::default();
    Serde::serialize(@name, ref constructor_calldata);
    Serde::serialize(@symbol, ref constructor_calldata);
    Serde::serialize(@factory, ref constructor_calldata);
    Serde::serialize(@token0, ref constructor_calldata);
    Serde::serialize(@token1, ref constructor_calldata);
    Serde::serialize(@fee_tier, ref constructor_calldata);
    Serde::serialize(@decimal_offset, ref constructor_calldata);
    Serde::serialize(@fee_cap, ref constructor_calldata);
    Serde::serialize(@fee_config, ref constructor_calldata);
    Serde::serialize(@owner, ref constructor_calldata);
    
    let vault_class = declare('TeaVaultJediV2');
    let vault = vault_class.deploy(@constructor_calldata).unwrap();

    let vault_dispatcher = ITeaVaultJediV2Dispatcher { contract_address: vault };
    let token0_dispatcher = ERC20ABIDispatcher { contract_address: token0 };
    let token1_dispatcher = ERC20ABIDispatcher { contract_address: token1 };
    let factory_dispatcher = IJediSwapV2FactoryDispatcher { contract_address: factory };
    let pool_dispatcher = IJediSwapV2PoolDispatcher { contract_address: factory_dispatcher.get_pool(token0, token1, fee_tier) };
    (vault_dispatcher, token0_dispatcher, token1_dispatcher, factory_dispatcher, pool_dispatcher)
}

fn token_approve(token_dispatcher: ERC20ABIDispatcher, owner: ContractAddress, spender: ContractAddress, amount: u256) {
    start_prank(CheatTarget::One(token_dispatcher.contract_address), owner);
    token_dispatcher.approve(spender, amount);
    stop_prank(CheatTarget::One(token_dispatcher.contract_address));
}

fn set_fee_config(
    vault_dispatcher: ITeaVaultJediV2Dispatcher,
    sender: ContractAddress,
    treasury: ContractAddress,
    entry_fee: u32,
    exit_fee: u32,
    performance_fee: u32,
    management_fee: u32
) -> FeeConfig {
    let fee_config = FeeConfig{
        treasury: treasury,
        entry_fee: entry_fee,
        exit_fee: exit_fee,
        performance_fee: performance_fee,
        management_fee: management_fee
    };

    start_prank(CheatTarget::One(vault_dispatcher.contract_address), sender);
    vault_dispatcher.set_fee_config(fee_config);
    stop_prank(CheatTarget::One(vault_dispatcher.contract_address));
    fee_config
}

fn set_manager(vault_dispatcher: ITeaVaultJediV2Dispatcher, sender: ContractAddress, manager: ContractAddress) {
    start_prank(CheatTarget::One(vault_dispatcher.contract_address), sender);
    vault_dispatcher.assign_manager(manager);
    stop_prank(CheatTarget::One(vault_dispatcher.contract_address));
}

use starknet::contract_address_to_felt252;

// deployment
#[test]
fn test_deployment_token_correctness() {
    let (vault_dispatcher, token0_dispatcher, token1_dispatcher, _, _) = setup();
    assert(vault_dispatcher.asset_token0() == token0_dispatcher.contract_address, 'token0 not correct');
    assert(vault_dispatcher.asset_token1() == token1_dispatcher.contract_address, 'token1 not correct');
}

#[test]
fn test_deployment_decimals_correctness() {
    let (vault_dispatcher, _, _, _, _) = setup();
    let vault_erc20_dispatcher = ERC20ABIDispatcher{ contract_address: vault_dispatcher.contract_address };
    assert(vault_erc20_dispatcher.decimals() == 18, 'decimals not correct');
}

// owner functions
#[test]
fn test_owner_functions_owner_set_valid_fees() {
    let owner = owner();
    let (vault_dispatcher, _, _, _, _) = setup();

    let fee_config = set_fee_config(vault_dispatcher, owner, owner, 1000, 2000, 100000, 10000);
    let fees = vault_dispatcher.fee_config();
    assert(fees.treasury == fee_config.treasury, 'fee treasury not correct');
    assert(fees.entry_fee == fee_config.entry_fee, 'entry fee not correct');
    assert(fees.exit_fee == fee_config.exit_fee, 'exit fee not correct');
    assert(fees.performance_fee == fee_config.performance_fee, 'performance fee not correct');
    assert(fees.management_fee == fee_config.management_fee, 'management fee not correct');
}

#[test]
#[should_panic(expected: ('Invalid fee percentage',))]
fn test_owner_functions_owner_set_invalid_fees_1() {
    let owner = owner();
    let (vault_dispatcher, _, _, _, _) = setup();

    set_fee_config(vault_dispatcher, owner, owner, 500001, 500000, 100000, 10000);
}

#[test]
#[should_panic(expected: ('Invalid fee percentage',))]
fn test_owner_functions_owner_set_invalid_fees_2() {
    let owner = owner();
    let (vault_dispatcher, _, _, _, _) = setup();

    set_fee_config(vault_dispatcher, owner, owner, 1000, 2000, 1000001, 10000);
}

#[test]
#[should_panic(expected: ('Invalid fee percentage',))]
fn test_owner_functions_owner_set_invalid_fees_3() {
    let owner = owner();
    let (vault_dispatcher, _, _, _, _) = setup();

    set_fee_config(vault_dispatcher, owner, owner, 1000, 2000, 100000, 1000001);
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_owner_functions_non_owner_set_valid_fees() {
    let (vault_dispatcher, _, _, _, _) = setup();
    let invalid_address = invalid_address();

    set_fee_config(vault_dispatcher, invalid_address, invalid_address, 1000, 2000, 100000, 1000001);
}

#[test]
fn test_owner_functions_owner_assign_manager() {
    let (vault_dispatcher, _, _, _, _) = setup();
    let manager = manager();

    set_manager(vault_dispatcher, owner(), manager);

    assert(vault_dispatcher.manager() == manager, 'manager not set correctly');
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_owner_functions_non_owner_assign_manager() {
    let (vault_dispatcher, _, _, _, _) = setup();
    let invalid_address = invalid_address();

    set_manager(vault_dispatcher, invalid_address, invalid_address);
}

// user and manager functions
#[test]
fn test_user_manager_functions_user_deposit_withdraw() {
    let (vault_dispatcher, token0_dispatcher, token1_dispatcher, _, _) = setup();
    let owner = owner();
    let user = user();
    let vault_address = vault_dispatcher.contract_address;
    let vault_erc20_dispatcher = ERC20ABIDispatcher{ contract_address: vault_address };

    let fee_config = set_fee_config(vault_dispatcher, owner, owner, 1000, 2000, 100000, 10000);
    token_approve(token0_dispatcher, user, vault_address, 10000 * pow(10, 18));

    start_prank(CheatTarget::One(vault_address), user);
    start_warp(CheatTarget::One(vault_address), 100000);
    // deposit
    let shares = 100 * pow(10, 18);
    let token0_amount = 100 * pow(10, 18);
    let token0_before = token0_dispatcher.balance_of(user);
    vault_dispatcher.deposit(shares, BoundedU256::max(), BoundedU256::max());
    assert(vault_erc20_dispatcher.balance_of(user) == shares, 'share amount incorrect');
    let token0_after = token0_dispatcher.balance_of(user);

    let entry_fee_amount0 = token0_amount * fee_config.entry_fee.into() / 1000000;
    let expect_amount0 = token0_amount + entry_fee_amount0;
    assert(token0_before - token0_after == expect_amount0, 'deposited amount incorrect');
    assert(token0_dispatcher.balance_of(owner) == entry_fee_amount0, 'entry fee amount incorrect');
    let deposit_time = vault_dispatcher.last_collect_management_fee();

    // withdraw
    start_warp(CheatTarget::One(vault_address), 200000);
    let total_supply = vault_erc20_dispatcher.total_supply();
    let token0_before = token0_dispatcher.balance_of(user);
    vault_dispatcher.withdraw(shares, 0, 0);
    assert(vault_erc20_dispatcher.balance_of(user) == 0, 'share amount incorrect');
    let token0_after = token0_dispatcher.balance_of(user);

    let withdraw_time = vault_dispatcher.last_collect_management_fee();
    let management_fee_x_time_diff: u256 = (fee_config.management_fee.into() * (withdraw_time - deposit_time)).into();
    let denominator = Constants::FEE_MULTIPLIER * Constants::SECONDS_IN_A_YEAR - management_fee_x_time_diff;
    let management_fee = (shares * management_fee_x_time_diff + denominator - 1) / denominator;
    
    let mut expected_amount0 = token0_amount * (total_supply - management_fee) / total_supply;
    let exit_fee_amount0 = expected_amount0 * fee_config.exit_fee.into() / 1000000;
    let exit_fee_shares = shares * fee_config.exit_fee.into() / 1000000;
    expected_amount0 -= exit_fee_amount0;
    assert(is_close_to(token0_after - token0_before, expected_amount0, pow(10, 12)), 'withdrawn amount incorrect');
    assert(vault_erc20_dispatcher.balance_of(owner) == management_fee + exit_fee_shares, 'incorrect received fee amount');

    stop_warp(CheatTarget::One(vault_address));
    stop_prank(CheatTarget::One(vault_address));
}

#[test]
#[should_panic(expected: ('u256_sub Overflow',))]
fn test_user_manager_functions_non_user_deposit_withdraw() {
    let (vault_dispatcher, token0_dispatcher, token1_dispatcher, _, _) = setup();
    let user = user();
    let vault_address = vault_dispatcher.contract_address;

    token_approve(token0_dispatcher, user, vault_address, 10000 * pow(10, 18));

    start_prank(CheatTarget::One(vault_address), user);
    let shares = 100 * pow(10, 18);
    vault_dispatcher.deposit(shares, BoundedU256::max(), BoundedU256::max());
    stop_prank(CheatTarget::One(vault_address));

    vault_dispatcher.withdraw(shares, 0, 0);
}

#[test]
#[should_panic(expected: ('Invalid price slippage',))]
fn test_user_manager_functions_slippage_checks_when_depositing() {
    let (vault_dispatcher, token0_dispatcher, token1_dispatcher, _, _) = setup();
    let user = user();
    let vault_address = vault_dispatcher.contract_address;

    token_approve(token0_dispatcher, user, vault_address, 10000 * pow(10, 18));

    start_prank(CheatTarget::One(vault_address), user);
    vault_dispatcher.deposit(1000, 100, 100);
    stop_prank(CheatTarget::One(vault_address));
}

#[test]
#[should_panic(expected: ('Invalid price slippage',))]
fn test_user_manager_functions_slippage_checks_when_withdrawing() {
    let (vault_dispatcher, token0_dispatcher, token1_dispatcher, _, _) = setup();
    let user = user();
    let vault_address = vault_dispatcher.contract_address;

    token_approve(token0_dispatcher, user, vault_address, 10000 * pow(10, 18));

    start_prank(CheatTarget::One(vault_address), user);
    let shares = 1000;
    vault_dispatcher.deposit(shares, BoundedU256::max(), BoundedU256::max());
    vault_dispatcher.withdraw(shares, BoundedU256::max(), BoundedU256::max());
    stop_prank(CheatTarget::One(vault_address));
}

#[test]
fn test_user_manager_functions_manager_swap_add_remove_positions_after_deposit() {
    let (vault_dispatcher, token0_dispatcher, token1_dispatcher, factory_dispatcher, pool_dispatcher) = setup();
    let vault_address = vault_dispatcher.contract_address;
    let token0_address = token0_dispatcher.contract_address;
    let token1_address = token1_dispatcher.contract_address;
    let owner = owner();
    let manager = manager();
    let user = user();

    let fee_config = set_fee_config(vault_dispatcher, owner, owner, 1000, 2000, 100000, 0);
    set_manager(vault_dispatcher, owner, manager);

    start_prank(CheatTarget::One(vault_address), user);
    // deposit
    token_approve(token0_dispatcher, user, vault_address, 10000 * pow(10, 18));
    token_approve(token1_dispatcher, user, vault_address, 10000 * pow(10, 18));
    let shares = 1000 * pow(10, 18);
    vault_dispatcher.deposit(shares, BoundedU256::max(), BoundedU256::max());
    stop_prank(CheatTarget::One(vault_address));

    // donate some token1 for 2-sided liquidity provision
    start_prank(CheatTarget::One(token1_address), user);
    token1_dispatcher.transfer(vault_address, shares);
    stop_prank(CheatTarget::One(token1_address));

    assert(token0_dispatcher.balance_of(vault_address) == shares, 'incorrect amount0 (1)');
    assert(token1_dispatcher.balance_of(vault_address) == shares, 'incorrect amount1 (1)');

    // start_prank(CheatTarget::One(vault_address), manager); // unexpected behavior of nested prank
    // add liquidity
    let tick_lower0 = i32Impl::new(60, true);
    let tick_upper0 = i32Impl::new(60, false);
    let liquidity0 = vault_dispatcher.get_liquidity_for_amounts(tick_lower0, tick_upper0, 210 * pow(10, 18), 210 * pow(10, 18));
    let tick_lower1 = i32Impl::new(120, true);
    let tick_upper1 = i32Impl::new(120, false);
    let liquidity1 = vault_dispatcher.get_liquidity_for_amounts(tick_lower1, tick_upper1, 165 * pow(10, 18), 165 * pow(10, 18));
    let tick_lower2 = i32Impl::new(180, true);
    let tick_upper2 = i32Impl::new(180, false);
    let liquidity2 = vault_dispatcher.get_liquidity_for_amounts(tick_lower2, tick_upper2, 120 * pow(10, 18), 120 * pow(10, 18));
    let tick_lower3 = i32Impl::new(240, true);
    let tick_upper3 = i32Impl::new(240, false);
    let liquidity3 = vault_dispatcher.get_liquidity_for_amounts(tick_lower3, tick_upper3, 75 * pow(10, 18), 75 * pow(10, 18));
    let tick_lower4 = i32Impl::new(300, true);
    let tick_upper4 = i32Impl::new(300, false);
    let liquidity4 = vault_dispatcher.get_liquidity_for_amounts(tick_lower4, tick_upper4, 30 * pow(10, 18), 30 * pow(10, 18));
    vault_dispatcher.add_liquidity(tick_lower0, tick_upper0, liquidity0, 0, 0, BoundedU64::max());
    vault_dispatcher.add_liquidity(tick_lower1, tick_upper1, liquidity1, 0, 0, BoundedU64::max());
    vault_dispatcher.add_liquidity(tick_lower2, tick_upper2, liquidity2, 0, 0, BoundedU64::max());
    vault_dispatcher.add_liquidity(tick_lower3, tick_upper3, liquidity3, 0, 0, BoundedU64::max());
    vault_dispatcher.add_liquidity(tick_lower4, tick_upper4, liquidity4, 0, 0, BoundedU64::max());

    // reverted with 'Position length exceeds limit' as expected.
    // let tick_lower5 = i32Impl::new(3300, true);
    // let tick_upper5 = i32Impl::new(3300, false);
    // let liquidity5 = vault_dispatcher.get_liquidity_for_amounts(tick_lower5, tick_upper5, 120 * pow(10, 18), 120 * pow(10, 18));
    // vault_dispatcher.add_liquidity(tick_lower5, tick_upper5, liquidity5, 0, 0, BoundedU64::max());

    let (underlying0, underlying1) = vault_dispatcher.vault_all_underlying_assets();
    assert(token0_dispatcher.balance_of(vault_address) == 400 * pow(10, 18), 'incorrect amount0 (2)');
    assert(token1_dispatcher.balance_of(vault_address) == 400 * pow(10, 18), 'incorrect amount1 (2)');
    assert(is_close_to(underlying0, 1000 * pow(10, 18), 10), 'incorrect total0 (1)');
    assert(is_close_to(underlying1, 1000 * pow(10, 18), 10), 'incorrect total1 (1)');

    // swap exact input
    vault_dispatcher.swap_input_single(true, 40 * pow(10, 18), 0, 0, BoundedU64::max());
    let (underlying0, underlying1) = vault_dispatcher.vault_all_underlying_assets();
    assert(token0_dispatcher.balance_of(vault_address) == 360 * pow(10, 18), 'incorrect amount0 (3)');
    assert(is_close_to(token1_dispatcher.balance_of(vault_address), 440 * pow(10, 18), 2 * pow(10, 18)), 'incorrect amount1 (3)');
    assert(is_close_to(underlying0, 1000 * pow(10, 18), 10), 'incorrect total0 (2)');
    assert(is_close_to(underlying1, 1000 * pow(10, 18), 10), 'incorrect total1 (2)');

    // revert without rolling as expected
    // vault_dispatcher.swap_output_single(false, 40 * pow(10, 18), BoundedU256::max(), 0, BoundedU64::max());
    start_roll(CheatTarget::One(vault_address), get_block_number() + 1);

    // swap exact output
    vault_dispatcher.swap_output_single(false, 40 * pow(10, 18), BoundedU256::max(), 0, BoundedU64::max());
    let (underlying0, underlying1) = vault_dispatcher.vault_all_underlying_assets();
    assert(token0_dispatcher.balance_of(vault_address) == 400 * pow(10, 18), 'incorrect amount0 (4)');
    assert(is_close_to(token1_dispatcher.balance_of(vault_address), 400 * pow(10, 18), 2 * pow(10, 18)), 'incorrect amount1 (4)');
    assert(is_close_to(underlying0, 1000 * pow(10, 18), 10), 'incorrect total0 (3)');
    assert(is_close_to(underlying1, 1000 * pow(10, 18), 10), 'incorrect total1 (3)');

    // remove liquidity
    vault_dispatcher.remove_liquidity(tick_lower0, tick_upper0, liquidity0 / 2, 0, 0, BoundedU64::max());
    vault_dispatcher.remove_liquidity(tick_lower1, tick_upper1, liquidity1 / 2, 0, 0, BoundedU64::max());
    vault_dispatcher.remove_liquidity(tick_lower2, tick_upper2, liquidity2, 0, 0, BoundedU64::max());
    vault_dispatcher.remove_liquidity(tick_lower3, tick_upper3, liquidity3 / 2, 0, 0, BoundedU64::max());
    vault_dispatcher.remove_liquidity(tick_lower4, tick_upper4, liquidity4 / 2, 0, 0, BoundedU64::max());
    assert(vault_dispatcher.get_all_positions().len() == 4, 'incorrect position length');

    let (underlying0, underlying1) = vault_dispatcher.vault_all_underlying_assets();
    assert(is_close_to(token0_dispatcher.balance_of(vault_address), 760 * pow(10, 18), pow(10, 18)), 'incorrect amount1 (5)');
    assert(is_close_to(token1_dispatcher.balance_of(vault_address), 760 * pow(10, 18), pow(10, 18)), 'incorrect amount1 (5)');
    assert(is_close_to(underlying0, 1000 * pow(10, 18), pow(10, 18)), 'incorrect total0 (4)');
    assert(is_close_to(underlying1, 1000 * pow(10, 18), pow(10, 18)), 'incorrect total1 (4)');
    assert(is_close_to(token0_dispatcher.balance_of(owner), 1012 * pow(10, 15), 10), 'incorrect fee amount0');
    assert(is_close_to(token1_dispatcher.balance_of(owner), 12 * pow(10, 15), 5 * pow(10, 13)), 'incorrect fee amount1');

    // deposit more
    // hardcode the recipient to self.pool.read()
    start_prank(CheatTarget::One(vault_address), user);
    vault_dispatcher.deposit(shares * 2, BoundedU256::max(), BoundedU256::max());
    let token0 = token0_dispatcher.balance_of(vault_address);
    let token1 = token1_dispatcher.balance_of(vault_address);
    let (underlying0, underlying1) = vault_dispatcher.vault_all_underlying_assets();
    assert(is_close_to(token0_dispatcher.balance_of(vault_address), 2280 * pow(10, 18), 2 * pow(10, 18)), 'incorrect amount0 (6)');
    assert(is_close_to(token1_dispatcher.balance_of(vault_address), 2280 * pow(10, 18), 2 * pow(10, 18)), 'incorrect amount1 (6)');
    assert(is_close_to(underlying0, 3000 * pow(10, 18), pow(10, 18)), 'incorrect total0 (5)');
    assert(is_close_to(underlying1, 3000 * pow(10, 18), pow(10, 18)), 'incorrect total1 (5)');

    // withdraw
    let token0_before = token0_dispatcher.balance_of(user);
    let token1_before = token1_dispatcher.balance_of(user);
    vault_dispatcher.withdraw(shares / 3, 0, 0);
    let token0_after = token0_dispatcher.balance_of(user);
    let token1_after = token1_dispatcher.balance_of(user);
    assert(is_close_to(token0_after - token0_before, underlying0 / 9, pow(10, 18)), 'incorrect withdrawal amount0');
    assert(is_close_to(token1_after - token1_before, underlying1 / 9, pow(10, 18)), 'incorrect withdrawal amount1');
    let (underlying0_after, underlying1_after) = vault_dispatcher.vault_all_underlying_assets();
    assert(is_close_to(token0_dispatcher.balance_of(vault_address), token0 * 8 / 9, pow(10, 18)), 'incorrect amount0 (7)');
    assert(is_close_to(token1_dispatcher.balance_of(vault_address), token1 * 8 / 9, pow(10, 18)), 'incorrect amount1 (7)');
    assert(is_close_to(underlying0_after, underlying0 * 8 / 9, pow(10, 18)), 'incorrect total0 (6)');
    assert(is_close_to(underlying1_after, underlying1 * 8 / 9, pow(10, 18)), 'incorrect total1 (6)');
    stop_roll(CheatTarget::One(vault_address));
    stop_prank(CheatTarget::One(vault_address));
}