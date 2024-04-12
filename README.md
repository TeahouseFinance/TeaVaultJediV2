# TeaVaultJediV2

TeaVault Jedi V2 is a managed vault for JediSwap V2.

## Installation

[Cairo book - installation](https://book.cairo-lang.org/ch01-01-installation.html)

[Scarb - 2.6.3](https://docs.swmansion.com/scarb/download.html)

[Starknet Foundry - 0.20.1](https://github.com/foundry-rs/starknet-foundry/)

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
# cd TeaVaultJediV2
.
├── README.md
├── Scarb.lock
├── Scarb.toml
├── audit
│   ├── Teahouse Vault Cairo Security Report - DeFi Spring.pdf
│   └── Teahouse Vault Cairo Security Report - Ver.1.pdf
├── src
│   ├── lib.cairo
│   ├── libraries
│   │   └── vault_utils.cairo
│   └── tea_vault_jedi_v2.cairo
└── tests
    ├── lib.cairo
    ├── test_vault.cairo
    └── utils.cairo
```

## TODOs

1. License declaration: BUSL-1.1
