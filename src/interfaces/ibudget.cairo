use starknet::ContractAddress;

#[starknet::interface]
pub trait IBudget<TContractState> {

    // a function that creates a new milestone for a project
    fn create_milestone(
        ref self: TContractState, org: ContractAddress, project_id: u64, milestone_id: u64,
        milestone_name: u32, milestone_description: u32
    ) -> u64;

    // dummy create org function for testing
    fn create_org(
        ref self: TContractState, org: ContractAddress, org_id: u32
    ) -> bool;

    // a function that updates a milestone when it is completed
    fn complete_milestone(
        ref self: TContractState, org: ContractAddress, project_id: u64, milestone_id: u64,
    ) -> bool;
}
