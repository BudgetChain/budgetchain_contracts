use starknet::ContractAddress;

#[derive(Drop, Copy, Serde, PartialEq, starknet::Store)]
pub struct FundRequest {
    pub project_id: u64,
    pub amount: u128,
    pub requester: ContractAddress,
    pub status: FundRequestStatus,
}

#[derive(Drop, Copy, Serde, PartialEq, starknet::Store)]
#[allow(starknet::store_no_default_variant)]
pub enum FundRequestStatus {
    Pending,
    Approved,
    Rejected,
}
