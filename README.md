# TeaVaultJediV2

TeaVault Jedi V2 is a managed vault for JediSwap V2.

## Installation

[Cairo book - installation](https://book.cairo-lang.org/ch01-01-installation.html)

[Scarb - 2.4.4](https://docs.swmansion.com/scarb/download.html)

[Starknet Foundry - 0.16.0](https://github.com/foundry-rs/starknet-foundry/)

## Compile Contracts

```bash
scarb build
```

## Run Tests

```bash
snforge test
```

## Project Structure

```bash
cd to tea_vault_jedi_v2
.
├── README.md
├── Scarb.lock
├── Scarb.toml
├── src
│   ├── lib.cairo
│   ├── libraries
│   │   ├── ownable
│   │   ├── ownable.cairo
│   │   └── vault_utils.cairo
│   └── tea_vault_jedi_v2.cairo
├── target
│   ├── CACHEDIR.TAG
│   └── dev
│       ├── snforge
│       ├── tea_vault_jedi_v2.starknet_artifacts.json
│       ├── tea_vault_jedi_v2_ERC20.compiled_contract_class.json
│       ├── tea_vault_jedi_v2_ERC20.contract_class.json
│       ├── tea_vault_jedi_v2_JediSwapV2Factory.compiled_contract_class.json
│       ├── tea_vault_jedi_v2_JediSwapV2Factory.contract_class.json
│       ├── tea_vault_jedi_v2_JediSwapV2NFTPositionManager.compiled_contract_class.json
│       ├── tea_vault_jedi_v2_JediSwapV2NFTPositionManager.contract_class.json
│       ├── tea_vault_jedi_v2_JediSwapV2Pool.compiled_contract_class.json
│       ├── tea_vault_jedi_v2_JediSwapV2Pool.contract_class.json
│       ├── tea_vault_jedi_v2_TeaVaultJediV2.compiled_contract_class.json
│       ├── tea_vault_jedi_v2_TeaVaultJediV2.contract_class.json
│       ├── tea_vault_jedi_v2_tests.test.json
│       └── tea_vault_jedi_v2_unittest.test.json
└── tests
    ├── lib.cairo
    ├── test_vault.cairo
    └── utils.cairo

7 directories, 24 files
    ~/Doc/tea/j/TeaVaultJediV2    main !3  tree -L 2                                                                                             ✔  block   1300 Mbps   114.44.234.72  
.
├── README.md
├── Scarb.lock
├── Scarb.toml
├── src
│   ├── lib.cairo
│   ├── libraries
│   └── tea_vault_jedi_v2.cairo
├── target
│   ├── CACHEDIR.TAG
│   └── dev
└── tests
    ├── lib.cairo
    ├── test_vault.cairo
    └── utils.cairo

5 directories, 9 files
    ~/Doc/tea/j/TeaVaultJediV2    main !3  tree -L 3                                                                                             ✔  block   1300 Mbps   114.44.234.72  
.
├── README.md
├── Scarb.lock
├── Scarb.toml
├── src
│   ├── lib.cairo
│   ├── libraries
│   │   ├── ownable
│   │   ├── ownable.cairo
│   │   └── vault_utils.cairo
│   └── tea_vault_jedi_v2.cairo
├── target
│   ├── CACHEDIR.TAG
│   └── dev
│       ├── snforge
│       ├── tea_vault_jedi_v2.starknet_artifacts.json
│       ├── tea_vault_jedi_v2_ERC20.compiled_contract_class.json
│       ├── tea_vault_jedi_v2_ERC20.contract_class.json
│       ├── tea_vault_jedi_v2_JediSwapV2Factory.compiled_contract_class.json
│       ├── tea_vault_jedi_v2_JediSwapV2Factory.contract_class.json
│       ├── tea_vault_jedi_v2_JediSwapV2NFTPositionManager.compiled_contract_class.json
│       ├── tea_vault_jedi_v2_JediSwapV2NFTPositionManager.contract_class.json
│       ├── tea_vault_jedi_v2_JediSwapV2Pool.compiled_contract_class.json
│       ├── tea_vault_jedi_v2_JediSwapV2Pool.contract_class.json
│       ├── tea_vault_jedi_v2_TeaVaultJediV2.compiled_contract_class.json
│       ├── tea_vault_jedi_v2_TeaVaultJediV2.contract_class.json
│       ├── tea_vault_jedi_v2_tests.test.json
│       └── tea_vault_jedi_v2_unittest.test.json
└── tests
    ├── lib.cairo
    ├── test_vault.cairo
    └── utils.cairo

7 directories, 24 files
    ~/Doc/tea/j/TeaVaultJediV2    main !3  tree -L 4                                                                                             ✔  block   1300 Mbps   114.44.234.72  
.
├── README.md
├── Scarb.lock
├── Scarb.toml
├── src
│   ├── lib.cairo
│   ├── libraries
│   │   ├── ownable
│   │   │   ├── interface.cairo
│   │   │   └── ownable.cairo
│   │   ├── ownable.cairo
│   │   └── vault_utils.cairo
│   └── tea_vault_jedi_v2.cairo
└── tests
    ├── lib.cairo
    ├── test_vault.cairo
    └── utils.cairo
```

## TODOs

1. Code review
2. Testing
3. License declaration
