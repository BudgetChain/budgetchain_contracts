#[starknet::contract]
pub mod budget {
    use starknet::ContractAddress;
    use crate::interfaces::ibudget::IBudget;

    #[storage]
    struct Storage {}

    fn constructor(ref self: ContractState) {}

    #[abi(embed_v0)]
    impl budget of IBudget<ContractState> {
        fn complete_milestone(
            ref self: ContractState, org: ContractAddress, project_id: u64, milestone_id: u64,
        ) -> bool {
            true
        }
    }
}
