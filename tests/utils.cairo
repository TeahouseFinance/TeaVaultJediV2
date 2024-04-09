use core::option::OptionTrait;
use starknet::{
    ContractAddress, ClassHash, contract_address_try_from_felt252, contract_address_to_felt252
};
use core::integer::u256_from_felt252;
use snforge_std::{declare, start_prank, stop_prank, ContractClass, ContractClassTrait, CheatTarget};
use jediswap_v2_core::libraries::math_utils::pow;
use openzeppelin::token::erc20::interface::{ IERC20Dispatcher, IERC20DispatcherTrait };

fn owner() -> ContractAddress {
    contract_address_try_from_felt252('owner').unwrap()
}

fn new_owner() -> ContractAddress {
    contract_address_try_from_felt252('new_owner').unwrap()
}

fn manager() -> ContractAddress {
    contract_address_try_from_felt252('manager').unwrap()
}

fn reward_claimer() -> ContractAddress {
    contract_address_try_from_felt252('reward_claimer').unwrap()
}

fn user() -> ContractAddress {
    contract_address_try_from_felt252('user').unwrap()
}

fn invalid_address() -> ContractAddress {
    contract_address_try_from_felt252('invalid_address').unwrap()
}

fn token_0_1() -> (ContractAddress, ContractAddress) {
    let erc20_class = declare("ERC20");
    let initial_supply: u256 = 100000000 * pow(10, 18);

    let token0_name = "token0";
    let token0_symbol = "TOK0";
    let token1_name = "token1";
    let token1_symbol = "TOK1";
    
    let token0_address = erc20_class.deploy(@serialize_erc20_constructor(
        @token0_name,
        @token0_symbol,
        @initial_supply,
        @user()
    )).unwrap();

    let token1_address = erc20_class.deploy(@serialize_erc20_constructor(
        @token1_name,
        @token1_symbol,
        @initial_supply,
        @user()
    )).unwrap();

    // token0_address < token1_address
    if (contract_address_to_u256(token0_address) < contract_address_to_u256(token1_address)) {
        (token0_address, token1_address)
    }
    else {
        (token1_address, token0_address)
    }
}

fn contract_address_to_u256(contract_address: ContractAddress) -> u256 {
    u256_from_felt252(contract_address_to_felt252(contract_address))
}

fn serialize_erc20_constructor(
    name: @ByteArray,
    symbol: @ByteArray,
    initial_supply: @u256,
    recipient: @ContractAddress
) -> Array<felt252> {
    let mut constructor_calldata = Default::default();
    Serde::serialize(name, ref constructor_calldata);
    Serde::serialize(symbol, ref constructor_calldata);
    Serde::serialize(initial_supply, ref constructor_calldata);
    Serde::serialize(recipient, ref constructor_calldata);
    constructor_calldata
}

fn is_close_to(a: u256, b: u256, delta: u256) -> bool {
    a - delta <= b && b <= a + delta
}