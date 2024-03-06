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
