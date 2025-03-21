use starknet::ContractAddress;

#[starknet::interface]
pub trait IBudget<TContractState> {
    // a function that updates a milestone when it is completed
    fn complete_milestone(
        ref self: TContractState, org: ContractAddress, project_id: u64, milestone_id: u64,
    ) -> bool;
}
