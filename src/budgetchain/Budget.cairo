use starknet::ContractAddress;
use crate::interfaces::IBudget::IBudget;

/// Request status enum
#[derive(Copy, Drop, Serde, starknet::Store, PartialEq)]
enum RequestStatus {
    Pending,
    Approved,
    Rejected,
}

#[starknet::contract]
pub mod Budget {
    use super::{ContractAddress, IBudget, RequestStatus};
    use starknet::get_caller_address;

    /// Project data structure
    #[derive(Copy, Drop, Serde, starknet::Store)]
    struct Project {
        organization: ContractAddress,
        total_budget: u256,
        remaining_budget: u256,
    }

    /// Fund request data structure
    #[derive(Copy, Drop, Serde, starknet::Store)]
    struct FundRequest {
        project_id: u64,
        amount: u256,
        status: RequestStatus,
        milestone_id: u64,
    }

    /// Milestone data structure
    #[derive(Copy, Drop, Serde, starknet::Store)]
    struct Milestone {
        project_id: u64,
        is_released: bool,
    }

    /// Funds released event
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        FundsReleased: FundsReleased,
    }

    #[derive(Drop, starknet::Event)]
    struct FundsReleased {
        project_id: u64,
        request_id: u64,
        amount: u256,
    }

    #[storage]
    struct Storage {
        projects: LegacyMap::<u64, Project>,
        fund_requests: LegacyMap::<u64, FundRequest>,
        milestones: LegacyMap::<u64, Milestone>,
    }

    #[abi(embed_v0)]
    impl BudgetImpl of super::IBudget<ContractState> {
        /// Implementation of release_funds function
        /// Allows organizations to release funds for approved requests
        fn release_funds(
            ref self: ContractState, org: ContractAddress, project_id: u64, request_id: u64,
        ) {
            // Get the caller address for authorization
            let caller = get_caller_address();

            // Ensure caller is the organization associated with the project
            let project = self.projects.read(project_id);
            assert(project.organization == org && org == caller, 'Only organization can release');

            // Get the fund request
            let mut request = self.fund_requests.read(request_id);

            // Ensure the request is for the correct project
            assert(request.project_id == project_id, 'Invalid project ID');

            // Ensure the request is in pending status
            assert(request.status == RequestStatus::Pending, 'Request not in Pending status');

            // Get the milestone
            let mut milestone = self.milestones.read(request.milestone_id);

            // Ensure the milestone is for the correct project
            assert(milestone.project_id == project_id, 'Invalid milestone');

            // Update the request status to Approved
            request.status = RequestStatus::Approved;
            self.fund_requests.write(request_id, request);

            // Mark the milestone as released
            milestone.is_released = true;
            self.milestones.write(request.milestone_id, milestone);

            // Update the project's remaining budget
            let mut updated_project = project;
            updated_project.remaining_budget -= request.amount;
            self.projects.write(project_id, updated_project);

            // Emit the FundsReleased event
            self
                .emit(
                    Event::FundsReleased(
                        FundsReleased { project_id, request_id, amount: request.amount },
                    ),
                );
        }
    }
}
