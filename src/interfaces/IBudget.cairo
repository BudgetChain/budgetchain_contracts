use core::array::Array;
use core::result::Result;
use starknet::ContractAddress;
use budgetchain_contracts::base::types::Transaction;

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
    fn get_transaction_count(self: @TContractState) -> u64;

     fn get_project_transactions(self: @TContractState, project_id: u64) -> Array<Transaction>;
}
