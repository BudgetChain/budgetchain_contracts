use budgetchain_contracts::base::types::{
    FundRequest, Milestone, Organization, Project, Transaction,
};
use starknet::ContractAddress;

#[starknet::interface]
pub trait IBudget<TContractState> {
    // Transaction Management
    fn create_transaction(
        ref self: TContractState,
        project_id: u64,
        recipient: ContractAddress,
        amount: u128,
        category: felt252,
        description: felt252,
    ) -> Result<u64, felt252>;
    fn get_transaction(self: @TContractState, id: u64) -> Result<Transaction, felt252>;
    fn get_transaction_history(
        self: @TContractState, page: u64, page_size: u64,
    ) -> Result<Array<Transaction>, felt252>;
    fn get_transaction_count(self: @TContractState) -> u64;

    // Project Management
    fn get_project(self: @TContractState, project_id: u64) -> Project;
    fn get_project_remaining_budget(self: @TContractState, project_id: u64) -> u256;
    fn get_project_transactions(
        self: @TContractState, project_id: u64, page: u64, page_size: u64,
    ) -> Result<(Array<Transaction>, u64), felt252>;
    fn allocate_project_budget(
        ref self: TContractState,
        org: ContractAddress,
        project_owner: ContractAddress,
        total_budget: u256,
        milestone_descriptions: Array<felt252>,
        milestone_amounts: Array<u256>,
    ) -> u64;

    // Organization Management
    fn create_organization(
        ref self: TContractState, name: felt252, org_address: ContractAddress, mission: felt252,
    ) -> u256;
    fn get_organization(self: @TContractState, org_id: u256) -> Organization;
    fn is_authorized_organization(self: @TContractState, org: ContractAddress) -> bool;

    // Fund Request Management
    fn get_fund_request(self: @TContractState, project_id: u64, request_id: u64) -> FundRequest;
    fn get_fund_requests(self: @TContractState, project_id: u64) -> Array<FundRequest>;
    fn set_fund_requests(ref self: TContractState, fund_request: FundRequest, budget_id: u64);
    fn get_fund_requests_counts(self: @TContractState, project_id: u64) -> u64;
    fn set_fund_requests_counts(ref self: TContractState, project_id: u64, count: u64);
    fn create_fund_request(ref self: TContractState, project_id: u64, milestone_id: u64) -> u64;
    fn release_funds(
        ref self: TContractState, org: ContractAddress, project_id: u64, request_id: u64,
    );

    // Milestone Management
    fn create_milestone(
        ref self: TContractState,
        org: ContractAddress,
        project_id: u64,
        milestone_description: felt252,
        milestone_amount: u256,
    ) -> u64;
    fn get_milestone(self: @TContractState, project_id: u64, milestone_id: u64) -> Milestone;
    fn set_milestone_complete(ref self: TContractState, project_id: u64, milestone_id: u64);

    // Admin Management
    fn get_admin(self: @TContractState) -> ContractAddress;
    fn request_funds(
        ref self: TContractState,
        requester: ContractAddress,
        project_id: u64,
        milestone_id: u64,
        request_id: u64,
    ) -> u64;
    fn write_fund_request(
        ref self: TContractState,
        requester: ContractAddress,
        project_id: u64,
        milestone_id: u64,
        request_id: u64,
    ) -> bool;
    fn funds_released(self: @TContractState, project_id: u64, milestone_id: u64);
    fn check_milestone(
        self: @TContractState, requester: ContractAddress, project_id: u64, milestone_id: u64,
    );
    fn check_owner(self: @TContractState, requester: ContractAddress, project_id: u64);
    fn set_fund_requests_counter(ref self: TContractState, value: u64) -> bool;
    fn get_fund_requests_counter(self: @TContractState) -> u64;
}
