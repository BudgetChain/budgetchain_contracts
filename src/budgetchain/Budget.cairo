#[starknet::contract]
pub mod Budget {
    use starknet::storage::VecTrait;
    use crate::interfaces::IBudget::IBudget;
    use crate::base::errors::*;
    use crate::base::types::{
        FundRequest, FundRequestStatus, Project, Milestone, Transaction, ADMIN_ROLE,
        ORGANIZATION_ROLE, TRANSACTION_FUND_RELEASE,
    };
    use openzeppelin::access::accesscontrol::{AccessControlComponent, DEFAULT_ADMIN_ROLE};
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::{
        ContractAddress, contract_address_const, get_block_timestamp, get_caller_address,
    };
    use starknet::storage::{
        Map, MutableVecTrait, Vec, StoragePathEntry, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use super::{};

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
        organizations: Map<ContractAddress, bool>,
        projects: Map<u64, Project>,
        milestones: Map<u64, Map<u64, Milestone>>, // Key: (project_id, milestone_id)
        fund_requests: Map<u64, Map<u64, FundRequest>>, // Key: (project_id, request_id)
        project_transaction_ids: Map<u64, Vec<u64>>,
        all_transactions: Vec<Transaction>,
        transaction_counter: u64,
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    /// Events
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        AdminAdded: AdminAdded,
        OrganizationAdded: OrganizationAdded,
        OrganizationRemoved: OrganizationRemoved,
        FundsReleased: FundsReleased,
        MilestoneCompleted: MilestoneCompleted,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct FundsReleased {
        pub project_id: u64,
        pub request_id: u64,
        pub milestone_id: u64,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AdminAdded {
        pub new_admin: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct OrganizationAdded {
        pub org: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct OrganizationRemoved {
        pub org: ContractAddress,
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
        self.transaction_counter.write(0);
    }

    #[abi(embed_v0)]
    impl BudgetImpl of IBudget<ContractState> {
        // Organization management
        fn add_organization(ref self: ContractState, org: ContractAddress) {
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.organizations.entry(org).write(true);

            // Grant organization role
            self.accesscontrol._grant_role(ORGANIZATION_ROLE, org);

            self.emit(Event::OrganizationAdded(OrganizationAdded { org }));
        }

        fn remove_organization(ref self: ContractState, org: ContractAddress) {
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.organizations.entry(org).write(false);

            // Revoke organization role
            self.accesscontrol._revoke_role(ORGANIZATION_ROLE, org);

            self.emit(Event::OrganizationRemoved(OrganizationRemoved { org }));
        }

        fn is_organization(self: @ContractState, org: ContractAddress) -> bool {
            self.organizations.entry(org).read()
        }

        // Project Management
        fn create_project(
            ref self: ContractState,
            project_id: u64,
            organization: ContractAddress,
            total_budget: u256,
        ) {
            // Only admin can create projects
            self.accesscontrol.assert_only_role(ORGANIZATION_ROLE);

            // Ensure the organization is registered
            assert(self.organizations.entry(organization).read(), ERROR_ONLY_ORGANIZATION);

            // Create the project
            let project = Project { organization, total_budget, remaining_budget: total_budget };

            // Store the project
            self.projects.entry(project_id).write(project);
        }

        /// Get project details
        fn get_project(self: @ContractState, project_id: u64) -> Project {
            self.projects.entry(project_id).read()
        }

        // Milestone Management
        fn create_milestone(
            ref self: ContractState,
            project_id: u64,
            milestone_id: u64,
            description: felt252,
            amount: u256,
            is_completed: bool,
        ) {
            // Only admin can create milestones
            self.accesscontrol.assert_only_role(ORGANIZATION_ROLE);

            // Verify project exists
            let project = self.projects.entry(project_id).read();
            assert(project.organization == get_caller_address(), ERROR_CALLER_NOT_AUTHORIZED);

            // Create milestone
            let milestone = Milestone {
                project_id,
                milestone_description: description,
                milestone_amount: amount,
                is_completed,
                is_released: false,
            };

            // Store the milestone
            self.milestones.entry(project_id).entry(milestone_id).write(milestone);
        }

        /// Get milestone details
        fn get_milestone(self: @ContractState, project_id: u64, milestone_id: u64) -> Milestone {
            self.milestones.entry(project_id).entry(milestone_id).read()
        }

        /// Marks a milestone as complete
        fn complete_milestone(ref self: ContractState, project_id: u64, milestone_id: u64) {
            // Only organization can mark milestones as complete
            self.accesscontrol.assert_only_role(ORGANIZATION_ROLE);

            // Verify project exists and caller is the project's organization
            let project = self.projects.entry(project_id).read();
            assert(project.organization == get_caller_address(), ERROR_CALLER_NOT_AUTHORIZED);

            // Verify milestone exists
            let mut milestone = self.milestones.entry(project_id).entry(milestone_id).read();
            assert(milestone.project_id == project_id, ERROR_INVALID_MILESTONE);

            // Verify milestone is not already completed
            assert(milestone.is_completed != true, ERROR_MILESTONE_ALREADY_COMPLETED);

            // Mark milestone as completed
            milestone.is_completed = true;
            self.milestones.entry(project_id).entry(milestone_id).write(milestone);

            // Emit event
            self.emit(Event::MilestoneCompleted(MilestoneCompleted { project_id, milestone_id }));
        }

        // Fund Request Management
        fn create_fund_request(
            ref self: ContractState,
            project_id: u64,
            request_id: u64,
            milestone_id: u64,
            amount: u256,
            requester: ContractAddress,
        ) {
            // Only admin can create fund requests
            self.accesscontrol.assert_only_role(ORGANIZATION_ROLE);

            // Verify project exists
            let project = self.projects.entry(project_id).read();
            assert(project.organization != contract_address_const::<0>(), ERROR_INVALID_PROJECT_ID);

            // Verify milestone exists
            let milestone = self.milestones.entry(project_id).entry(milestone_id).read();
            assert(milestone.project_id == project_id, ERROR_INVALID_MILESTONE);

            // Create fund request
            let fund_request = FundRequest {
                project_id, milestone_id, amount, requester, status: FundRequestStatus::Pending,
            };

            // Store the fund request
            self.fund_requests.entry(project_id).entry(request_id).write(fund_request);
        }

        /// Get fund request details
        fn get_fund_request(self: @ContractState, project_id: u64, request_id: u64) -> FundRequest {
            self.fund_requests.entry(project_id).entry(request_id).read()
        }

        // Get admin
        fn get_admin(self: @ContractState) -> ContractAddress {
            // Verify caller is default admin
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);

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
            let transaction_id = self.transaction_counter.read() + 1;

            let transaction = Transaction {
                project_id,
                transaction_type: TRANSACTION_FUND_RELEASE,
                amount: request.amount,
                executor: org,
                timestamp: get_block_timestamp(),
            };

            // Save transaction ID to project transaction IDs
            self.project_transaction_ids.entry(project_id).append().write(transaction_id);

            // Save transaction to all transactions array
            self.all_transactions.append().write(transaction);

            // Update transaction counter
            self.transaction_counter.write(transaction_id);

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

        /// Transaction related getters
        fn get_transaction_count(self: @ContractState) -> u64 {
            self.transaction_counter.read()
        }

        fn get_transaction(self: @ContractState, transaction_id: u64) -> Transaction {
            assert(
                transaction_id > 0 && transaction_id <= self.transaction_counter.read(),
                ERROR_INVALID_TRANSACTION_ID,
            );
            // Transaction IDs are 1-based, but array indices are 0-based
            self.all_transactions.at(transaction_id - 1).read()
        }

        fn get_project_transactions(self: @ContractState, project_id: u64) -> Array<u64> {
            let tx_ids_vec = self.project_transaction_ids.entry(project_id);
            let mut result: Array<u64> = ArrayTrait::new();

            let mut i: u64 = 0;
            let len = tx_ids_vec.len();

            while i < len {
                result.append(tx_ids_vec.at(i).read());
                i += 1;
            };

            result
        }
    }
}
