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
        all_transaction_ids: LegacyMap<u64, u64>, // index -> transaction_id
        fund_requests: Map::<(u64, u64), FundRequest>, // Key: (project_id, request_id)
        fund_requests_count: Map::<u64, u64>, // Key: project_id, Value: count of requests
        project_budgets: Map::<u64, u128>, // Key: project_id, Value: remaining budget
        org_count: u256,
        organizations: Map<u256, Organization>,
        org_addresses: Map<ContractAddress, bool>,
        org_list: Array<Organization>,
        milestones: Map<(u64, u32), Milestone>, // (project, milestone id) -> Milestone
        org_milestones: Map<ContractAddress, u32>, // org to number of milestones they have
        budget_allocations: Map<(u64, felt252), u128>, // (project_id, category) -> allocated amount
        role_permissions: Map<ContractAddress, felt252>, // address -> role
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        FundsReleased: FundsReleased,
        TransactionCreated: TransactionCreated,
        ProjectAllocated: ProjectAllocated,
        OrganizationAdded: OrganizationAdded,
        MilestoneCreated: MilestoneCreated,
        BudgetAllocated: BudgetAllocated,
        BudgetTransferred: BudgetTransferred,
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

    #[derive(Drop, starknet::Event)]
    pub struct MilestoneCreated {
        pub organization: u256,
        pub project_id: u64,
        pub milestone_description: felt252,
        pub milestone_amount: u256,
        pub created_at: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BudgetAllocated {
        pub project_id: u64,
        pub category: felt252,
        pub amount: u128,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BudgetTransferred {
        pub project_id: u64,
        pub from_category: felt252,
        pub to_category: felt252,
        pub amount: u128,
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
    const INSUFFICIENT_BUDGET: felt252 = 'Insufficient budget';

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        self.admin.write(admin);
        self.fund_requests_count.write(0, 0);
        self.project_budgets.write(0, 0);
    }

    #[abi(embed_v0)]
    impl BudgetImpl of IBudget<ContractState> {
        fn allocate_budget(
            ref self: ContractState,
            project_id: u64,
            category: felt252,
            amount: u128,
        ) {
            let caller = get_caller_address();
            let admin = self.admin.read();
            assert(caller == admin, ONLY_ADMIN);

            let remaining_budget = self.project_budgets.read(project_id);
            assert(amount <= remaining_budget, INSUFFICIENT_BUDGET);

            self.budget_allocations.write((project_id, category), amount);
            self.project_budgets.write(project_id, remaining_budget - amount);

            self.emit(BudgetAllocated { project_id, category, amount });
        }

        fn transfer_budget(
            ref self: ContractState,
            project_id: u64,
            from_category: felt252,
            to_category: felt252,
            amount: u128,
        ) {
            let caller = get_caller_address();
            let admin = self.admin.read();
            assert(caller == admin, ONLY_ADMIN);

            let from_balance = self.budget_allocations.read((project_id, from_category));
            assert(from_balance >= amount, INSUFFICIENT_BUDGET);

            let to_balance = self.budget_allocations.read((project_id, to_category));

            self.budget_allocations.write((project_id, from_category), from_balance - amount);
            self.budget_allocations.write((project_id, to_category), to_balance + amount);

            self.emit(BudgetTransferred { project_id, from_category, to_category, amount });
        }

        fn get_budget_allocation(self: @ContractState, project_id: u64, category: felt252) -> u128 {
            self.budget_allocations.read((project_id, category))
        }

        fn set_role(ref self: ContractState, user: ContractAddress, role: felt252) {
            let caller = get_caller_address();
            let admin = self.admin.read();
            assert(caller == admin, ONLY_ADMIN);

            self.role_permissions.write(user, role);
        }

        fn get_role(self: @ContractState, user: ContractAddress) -> felt252 {
            self.role_permissions.read(user)
        }
    }
}
