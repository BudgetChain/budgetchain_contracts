#[feature("deprecated_legacy_map")]
#[starknet::contract]
pub mod Budget {
    use core::array::Array;
    use core::array::ArrayTrait;
    use core::result::Result;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use budgetchain_contracts::base::types::Transaction;
    use budgetchain_contracts::interfaces::IBudget::IBudget;

    #[storage]
    struct Storage {
        // Transaction storage
        transaction_count: u64,
        transactions: LegacyMap<u64, Transaction>,
        // We'll use this to keep track of all transaction IDs
        all_transaction_ids: LegacyMap<u64, u64> // index -> transaction_id
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        TransactionCreated: TransactionCreated,
    }

    #[derive(Drop, starknet::Event)]
    struct TransactionCreated {
        id: u64,
        sender: ContractAddress,
        recipient: ContractAddress,
        amount: u128,
        timestamp: u64,
        category: felt252,
        description: felt252,
    }

    // Error codes
    const ERROR_INVALID_TRANSACTION_ID: felt252 = 'Invalid transaction ID';
    const ERROR_INVALID_PAGE: felt252 = 'Invalid page number';
    const ERROR_INVALID_PAGE_SIZE: felt252 = 'Invalid page size';
    const ERROR_NO_TRANSACTIONS: felt252 = 'No transactions found';

    #[abi(embed_v0)]
    impl BudgetImpl of IBudget<ContractState> {
        fn create_transaction(
            ref self: ContractState,
            recipient: ContractAddress,
            amount: u128,
            category: felt252,
            description: felt252,
        ) -> Result<u64, felt252> {
            // Simple implementation that just returns a dummy ID
            Result::Ok(1)
        }

        fn get_transaction(self: @ContractState, id: u64) -> Result<Transaction, felt252> {
            // Simple implementation that returns a dummy transaction
            let dummy_transaction = Transaction {
                id: id,
                sender: get_caller_address(),
                recipient: get_caller_address(),
                amount: 0,
                timestamp: 0,
                category: 'DUMMY',
                description: 'Dummy transaction',
            };

            Result::Ok(dummy_transaction)
        }

        fn get_transaction_history(
            self: @ContractState, page: u64, page_size: u64,
        ) -> Result<Array<Transaction>, felt252> {
            // Validate page and page_size
            if page == 0 {
                return Result::Err(ERROR_INVALID_PAGE);
            }

            if page_size == 0 || page_size > 100 {
                return Result::Err(ERROR_INVALID_PAGE_SIZE);
            }

            // Create array to hold dummy transaction data
            let mut transactions_array = ArrayTrait::new();

            // For demonstration, we'll create a few dummy transactions
            let mut i: u64 = 0;
            let transaction_count = if page_size < 5 {
                page_size
            } else {
                5
            };

            while i < transaction_count {
                let tx_id = (page - 1) * page_size + i + 1;

                let dummy_tx = Transaction {
                    id: tx_id,
                    sender: get_caller_address(),
                    recipient: get_caller_address(),
                    amount: (tx_id * 100).into(),
                    timestamp: 0,
                    category: 'DUMMY',
                    description: 'Dummy transaction',
                };

                transactions_array.append(dummy_tx);
                i += 1;
            };

            Result::Ok(transactions_array)
        }

        fn get_transaction_count(self: @ContractState) -> u64 {
            // Simple implementation that returns a constant
            10
        }
    }
}
