#[starknet::contract]
pub mod Budget {
    use crate::interfaces::IBudget::IBudget;
    use crate::base::errors::*;
    use crate::base::types::{
        FundRequest, FundRequestStatus, Project, Milestone, Transaction, ADMIN_ROLE,
        ORGANIZATION_ROLE, TRANSACTION_FUND_RELEASE,
    };
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::access::accesscontrol::{AccessControlComponent, DEFAULT_ADMIN_ROLE};
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::{
        ContractAddress, contract_address_const, get_block_timestamp, get_caller_address,
    };
    use starknet::storage::{
        Map, StoragePathEntry, // StorageMapReadAccess, StorageMapWriteAccess,
        StoragePointerReadAccess, StoragePointerWriteAccess, MutableVecTrait, Vec, VecTrait,
    };
    use super::{};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // Ownable Mixin
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

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
        // milestones: Map<(u64, u64), Milestone>, // Key: (project_id, milestone_id)
        milestones: Map<u64, Map<u64, Milestone>>, // Key: (project_id, milestone_id)
        // fund_requests: Map<(u64, u64), FundRequest>, // Key: (project_id, request_id)
        fund_requests: Map<u64, Map<u64, FundRequest>>, // Key: (project_id, request_id)
        project_transaction_ids: Map<u64, Vec<u64>>,
        all_transactions: Vec<Transaction>,
        transaction_counter: u64,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    /// Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        AdminChanged: AdminChanged,
        OrganizationAdded: OrganizationAdded,
        OrganizationRemoved: OrganizationRemoved,
        FundsReleased: FundsReleased,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct FundsReleased {
        project_id: u64,
        request_id: u64,
        milestone_id: u64,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct AdminChanged {
        old_admin: ContractAddress,
        new_admin: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct OrganizationAdded {
        org: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct OrganizationRemoved {
        org: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        assert(owner != contract_address_const::<0>(), ERROR_ZERO_ADDRESS);

        // Initialize contract owner
        self.ownable.initializer(owner);

        // Initialize access control
        self.accesscontrol.initializer();
        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, owner);

        // Initialize transaction counter
        self.transaction_counter.write(0);
    }

    #[abi(embed_v0)]
    impl BudgetImpl of IBudget<ContractState> {
        // Organization management
        fn add_organization(ref self: ContractState, org: ContractAddress) {
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);
            // self.organizations.write(org, true);
            self.organizations.entry(org).write(true);

            self.emit(Event::OrganizationAdded(OrganizationAdded { org }));
        }

        fn remove_organization(ref self: ContractState, org: ContractAddress) {
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);
            // self.organizations.write(org, false);
            // self.organizations.entry(org).write(false);

            self.emit(Event::OrganizationRemoved(OrganizationRemoved { org }));
        }

        /// Allows authorized organizations to release funds for approved requests
        fn release_funds(ref self: ContractState, project_id: u64, request_id: u64) {
            // Verify caller is an authorized organization
            self.accesscontrol.assert_only_role(ORGANIZATION_ROLE);

            // Ensure caller is the organization associated with the project
            let org = get_caller_address();
            // let project = self.projects.read(project_id);
            let project = self.projects.entry(project_id).read();
            assert(org == project.organization, ERROR_CALLER_NOT_AUTHORIZED);

            // Validate fund request
            // let mut request = self.fund_requests.read((project_id, request_id));
            let mut request = self.fund_requests.entry(project_id).entry(request_id).read();
            assert(request.project_id == project_id, ERROR_INVALID_PROJECT_ID);
            assert(request.status == FundRequestStatus::Pending, ERROR_REQUEST_NOT_PENDING);

            // Verify milestone status
            // let mut milestone = self.milestones.read((project_id, request.milestone_id));
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
            // self.fund_requests.write((project_id, request_id), request);
            self.fund_requests.entry(project_id).entry(request_id).write(request);

            // Mark the project milestone as released
            milestone.is_released = true;
            // self.milestones.write((project_id, request.milestone_id), milestone);
            self.milestones.entry(project_id).entry(request.milestone_id).write(milestone);

            // Update the project's remaining budget
            let mut updated_project = project;
            updated_project.remaining_budget -= request.amount;
            // self.projects.write(project_id, updated_project);
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
    }
}
