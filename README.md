# TeaVaultJediV2

TeaVault Jedi V2 is a managed vault for JediSwap V2.

## Installation

[Cairo book - installation](https://book.cairo-lang.org/ch01-01-installation.html)

## Compile Contracts

```bash
scarb build
```

## Project Structure

Place `JediSwap-v2-core` and `JediSwap-v2-periphery` beside `tea_vault_jedi_v2` (this repo).

```bash
cd to tea_vault_jedi_v2 to compile project
.
├── JediSwap-v2-core
│   ├── CODE_OF_CONDUCT.md
│   ├── CONTRIBUTING.md
│   ├── LICENSE
│   ├── README.md
│   ├── Scarb.lock
│   ├── Scarb.toml
│   ├── scripts
│   ├── src
│   └── tests
├── JediSwap-v2-periphery
│   ├── CODE_OF_CONDUCT.md
│   ├── CONTRIBUTING.md
│   ├── LICENSE
│   ├── README.md
│   ├── Scarb.lock
│   ├── Scarb.toml
│   ├── scripts
│   ├── src
│   └── tests
└── TeaVaultJediV2
    ├── README.md
    ├── Scarb.lock
    ├── Scarb.toml
    └── src
```

## TODOs

1. Code review
2. Testing
3. License declaration
