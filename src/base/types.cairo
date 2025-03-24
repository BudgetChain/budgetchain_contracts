use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Transaction {
    pub id: u64,
    pub project_id: u64, // Add this field
    pub sender: ContractAddress,
    pub recipient: ContractAddress,
    pub amount: u128,
    pub timestamp: u64,
    pub category: felt252,
    pub description: felt252,