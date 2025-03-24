#[feature("deprecated_legacy_map")]
#[starknet::contract]
pub mod Budget {
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess, StoragePathEntry,
    };
    use core::array::Array;

    use core::array::ArrayTrait;
    use core::result::Result;
    use starknet::ContractAddress;
    use budgetchain_contracts::base::types::{Organization, Transaction, Project, Milestone};
    use starknet::{get_caller_address, get_block_timestamp};

    use budgetchain_contracts::interfaces::IBudget::IBudget;

    use core::option::Option;

    use budgetchain_contracts::base::types::{FundRequest};


    #[storage]
    struct Storage {
        admin: ContractAddress,
        // Transaction storage
        transaction_count: u64,
        transactions: LegacyMap<u64, Transaction>,
        project_count: u64,
        projects: Map<u64, Project>,
        milestones: Map<(u64, u32), Milestone>,
        // We'll use this to keep track of all transaction IDs
        all_transaction_ids: LegacyMap<u64, u64>, // index -> transaction_id
        fund_requests: Map::<(u64, u64), FundRequest>, // Key: (project_id, request_id)
        fund_requests_count: Map::<u64, u64>, // Key: project_id, Value: count of requests
        project_budgets: Map::<u64, u128>, // Key: project_id, Value: remaining budget
        org_count: u256,
        organizations: Map<u256, Organization>,
        org_addresses: Map<ContractAddress, bool>,
        org_list: Array<Organization>,
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        FundsReleased: FundsReleased,
        TransactionCreated: TransactionCreated,
        ProjectAllocated: ProjectAllocated,
        OrganizationAdded: OrganizationAdded,
    }

    #[derive(Drop, starknet::Event)]


    pub struct FundsReleased {
        project_id: u64,
        request_id: u64,
        amount: u128,
    }

    #[derive(Drop, starknet::Event)]
    struct TransactionCreated {
        id: u256,
        sender: ContractAddress,
        recipient: ContractAddress,
        amount: u128,
        timestamp: u64,
        category: felt252,
        description: felt252,
    }


    #[derive(Drop, starknet::Event)]
    pub struct ProjectAllocated {
        pub project_id: u64,
        pub org: ContractAddress,
        pub project_owner: ContractAddress,
        pub total_budget: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct OrganizationAdded {
        pub id: u256,
        pub address: ContractAddress,
        pub name: felt252,
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
    const ONLY_ADMIN: felt252 = 'ONLY ADMIN';

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        // Initialize contract state
        self.admin.write(admin);
        self.fund_requests_count.write(0, 0);
        self.project_budgets.write(0, 0);
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
            self: @ContractState, project_id: u64, page: u64, page_size: u64,
        ) -> Result<(Array<Transaction>, u64), felt252> {
            if page_size == 0 {
                return Result::Err(ERROR_INVALID_PAGE_SIZE);
            }
            if page == 0 {
                return Result::Err(ERROR_INVALID_PAGE);
            }

            let mut transactions_array = ArrayTrait::new();
            let total_tx_count: u64 = self.transaction_count.read();

            let mut i: u64 = 0;
            while i < total_tx_count {
                let transaction_id = self.all_transaction_ids.read(i);
                let transaction = self.transactions.read(transaction_id);

                if transaction.project_id == project_id {
                    transactions_array.append(transaction);
                }
                i += 1;
            };

            if transactions_array.len() == 0 {
                return Result::Err(ERROR_NO_TRANSACTIONS);
            }

            let start_index = (page - 1) * page_size;
            let end_index = start_index + page_size;
            let total_transactions: u64 = transactions_array.len().into();

            if start_index >= total_transactions {
                return Result::Err(ERROR_INVALID_PAGE);
            }

            let mut paginated_transactions = ArrayTrait::<Transaction>::new();
            let mut j: u64 = start_index;

            while j < end_index && j < total_transactions {
                if let Option::Some(boxed_tx) = transactions_array.get(j.try_into().unwrap()) {
                    let transaction: Transaction = *boxed_tx.unbox();
                    paginated_transactions.append(transaction);
                }
                j += 1;
            };

            Result::Ok((paginated_transactions, total_transactions.into()))
        }


        // Retrieves all fund requests for a given project ID.
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

        fn get_admin(self: @ContractState) -> ContractAddress {
            self.admin.read()
        }

        fn set_fund_requests(ref self: ContractState, fund_request: FundRequest, budget_id: u64) {
            self.fund_requests.write((fund_request.project_id, budget_id), fund_request);

            // Update the count for this project
            let current_max_id = self.fund_requests_count.read(fund_request.project_id);
            if budget_id >= current_max_id {
                self.fund_requests_count.write(fund_request.project_id, budget_id + 1_u64);
            }
        }

        fn get_fund_requests_counts(self: @ContractState, project_id: u64) -> u64 {
            self.fund_requests_count.read(project_id)
        }

        fn set_fund_requests_counts(ref self: ContractState, project_id: u64, count: u64) {
            self.fund_requests_count.write(project_id, count);
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
            assert(self.org_addresses.entry(org).read(), UNAUTHORIZED);
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

        fn create_organization(
            ref self: ContractState, name: felt252, org_address: ContractAddress, mission: felt252,
        ) -> u256 {
            // Ensure only the admin can add an organization

            let admin = self.admin.read();
            assert(admin == get_caller_address(), ONLY_ADMIN);

            let created_at = get_block_timestamp();
            // // Generate a unique organization ID
            let org_id: u256 = self.org_count.read();

            // Create and store the organization
            let organization = Organization {
                id: org_id,
                address: org_address,
                name,
                is_active: true,
                mission,
                created_at: created_at,
            };

            // Emit an event
            self.emit(OrganizationAdded { id: org_id, address: org_address, name: name });

            self.org_count.write(org_id + 1);
            self.organizations.write(org_id, organization);
            self.org_addresses.write(org_address, true);

            org_id
        }

        fn get_milestone(self: @ContractState, project_id: u64, index: u32) -> Milestone {
            self.milestones.entry((project_id, index)).read()
        }

        fn get_organization(self: @ContractState, org_id: u256) -> Organization {
            let organization = self.organizations.read(org_id);
            organization
        }
    }
}
