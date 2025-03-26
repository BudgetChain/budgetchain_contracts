use starknet::ContractAddress;
use crate::base::types::{Project, Milestone, FundRequest, Organization, Transaction};

#[starknet::interface]
pub trait IBudget<TContractState> {
    // Transaction Management
    fn create_transaction(
        ref self: TContractState,
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

    // Organization Management
    fn create_organization(
        ref self: TContractState, name: felt252, org_address: ContractAddress, mission: felt252,
    ) -> u256;
    fn get_organization(self: @TContractState, org_id: u256) -> Organization;

    // Project Management
    fn get_project(self: @TContractState, project_id: u64) -> Project;

    // Milestone Management
    fn get_milestone(self: @TContractState, project_id: u64, milestone_id: u64) -> Milestone;

    // Fund Request Management
    /// Releases funds for an approved request
    fn release_funds(
        ref self: TContractState, org: ContractAddress, project_id: u64, request_id: u64,
    );

    // Admin Management
    fn get_admin(self: @TContractState) -> ContractAddress;
}