#[feature("deprecated_legacy_map")]
#[starknet::contract]
pub mod Budget {
    use starknet::storage::StorageMapReadAccess;
use core::array::Array;
    use core::array::ArrayTrait;
    use core::result::Result;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use budgetchain_contracts::base::types::Transaction;
    use budgetchain_contracts::interfaces::IBudget::IBudget;
    use starknet::storage::{StoragePointerReadAccess};
    use core::option::Option;
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
        project_id: u64,
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
                project_id: 0,  
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
                    project_id: tx_id,
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

    // New function: Get all transactions for a specific project
    fn get_project_transactions(
        self: @ContractState,
        project_id: u64,
        page: u64,
        page_size: u64,
    ) -> Result<(Array<Transaction>, u64), felt252> {
        // Validate inputs
        if page_size == 0 {
            return Result::Err(ERROR_INVALID_PAGE_SIZE);
        }
        if page == 0 {
            return Result::Err(ERROR_INVALID_PAGE);
        }
    
        // Create an array to hold the transactions
        let mut transactions_array = ArrayTrait::new();
    
        // Loop through all transactions
        let mut i = 0;
        while i < self.transaction_count.read() {
            let transaction_id = self.all_transaction_ids.read(i);
            let transaction = self.transactions.read(transaction_id);
            // Check if the transaction belongs to the specified project
            if transaction.project_id == project_id {
                transactions_array.append(transaction);
            }
            i += 1;
        };
    
        // Check if there are any transactions
        if transactions_array.len() == 0 {
            return Result::Err(ERROR_NO_TRANSACTIONS);
        }
    
        // Calculate pagination
        let start_index = (page - 1) * page_size;
        let end_index = start_index + page_size;
    
        if start_index >= transactions_array.len() {
            return Result::Err(ERROR_INVALID_PAGE);
        }
    
        // Slice the transactions for the requested page
        let mut paginated_transactions = ArrayTrait::new();
        let mut j = start_index;
        while j < end_index && j < transactions_array.len() {
            paginated_transactions.append(transactions_array[j]);
            j += 1;
        }
    
        // Return the paginated transactions and the total count
        Result::Ok((paginated_transactions, transactions_array.len()))
     }
   }
}