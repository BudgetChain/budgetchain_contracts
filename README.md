# BudgetChain Contracts

A decentralized financial management system built on StarkNet using Cairo contracts.

## Overview

BudgetChain is a blockchain-based budgeting and financial management system that allows users to create, track, and manage budgets in a transparent and secure way. Built on StarkNet using Cairo, BudgetChain provides a gas-efficient and scalable solution for financial management.

## Project Structure

```
budgetchain_contracts/
├── README.md
├── Scarb.lock
├── Scarb.toml
├── snfoundry.toml
├── src/
│   ├── base/
│   │   └── types.cairo
│   ├── budgetchain/
│   │   └── Budget.cairo
│   ├── interfaces/
│   │   └── IBudget.cairo
│   └── lib.cairo
└── tests/
    └── test_Budget.cairo
```

## Prerequisites

- [Scarb](https://docs.swmansion.com/scarb/) - Cairo package manager
- [SNFoundry](https://github.com/foundry-rs/starknet-foundry) - Testing framework for StarkNet

## Installation

Clone the repository and install dependencies:

```bash
git clone https://github.com/yourusername/budgetchain_contracts.git
cd budgetchain_contracts
```

## Contract Overview

### Budget Contract

The Budget contract allows users to create and manage budgets with specific allocation rules.

Key features:
- Create and manage budget allocations
- Track spending against budget limits
- Transfer funds between budget categories
- Role-based access control

## Building the Project

To build the project, run:

```bash
scarb build
```

## Testing

Run the test suite using SNFoundry:

```bash
snforge test
```

```



## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- StarkWare for creating StarkNet and Cairo
- SNFoundry team for the testing framework