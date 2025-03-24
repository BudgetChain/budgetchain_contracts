use starknet::ContractAddress;
use crate::base::types::{Project, Milestone, FundRequest, Transaction};

#[starknet::interface]
pub trait IBudget<TContractState> {
    /// Getter functions
    fn get_admin(self: @TContractState) -> ContractAddress;

    /// Organization Management
    fn add_organization(ref self: TContractState, org: ContractAddress);
    fn remove_organization(ref self: TContractState, org: ContractAddress);
    fn is_organization(self: @TContractState, org: ContractAddress) -> bool;

    /// Project Management
    fn create_project(
        ref self: TContractState,
        project_id: u64,
        organization: ContractAddress,
        total_budget: u256,
    );
    fn get_project(self: @TContractState, project_id: u64) -> Project;

    /// Milestone Management
    fn create_milestone(
        ref self: TContractState,
        project_id: u64,
        milestone_id: u64,
        description: felt252,
        amount: u256,
        is_completed: bool,
    );
    fn complete_milestone(ref self: TContractState, project_id: u64, milestone_id: u64);
    fn get_milestone(self: @TContractState, project_id: u64, milestone_id: u64) -> Milestone;

    /// Fund Request Management
    fn create_fund_request(
        ref self: TContractState,
        project_id: u64,
        request_id: u64,
        milestone_id: u64,
        amount: u256,
        requester: ContractAddress,
    );
    fn get_fund_request(self: @TContractState, project_id: u64, request_id: u64) -> FundRequest;

    /// Releases funds for an approved request
    fn release_funds(
        ref self: TContractState, org: ContractAddress, project_id: u64, request_id: u64,
    );

    /// Transaction related getters
    fn get_transaction_count(self: @TContractState) -> u64;
    fn get_transaction(self: @TContractState, transaction_id: u64) -> Transaction;
    fn get_project_transactions(self: @TContractState, project_id: u64) -> Array<u64>;
}
