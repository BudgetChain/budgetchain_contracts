#[feature("deprecated_legacy_map")]
#[starknet::contract]
pub mod Budget {
    use budgetchain_contracts::base::errors::*;
    use budgetchain_contracts::base::types::{
        ADMIN_ROLE, FundRequest, FundRequestStatus, Milestone, ORGANIZATION_ROLE, Organization,
        Project, TRANSACTION_FUND_RELEASE, Transaction,
    };
    use budgetchain_contracts::interfaces::IBudget::IBudget;
    use core::array::{Array, ArrayTrait};
    use core::option::Option;
    use core::result::Result;
    use openzeppelin::access::accesscontrol::{AccessControlComponent, DEFAULT_ADMIN_ROLE};
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::storage::{
        Map, MutableVecTrait, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait,
    };
    use starknet::{
        ContractAddress, contract_address_const, get_block_timestamp, get_caller_address,
    };
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
        // Transaction storage
        owner: ContractAddress,
        transaction_count: u64,
        transactions: Map<u64, Transaction>,
        project_count: u64,
        projects: Map<u64, Project>,
        all_transaction_ids: Map<u64, u64>, // index -> transaction_id
        fund_requests: Map<(u64, u64), FundRequest>, // Key: (project_id, request_id)
        fund_requests_count: Map<u64, u64>, // Key: project_id, Value: count of requests
        project_budgets: Map<u64, u128>, // Key: project_id, Value: remaining budget
        org_count: u256,
        organizations: Map<u256, Organization>,
        org_addresses: Map<ContractAddress, bool>,
        org_list: Array<Organization>,
        milestones: Map<(u64, u64), Milestone>, // (project id, milestone id) -> Milestone
        org_milestones: Map<ContractAddress, u64>, // org to number of milestones they have
        all_transactions: Vec<Transaction>,
        project_transaction_ids: Map<u64, Vec<u64>>,
        project_transaction_count: Map<u64, u64>, // project_id -> count
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        fund_request: Map<u64, (u64, u64, ContractAddress)>,
        _fund_request_counter: u64,
        milestone_funds_released: LegacyMap<(u64, u64), bool>,
        project_owners: LegacyMap<u64, ContractAddress>,
        milestone_statuses: LegacyMap<(u64, u64), bool>,
        is_paused: bool,
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        FundsReleased: FundsReleased,
        TransactionCreated: TransactionCreated,
        ProjectAllocated: ProjectAllocated,
        OrganizationAdded: OrganizationAdded,
        AdminAdded: AdminAdded,
        MilestoneCreated: MilestoneCreated,
        MilestoneCompleted: MilestoneCompleted,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        FundsRequested: FundsRequested,
        OrganizationRemoved: OrganizationRemoved,
        FundsReturned: FundsReturned,
    }

    #[derive(Drop, starknet::Event)]
    pub struct FundsReleased {
        pub project_id: u64,
        pub request_id: u64,
        pub milestone_id: u64,
        pub amount: u128,
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

    #[derive(Drop, starknet::Event)]
    pub struct FundsReturned {
        pub project_id: u64,
        pub amount: u256,
        pub project_owner: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct FundsRequested {
        project_id: u64,
        request_id: u64,
        milestone_id: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MilestoneCreated {
        pub organization: u256,
        pub project_id: u64,
        pub milestone_description: felt252,
        pub milestone_amount: u256,
        pub created_at: u64,
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

    #[derive(Drop, starknet::Event)]
    pub struct OrganizationRemoved {
        pub org_id: u256,
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
        self.fund_requests_count.write(0, 0);
        self.project_budgets.write(0, 0);
    }

    #[abi(embed_v0)]
    impl BudgetImpl of IBudget<ContractState> {
        fn create_transaction(
            ref self: ContractState,
            project_id: u64,
            recipient: ContractAddress,
            amount: u128,
            category: felt252,
            description: felt252,
        ) -> Result<u64, felt252> {
            // Ensure the contract is not paused
            self.assert_not_paused();

            // Generate new transaction ID
            let transaction_id = self.transaction_count.read();
            let sender = get_caller_address();
            let timestamp = get_block_timestamp();
            let transaction = Transaction {
                id: transaction_id,
                project_id: project_id,
                sender: sender,
                recipient: recipient,
                amount: amount,
                timestamp: timestamp,
                category: category,
                description: description,
            };
            self.transactions.write(transaction_id, transaction);
            self.transaction_count.write(transaction_id + 1);

            // Use category as project_id
            let count = self.project_transaction_count.read(project_id);
            self.project_transaction_ids.entry(project_id).append().write(transaction_id);
            self.project_transaction_count.write(project_id, count + 1);

            Result::Ok(transaction_id)
        }

        fn get_transaction(self: @ContractState, id: u64) -> Result<Transaction, felt252> {
            assert(id > 0 && id <= self.transaction_count.read(), ERROR_INVALID_TRANSACTION_ID);

            // Transaction IDs are 1-based, but array indices are 0-based
            Result::Ok(self.all_transactions.at(id - 1).read())
        }

        fn get_transaction_count(self: @ContractState) -> u64 {
            self.transaction_count.read()
        }

        // fn get_transaction_history(
        //     self: @ContractState, page: u64, page_size: u64,
        // ) -> Result<Array<Transaction>, felt252> {}

        // New function: Get all transactions for a specific project

        fn get_project_transactions(
            self: @ContractState, project_id: u64, page: u64, page_size: u64,
        ) -> Result<(Array<Transaction>, u64), felt252> {
            if page == 0 {
                return Result::Err(ERROR_INVALID_PAGE);
            }
            if page_size == 0 || page_size > 100 {
                return Result::Err(ERROR_INVALID_PAGE_SIZE);
            }
            let total = self.project_transaction_count.read(project_id);
            if total == 0 {
                return Result::Err(ERROR_NO_TRANSACTIONS);
            }
            let start = (page - 1) * page_size;
            if start >= total {
                return Result::Ok((ArrayTrait::new(), total));
            }
            let end = if start + page_size > total {
                total
            } else {
                start + page_size
            };
            let mut txs = ArrayTrait::new();

            let mut i = start;
            while i < end {
                let tx_id = self.project_transaction_ids.entry(project_id).at(i).read();
                let tx = self.transactions.read(tx_id);
                txs.append(tx);
                i += 1;
            };
            Result::Ok((txs, total))
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

        fn return_funds(
            ref self: ContractState, project_owner: ContractAddress, project_id: u64, amount: u256,
        ) {
            assert(project_id != 0, 'Invalid project ID');
            assert(amount > 0, 'Amount cannot be zero');

            let get_project_by_id = self.projects.read(project_id);
            assert(get_project_by_id.owner == project_owner, ERROR_UNAUTHORIZED);

            // Verify that the project has enough remaining budget
            assert(get_project_by_id.total_budget >= amount, ERROR_INSUFFICIENT_BUDGET);

            // Update the project's remaining budget
            let new_budget = get_project_by_id.total_budget - amount;
            let updated_project = Project {
                id: get_project_by_id.id,
                org: get_project_by_id.org,
                owner: get_project_by_id.owner,
                total_budget: new_budget,
            };
            self.projects.write(project_id, updated_project);

            let transaction_id = self.transaction_count.read() + 1;
            let transaction = Transaction {
                id: transaction_id,
                project_id,
                sender: project_owner,
                recipient: get_project_by_id.org,
                amount: amount.try_into().unwrap(),
                timestamp: get_block_timestamp(),
                category: 'FUNDS_RETURNED',
                description: 'Unused project funds returned',
            };

            // Create transaction record for the returned funds
            // Save transaction to transaction history
            self.all_transactions.append().write(transaction);

            // Save transaction ID to project transaction IDs
            self.project_transaction_ids.entry(project_id).append().write(transaction_id);

            // Update transaction counter
            self.transaction_count.write(transaction_id);

            // Emit the FundsReturned event
            self.emit(Event::FundsReturned(FundsReturned { project_id, amount, project_owner }));
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
            // Ensure the contract is not paused
            self.assert_not_paused();

            let caller = get_caller_address();
            assert(self.org_addresses.entry(org).read(), ERROR_UNAUTHORIZED);
            assert(caller == org, ERROR_CALLER_NOT_ORG);

            // Validation - arrays have the same length
            let milestone_count = milestone_descriptions.len();
            assert(milestone_count == milestone_amounts.len(), ERROR_ARRAY_LENGTH_MISMATCH);

            let mut sum: u256 = 0;
            let mut i: u32 = 0;
            while i < milestone_count {
                sum += *milestone_amounts.at(i.into());
                i += 1;
            };
            assert(sum == total_budget, ERROR_BUDGET_MISMATCH);

            let project_id = self.project_count.read();

            let new_project = Project {
                id: project_id, org: org, owner: project_owner, total_budget: total_budget,
            };
            self.projects.write(project_id, new_project);

            // Create milestone records
            let mut j: u32 = 0;
            while j < milestone_count {
                self
                    .milestones
                    .write(
                        (project_id, j.into() + 1),
                        Milestone {
                            organization: org,
                            project_id: project_id,
                            milestone_description: *milestone_descriptions.at(j),
                            milestone_amount: *milestone_amounts.at(j),
                            created_at: get_block_timestamp(),
                            completed: false,
                            released: false,
                        },
                    );
                j += 1;
            };

            self.project_count.write(project_id + 1);
            self.org_milestones.write(org, milestone_count.try_into().unwrap());

            // Emit event
            self.emit(ProjectAllocated { project_id, org, project_owner, total_budget });

            project_id
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

            // Grant organization role
            self.accesscontrol._grant_role(ORGANIZATION_ROLE, organization.address);

            // Emit an event
            self.emit(OrganizationAdded { id: org_id, address: org_address, name: name });

            org_id
        }

        fn create_milestone(
            ref self: ContractState,
            org: ContractAddress,
            project_id: u64,
            milestone_description: felt252,
            milestone_amount: u256,
        ) -> u64 {
            let admin = self.admin.read();
            assert(admin == get_caller_address(), ERROR_ONLY_ADMIN);

            let created_at = get_block_timestamp();

            let new_milestone: Milestone = Milestone {
                organization: org,
                project_id: project_id,
                milestone_description: milestone_description,
                milestone_amount: milestone_amount,
                created_at: created_at,
                completed: false,
                released: false,
            };
            // // read the number of the current milestones the organization has
            let current_milestone = self.org_milestones.read(org);

            self.milestones.write((project_id, current_milestone + 1), new_milestone);
            self.org_milestones.write(org, current_milestone + 1);

            current_milestone + 1
        }

        fn get_organization(self: @ContractState, org_id: u256) -> Organization {
            let organization = self.organizations.read(org_id);
            organization
        }

        fn get_project_remaining_budget(self: @ContractState, project_id: u64) -> u256 {
            let project = self.projects.read(project_id);
            // Verify that the project exists
            assert(project.org != contract_address_const::<0>(), ERROR_INVALID_PROJECT_ID);
            project.total_budget
        }

        fn get_project_budget(self: @ContractState, project_id: u64) -> u256 {
            let project = self.projects.read(project_id);

            assert(project.org != contract_address_const::<0>(), ERROR_INVALID_PROJECT_ID);
            let project_budget = project.total_budget;

            project_budget
        }

        fn get_project(self: @ContractState, project_id: u64) -> Project {
            self.projects.read(project_id)
        }

        fn get_fund_request(self: @ContractState, project_id: u64, request_id: u64) -> FundRequest {
            // Verify project exists
            let project = self.projects.read(project_id);
            assert(project.org != contract_address_const::<0>(), ERROR_INVALID_PROJECT_ID);

            // Verify caller's authorization
            // Caller must be either project org or admin
            let caller = get_caller_address();
            assert(caller == self.admin.read() || caller == project.org, ERROR_UNAUTHORIZED);

            self.fund_requests.read((project_id, request_id))
        }

        fn create_fund_request(ref self: ContractState, project_id: u64, milestone_id: u64) -> u64 {
            // Verify project exists
            let project = self.projects.read(project_id);
            assert(project.org != contract_address_const::<0>(), ERROR_INVALID_PROJECT_ID);

            // Confirm project owner
            let caller = get_caller_address();
            assert(caller == project.owner, ERROR_UNAUTHORIZED);

            // Verify milestone exists
            let milestone = self.milestones.read((project_id, milestone_id));
            assert(milestone.project_id == project_id, ERROR_INVALID_MILESTONE);

            // Validate milestone status
            assert(milestone.completed == true, ERROR_INCOMPLETE_MILESTONE);

            // Create fund request
            let fund_request = FundRequest {
                project_id,
                milestone_id,
                amount: milestone.milestone_amount.try_into().unwrap(),
                requester: caller,
                status: FundRequestStatus::Pending,
            };

            // Store the fund request and increase the count
            let request_id = self.fund_requests_count.read(project_id) + 1;
            self.fund_requests.write((project_id, request_id), fund_request);
            self.fund_requests_count.write(project_id, request_id);

            request_id
        }

        fn set_milestone_complete(ref self: ContractState, project_id: u64, milestone_id: u64) {
            // Get the milestone
            let mut milestone = self.milestones.read((project_id, milestone_id));

            // Verify caller's authorization
            let caller = get_caller_address();
            let admin = self.admin.read();
            let project = self.projects.read(project_id);

            // Caller must be either project owner or admin
            assert(caller == project.owner || caller == admin, ERROR_UNAUTHORIZED);

            // Verify the milestone exists for this project
            assert(milestone.project_id == project_id, ERROR_INVALID_MILESTONE);

            // Validate milestone status
            assert(milestone.completed != true, ERROR_MILESTONE_ALREADY_COMPLETED);

            // Update the completed status
            milestone.completed = true;

            // Write back to storage
            self.milestones.write((project_id, milestone_id), milestone);

            // Emit the MilestoneCompleted event
            self.emit(Event::MilestoneCompleted(MilestoneCompleted { project_id, milestone_id }));
        }

        /// Allows authorized organizations to release funds for approved requests
        fn release_funds(
            ref self: ContractState, org: ContractAddress, project_id: u64, request_id: u64,
        ) {
            // Ensure the contract is not paused
            self.assert_not_paused();
            // Verify caller is an authorized organization
            self.accesscontrol.assert_only_role(ORGANIZATION_ROLE);

            // Ensure caller is the organization associated with the project
            let caller = get_caller_address();
            assert(org == caller, ERROR_ONLY_ORGANIZATION);
            let mut project = self.projects.read(project_id);
            assert(org == project.org, ERROR_ONLY_ORGANIZATION);

            // Validate fund request
            let mut request = self.fund_requests.read((project_id, request_id));
            assert(request.project_id == project_id, ERROR_INVALID_PROJECT_ID);
            assert(request.status == FundRequestStatus::Pending, ERROR_REQUEST_NOT_PENDING);

            // Verify milestone status
            let mut milestone = self.milestones.read((project_id, request.milestone_id));
            assert(milestone.project_id == project_id, ERROR_INVALID_MILESTONE);
            assert(milestone.completed == true, ERROR_INCOMPLETE_MILESTONE);
            assert(milestone.released != true, ERROR_REWARDED_MILESTONE);

            // Confirm project budget has sufficient allocation
            assert(project.total_budget >= request.amount.into(), ERROR_INSUFFICIENT_BUDGET);

            // Update the request status to Approved
            request.status = FundRequestStatus::Approved;
            self.fund_requests.write((project_id, request_id), request);

            // Mark the project milestone as released
            milestone.released = true;
            self.milestones.write((project_id, request.milestone_id), milestone);

            // Update the project's remaining budget
            project.total_budget -= request.amount.into();
            self.projects.write(project_id, project);

            // Create Transaction record and add to tx history
            let transaction_id = self.transaction_count.read() + 1;

            let transaction = Transaction {
                id: transaction_id,
                project_id,
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
                            milestone_id: request.milestone_id.into(),
                            amount: request.amount,
                        },
                    ),
                );
        }

        fn is_authorized_organization(self: @ContractState, org: ContractAddress) -> bool {
            self.org_addresses.read(org)
        }
        fn get_fund_requests_counter(self: @ContractState) -> u64 {
            let request_id = self._fund_request_counter.read();
            let increased_id = request_id + 1;
            increased_id
        }

        fn set_fund_requests_counter(ref self: ContractState, value: u64) -> bool {
            self._fund_request_counter.write(value);
            true
        }

        fn check_owner(self: @ContractState, requester: ContractAddress, project_id: u64) {
            let project_owner = self.project_owners.read(project_id);
            assert(project_owner == requester, ERROR_UNAUTHORIZED_REQUESTER);
        }
        fn check_milestone(
            self: @ContractState, requester: ContractAddress, project_id: u64, milestone_id: u64,
        ) {
            let is_completed = self.milestone_statuses.read((project_id, milestone_id));
            assert(is_completed, ERROR_MILESTONE_NOT_COMPLETED);
        }
        fn funds_released(self: @ContractState, project_id: u64, milestone_id: u64) {
            //check if funds already released
            let funds_released = self.milestone_funds_released.read((project_id, milestone_id));
            assert(!funds_released, ERROR_FUNDS_ALREADY_RELEASED);
        }
        fn write_fund_request(
            ref self: ContractState,
            requester: ContractAddress,
            project_id: u64,
            milestone_id: u64,
            request_id: u64,
        ) -> bool {
            // Verify project exists
            let project = self.projects.read(project_id);
            assert(project.org != contract_address_const::<0>(), ERROR_INVALID_PROJECT_ID);

            // Verify caller's authorization
            // Caller must be either project org or admin
            assert(requester == self.admin.read() || requester == project.org, ERROR_UNAUTHORIZED);

            // Verify milestone exists
            let milestone = self.milestones.read((project_id, milestone_id));
            assert(milestone.project_id == project_id, ERROR_INVALID_MILESTONE);

            // Store the funds request details
            self.fund_request.write(request_id, (project_id, milestone_id, requester));

            true
        }
        fn get_milestone(self: @ContractState, project_id: u64, milestone_id: u64) -> Milestone {
            self.milestones.read((project_id, milestone_id))
        }
        fn pause_contract(ref self: ContractState) {
            // Ensure only the admin can pause the contract
            let caller = get_caller_address();
            assert(caller == self.admin.read(), ERROR_ONLY_ADMIN);
            // check if already paused
            assert(!self.is_paused.read(), ERROR_ALREADY_PAUSED);
            // Set the paused state to true
            self.is_paused.write(true);
        }
        fn unpause_contract(ref self: ContractState) {
            // Ensure only the admin can unpause the contract
            let caller = get_caller_address();
            assert(caller == self.admin.read(), ERROR_ONLY_ADMIN);

            // Set the paused state to false
            self.is_paused.write(false);
        }
        fn is_paused(self: @ContractState) -> bool {
            self.is_paused.read()
        }
        fn remove_organization(ref self: ContractState, org_id: u256) {
            let caller = get_caller_address();
            assert(caller == self.admin.read(), ERROR_ONLY_ADMIN);

            let mut org = self.organizations.read(org_id);
            org.is_active = false;
            self.organizations.write(org_id, org);

            self.emit(OrganizationRemoved { org_id: org_id });
        }
        fn request_funds(
            ref self: ContractState,
            requester: ContractAddress,
            project_id: u64,
            milestone_id: u64,
            request_id: u64,
        ) -> u64 {
            //Ensure the contract is not paused
            self.assert_not_paused();

            // Verify project exists
            let project = self.projects.read(project_id);
            assert(project.org != contract_address_const::<0>(), ERROR_INVALID_PROJECT_ID);

            // Verify caller's authorization
            // Caller must be either project org or admin
            assert(
                requester == self.admin.read() || requester == project.org,
                ERROR_UNAUTHORIZED_REQUESTER,
            );

            // Verify milestone exists
            let milestone = self.milestones.read((project_id, milestone_id));
            assert(milestone.project_id == project_id, ERROR_INVALID_MILESTONE);

            //verify that the milestone is completed
            let milestone = self.milestones.read((project_id, milestone_id));
            assert(milestone.completed, ERROR_MILESTONE_NOT_COMPLETED);

            //check if funds already released
            // let funds_released = self.milestone_funds_released.read((project_id, milestone_id));
            // assert(funds_released, ERROR_FUNDS_ALREADY_RELEASED);
            let request = self.fund_requests.read((project_id, request_id));
            assert(request.project_id == project_id, ERROR_INVALID_PROJECT_ID);
            assert(request.status == FundRequestStatus::Pending, ERROR_FUNDS_ALREADY_RELEASED);

            // a unique request_id
            let request_id = self._fund_request_counter.read();
            let increased_id = request_id + 1;

            // Create fund request
            let fund_request = FundRequest {
                project_id,
                milestone_id,
                amount: milestone.milestone_amount.try_into().unwrap(),
                requester: requester,
                status: FundRequestStatus::Pending,
            };

            // Store the fund request and increase the count
            let request_id = self.fund_requests_count.read(project_id) + 1;
            self.fund_requests.write((project_id, request_id), fund_request);
            self.fund_requests_count.write(project_id, request_id);

            self.milestone_funds_released.write((project_id, milestone_id), true);

            // increment _fund_request_counter
            self._fund_request_counter.write(increased_id);

            // Emit FundsRequest
            self
                .emit(
                    Event::FundsRequested(FundsRequested { project_id, milestone_id, request_id }),
                );

            request_id
        }
    }

    #[generate_trait]
    pub impl Internal of InternalTrait {
        // Internal view function
        // - Takes `@self` as it only needs to read state
        // - Can only be called by other functions within the contract
        fn assert_not_paused(self: @ContractState) {
            assert(!self.is_paused.read(), ERROR_CONTRACT_PAUSED);
        }
    }
}
