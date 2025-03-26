use starknet::ContractAddress;

// STRUCTS
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
pub struct Project {
    pub organization: ContractAddress,
    pub total_budget: u256,
    pub remaining_budget: u256,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Milestone {
    pub project_id: u64,
    pub milestone_description: felt252,
    pub milestone_amount: u256,
    pub is_completed: bool,
    pub is_released: bool,
}

#[derive(Drop, Copy, Serde, PartialEq, starknet::Store)]
pub struct FundRequest {
    pub project_id: u64,
    pub milestone_id: u64,
    pub amount: u256,
    pub requester: ContractAddress,
    pub status: FundRequestStatus,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Transaction {
    pub id: u64,
    pub project_id: u64,
    pub transaction_type: felt252,
    pub amount: u256,
    pub timestamp: u64,
    pub sender: ContractAddress,
    pub recipient: ContractAddress,
    pub category: felt252,
    pub description: felt252,
}

// ENUMS
#[derive(Drop, Copy, Serde, PartialEq, starknet::Store)]
#[allow(starknet::store_no_default_variant)]
pub enum FundRequestStatus {
    Pending,
    Approved,
    Rejected,
}

// TRANSACTION CONSTANTS
pub const TRANSACTION_FUND_RELEASE: felt252 = selector!("FUND_RELEASE");

// ROLE CONSTANTS
pub const ADMIN_ROLE: felt252 = selector!("ADMIN_ROLE");
pub const ORGANIZATION_ROLE: felt252 = selector!("ORGANIZATION_ROLE");