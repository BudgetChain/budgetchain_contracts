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
    }
}
