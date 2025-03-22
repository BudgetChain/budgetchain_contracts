use starknet::ContractAddress;

/// Interface for Budget contract
#[starknet::interface]
pub trait IBudget<TContractState> {
    /// Releases funds for an approved request
    /// Parameters:
    ///   org: The organization releasing the funds
    ///   project_id: The ID of the project
    ///   request_id: The ID of the fund request
    fn release_funds(
        ref self: TContractState, org: ContractAddress, project_id: u64, request_id: u64,
    );
}

