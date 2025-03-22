use budgetchain_contracts::base::types::{FundRequest};
use starknet::ContractAddress;

#[starknet::interface]
pub trait IBudget<TState> {
    fn get_fund_requests(self: @TState, project_id: u64) -> Array<FundRequest>;
    fn get_owner(self: @TState) -> ContractAddress;
}
