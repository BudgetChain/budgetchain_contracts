#[starknet::contract]
pub mod Budget {
    use core::array::Array;
    use core::array::ArrayTrait;
    use core::result::Result;
    use openzeppelin::access::accesscontrol::{AccessControlComponent, DEFAULT_ADMIN_ROLE};
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::{
        ContractAddress, contract_address_const, get_block_timestamp, get_caller_address,
    };
    use starknet::storage::{
        Map, MutableVecTrait, Vec, VecTrait, StoragePathEntry, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use budgetchain_contracts::base::errors::*;
    use budgetchain_contracts::base::types::{
        FundRequest, FundRequestStatus, Project, Milestone, Organization, Transaction, ADMIN_ROLE,
        ORGANIZATION_ROLE, TRANSACTION_FUND_RELEASE,
    };
    use budgetchain_contracts::interfaces::IBudget::IBudget;

    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // AccessControl Mixin
    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;

    // SRC5 Mixin
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        admin: ContractAddress,
        org_count: u256,
        organizations: Map<u256, Organization>,
        org_addresses: Map<ContractAddress, bool>,
        org_list: Array<Organization>,
        projects: Map<u64, Project>,
        milestones: Map<u64, Map<u64, Milestone>>, // Key: (project_id, milestone_id)
        fund_requests: Map<u64, Map<u64, FundRequest>>, // Key: (project_id, request_id)
        all_transactions: Vec<Transaction>,
        project_transaction_ids: Map<u64, Vec<u64>>,
        transaction_count: u64,
        transactions: Map<u64, Transaction>,
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        TransactionCreated: TransactionCreated,
        OrganizationAdded: OrganizationAdded,
        AdminAdded: AdminAdded,
        FundsReleased: FundsReleased,
        MilestoneCompleted: MilestoneCompleted,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
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
    pub struct OrganizationAdded {
        pub id: u256,
        pub address: ContractAddress,
        pub name: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct FundsReleased {
        pub project_id: u64,
        pub request_id: u64,
        pub milestone_id: u64,
        pub amount: u128,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AdminAdded {
        pub new_admin: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MilestoneCompleted {
        pub project_id: u64,
        pub milestone_id: u64,
    }

    #[constructor]
    fn constructor(ref self: ContractState, default_admin: ContractAddress) {
        assert(default_admin != contract_address_const::<0>(), ERROR_ZERO_ADDRESS);

        // Initialize access control
        self.accesscontrol.initializer();
        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, default_admin);
        self.accesscontrol._grant_role(ADMIN_ROLE, default_admin);

        // Initialize contract storage
        self.admin.write(default_admin);
        self.transaction_count.write(0);
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

        // fn get_transaction(self: @ContractState, id: u64) -> Result<Transaction, felt252> {
        //     // Simple implementation that returns a dummy transaction
        //     let dummy_transaction = Transaction {
        //         id: id,
        //         sender: get_caller_address(),
        //         recipient: get_caller_address(),
        //         amount: 0,
        //         timestamp: 0,
        //         category: 'DUMMY',
        //         description: 'Dummy transaction',
        //     };

        //     Result::Ok(dummy_transaction)
        // }

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

        fn create_organization(
            ref self: ContractState, name: felt252, org_address: ContractAddress, mission: felt252,
        ) -> u256 {
            // Ensure only the admin can add an organization

            let admin = self.admin.read();
            assert(admin == get_caller_address(), ERROR_ONLY_ADMIN);

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

        fn get_organization(self: @ContractState, org_id: u256) -> Organization {
            let organization = self.organizations.read(org_id);
            organization
        }

        fn get_admin(self: @ContractState) -> ContractAddress {
            self.admin.read()
        }

    /// Allows authorized organizations to release funds for approved requests
        fn release_funds(
            ref self: ContractState, org: ContractAddress, project_id: u64, request_id: u64,
        ) {
            // Verify caller is an authorized organization
            self.accesscontrol.assert_only_role(ORGANIZATION_ROLE);

            // Ensure caller is the organization associated with the project
            let organization = get_caller_address();
            assert(org == organization, ERROR_ONLY_ORGANIZATION);
            let project = self.projects.entry(project_id).read();
            assert(org == project.organization, ERROR_ONLY_ORGANIZATION);

            // Validate fund request
            let mut request = self.fund_requests.entry(project_id).entry(request_id).read();
            assert(request.project_id == project_id, ERROR_INVALID_PROJECT_ID);
            assert(request.status == FundRequestStatus::Pending, ERROR_REQUEST_NOT_PENDING);

            // Verify milestone status
            let mut milestone = self
                .milestones
                .entry(project_id)
                .entry(request.milestone_id)
                .read();
            assert(milestone.project_id == project_id, ERROR_INVALID_MILESTONE);
            assert(milestone.is_completed == true, ERROR_INCOMPLETE_MILESTONE);
            assert(milestone.is_released != true, ERROR_REWARDED_MILESTONE);

            // Confirm project budget has sufficient allocation
            assert(project.total_budget >= request.amount, ERROR_INSUFFICIENT_BUDGET);

            // Update the request status to Approved
            request.status = FundRequestStatus::Approved;
            self.fund_requests.entry(project_id).entry(request_id).write(request);

            // Mark the project milestone as released
            milestone.is_released = true;
            self.milestones.entry(project_id).entry(request.milestone_id).write(milestone);

            // Update the project's remaining budget
            let mut updated_project = project;
            updated_project.remaining_budget -= request.amount;
            self.projects.entry(project_id).write(updated_project);

            // Create Transaction record and add to tx history
            let transaction_id = self.transaction_count.read() + 1;

            let transaction = Transaction {
                id: transaction_id,
                sender: org,
                recipient: request.requester,
                amount: request.amount,
                timestamp: get_block_timestamp(),
                category: TRANSACTION_FUND_RELEASE,
                description: milestone.milestone_description,
            };

            // Save transaction ID to project transaction IDs
            self.project_transaction_ids.entry(project_id).append().write(transaction_id);

            // Save transaction to all transactions array
            self.all_transactions.append().write(transaction);

            // Update transaction counter
            self.transaction_count.write(transaction_id);

            // Emit the FundsReleased event
            self
                .emit(
                    Event::FundsReleased(
                        FundsReleased {
                            project_id,
                            request_id,
                            milestone_id: request.milestone_id,
                            amount: request.amount,
                        },
                    ),
                );
        }

        /// Get project details
        fn get_project(self: @ContractState, project_id: u64) -> Project {
            self.projects.entry(project_id).read()
        }

        /// Get milestone details
        fn get_milestone(self: @ContractState, project_id: u64, milestone_id: u64) -> Milestone {
            self.milestones.entry(project_id).entry(milestone_id).read()
        }

        /// Transaction related getters
        fn get_transaction_count(self: @ContractState) -> u64 {
            self.transaction_count.read()
        }

        fn get_transaction(self: @ContractState, id: u64) -> Result<Transaction, felt252> {
            assert(
                id > 0 && id <= self.transaction_count.read(),
                ERROR_INVALID_TRANSACTION_ID,
            );

            // Transaction IDs are 1-based, but array indices are 0-based
            Result::Ok(self.all_transactions.at(id - 1).read())
        }
    }
}
