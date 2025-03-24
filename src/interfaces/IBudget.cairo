use core::array::Array;
use core::result::Result;
use starknet::ContractAddress;
use budgetchain_contracts::base::types::Transaction;
use budgetchain_contracts::base::types::{FundRequest};

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

    // This function returns all transactions with pagination support
    fn get_transaction_history(
        self: @TContractState, page: u64, page_size: u64,
    ) -> Result<Array<Transaction>, felt252>;

    // This function returns the total count of transactions
    fn set_fund_requests(ref self: TContractState, fund_request: FundRequest, budget_id: u64);
    fn set_fund_requests_counts(ref self: TContractState, project_id: u64, count: u64);
    fn get_fund_requests_counts(self: @TContractState, project_id: u64) -> u64;
    fn get_transaction_count(self: @TContractState) -> u64;
    fn get_fund_requests(self: @TContractState, project_id: u64) -> Array<FundRequest>;
    fn get_admin(self: @TContractState) -> ContractAddress;
}
