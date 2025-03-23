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
    use starknet::storage::{Map, StorageMapReadAccess, StoragePointerReadAccess};
    use budgetchain_contracts::base::types::{FundRequest};
    use openzeppelin::access::ownable::{OwnableComponent};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        // Transaction storage
        transaction_count: u64,
        transactions: LegacyMap<u64, Transaction>,
        // We'll use this to keep track of all transaction IDs
        all_transaction_ids: LegacyMap<u64, u64>, // index -> transaction_id
        owner: ContractAddress,
        fund_requests: Map::<(u64, u64), FundRequest>, // Key: (project_id, request_id)
        fund_requests_count: Map::<u64, u64>, // Key: project_id, Value: count of requests
        project_budgets: Map::<u64, u128>, // Key: project_id, Value: remaining budget
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        FundsReleased: FundsReleased,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        TransactionCreated: TransactionCreated,
    }

    #[derive(Drop, starknet::Event)]
    pub struct FundsReleased {
        project_id: u64,
        request_id: u64,
        amount: u128,
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

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        // Initialize contract state
        self.ownable.initializer(owner);
    }

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

        /// Retrieves all fund requests for a given project ID.
        fn get_fund_requests(self: @ContractState, project_id: u64) -> Array<FundRequest> {
            let mut fund_requests_to_return = ArrayTrait::new();

            // Get the total count of fund requests for this project
            let count = self.fund_requests_count.read(project_id);
            assert!(count > 0, "No fund requests found for this project ID");

            // Loop through all fund requests for the project
            let mut current_index = 0;

            while current_index < count {
                let fund_request = self.fund_requests.read((project_id, current_index));
                fund_requests_to_return.append(fund_request);
                current_index += 1;
            };

            fund_requests_to_return
        }

        fn get_owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }
    }
}
