#[starknet::contract]
pub mod budget {
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map,
    };
    use crate::interfaces::ibudget::IBudget;
    use crate::base::types::Milestone;

    #[storage]
    struct Storage {
        milestone_amount: u32,
        milestones: Map<u32, Array<Milestone>>, // and organization and its array of milestones its covering
        next_milestone_id: u32,
        organizations: Map<ContractAddress, u32>,
    }

    fn constructor(ref self: ContractState) {}

    #[abi(embed_v0)]
    impl budget of IBudget<ContractState> {
        fn complete_milestone(
            ref self: ContractState, org: ContractAddress, project_id: u64, milestone_id: u64,
        ) -> bool {

            let current_milestone_id = self.next_milestone_id.read();
            self.next_milestone_id.write(current_milestone_id + 1);
            true
        }

        fn create_milestone(
            ref self: ContractState, org: ContractAddress, project_id: u64, milestone_id: u64,
            milestone_name: u32, milestone_description: u32
        ) -> u64 {            
            1
        }

        fn create_org(
            ref self: ContractState, org: ContractAddress, org_id: u32
        ) -> bool {
            // this is a test fucntion for now
            // more checks and comepletios should be done to this function but it was written to asser the milestone functions were working as expected
            self.organizations.entry(org).write(org_id);
            true            
        }


    }
}
