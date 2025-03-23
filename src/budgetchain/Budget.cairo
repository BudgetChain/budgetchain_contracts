#[feature("deprecated_legacy_map")]
#[starknet::contract]
pub mod Budget {
    use core::array::Array;
    use core::array::ArrayTrait;
    use core::result::Result;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map,
    };
    use budgetchain_contracts::base::types::{Transaction, Project, Milestone};
    use budgetchain_contracts::interfaces::IBudget::IBudget;

    #[storage]
    struct Storage {
        // Transaction storage
        transaction_count: u64,
        transactions: LegacyMap<u64, Transaction>,
        // We'll use this to keep track of all transaction IDs
        authorized_orgs: Map<ContractAddress, bool>,
        project_count: u64,
        projects: Map<u64, Project>,
        milestones: Map<(u64, u32), Milestone>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        TransactionCreated: TransactionCreated,
        ProjectAllocated: ProjectAllocated,
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

    #[derive(Drop, starknet::Event)]
    struct ProjectAllocated {
        project_id: u64,
        org: ContractAddress,
        project_owner: ContractAddress,
        total_budget: u256,
    }

    // Error codes
    const ERROR_INVALID_TRANSACTION_ID: felt252 = 'Invalid transaction ID';
    const ERROR_INVALID_PAGE: felt252 = 'Invalid page number';
    const ERROR_INVALID_PAGE_SIZE: felt252 = 'Invalid page size';
    const ERROR_NO_TRANSACTIONS: felt252 = 'No transactions found';
    const UNAUTHORIZED: felt252 = 'Not authorized';
    const CALLER_NOT_ORG: felt252 = 'Caller must be org';
    const BUDGET_MISMATCH: felt252 = 'Milestone sum != total budget';
    const ARRAY_LENGTH_MISMATCH: felt252 = 'Array lengths mismatch';

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

        fn allocate_project_budget(
            ref self: ContractState,
            org: ContractAddress,
            project_owner: ContractAddress,
            total_budget: u256,
            milestone_descriptions: Array<felt252>,
            milestone_amounts: Array<u256>,
        ) -> u64 {
            let caller = get_caller_address();
            assert(self.authorized_orgs.entry(org).read(), UNAUTHORIZED);
            assert(caller == org, CALLER_NOT_ORG);

            // Validation - arrays have the same length
            let milestone_count = milestone_descriptions.len();
            assert(milestone_count == milestone_amounts.len(), ARRAY_LENGTH_MISMATCH);

            let mut sum: u256 = 0;
            let mut i: u32 = 0;
            while i < milestone_count {
                sum += *milestone_amounts.at(i);
                i += 1;
            };
            assert(sum == total_budget, 'Milestone sum != total budget');

            let project_id = self.project_count.read();

            let new_project = Project {
                id: project_id, org: org, owner: project_owner, total_budget: total_budget,
            };
            self.projects.entry(project_id).write(new_project);

            // Create milestone records
            let mut j: u32 = 0;
            while j < milestone_count {
                self
                    .milestones
                    .entry((project_id, j))
                    .write(
                        Milestone {
                            project_id: project_id,
                            index: j,
                            description: *milestone_descriptions.at(j),
                            amount: *milestone_amounts.at(j),
                            completed: false,
                        },
                    );
                j += 1;
            };

            // Emit event
            self.emit(ProjectAllocated { project_id, org, project_owner, total_budget });

            self.project_count.write(project_id + 1);

            project_id
        }
    }
}
