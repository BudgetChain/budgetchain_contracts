use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Transaction {
    pub id: u64,
    pub sender: ContractAddress,
    pub recipient: ContractAddress,
    pub amount: u128,
    pub timestamp: u64,
    pub category: felt252,
    pub description: felt252,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Organization {
    pub id: u256,
    pub address: ContractAddress,
    pub name: felt252,
    pub is_active: bool,
    pub mission: felt252,
    pub created_at: u64,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Milestone {
    pub organization: u256,
    pub project_id: u64,
    pub milestone_description: felt252,
    pub milestone_amount: u256,
    pub created_at: u64,
}
