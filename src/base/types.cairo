use starknet::ContractAddress;

#[derive(Drop, Serde, PartialEq, Debug, starknet::Store, Clone)]
pub struct Milestone {
    org: ContractAddress,
    project_id: u64,
    milestone_description: felt252,
    milestone_amount: u256,
    completed: bool
}