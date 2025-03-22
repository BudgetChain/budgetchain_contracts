#[starknet::contract]
mod Budget {
    use budgetchain_contracts::base::types::{FundRequest, FundRequestStatus};
    use budgetchain_contracts::interfaces::IBudget::IBudget;
    use core::array::ArrayTrait;
    use starknet::{ContractAddress};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use openzeppelin::access::ownable::{
        OwnableComponent // , interface::{IOwnableDispatcher, IOwnableDispatcherTrait}
    };

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        owner: ContractAddress,
        fund_requests: Map::<(u64, u64), FundRequest>, // Key: (project_id, request_id)
        fund_requests_count: Map::<u64, u64>, // Key: project_id, Value: count of requests
        project_budgets: Map::<u64, u128>, // Key: project_id, Value: remaining budget
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        FundsReleased: FundsReleased,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct FundsReleased {
        project_id: u64,
        request_id: u64,
        amount: u128,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        // Initialize contract state
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl BudgetImpl of IBudget<ContractState> {
        /// Retrieves all fund requests for a given project ID.
        fn get_fund_requests(self: @ContractState, project_id: u64) -> Array<FundRequest> {
            let mut fund_requests_to_return = ArrayTrait::new();

            // Get the total count of fund requests for this project
            let count = self.fund_requests_count.read(project_id);
            assert!(count > 0, "No fund requests found for this project ID");

            // Loop through all fund requests for the project
            let mut current_index = 0;

            while current_index < count {
                let fund_request = self.fund_requests.read((project_id, current_index));
                fund_requests_to_return.append(fund_request);
                current_index += 1;
            };

            fund_requests_to_return
        }

        /// Releases funds for an approved request.
        fn release_funds(
            ref self: ContractState, org: ContractAddress, project_id: u64, request_id: u64,
        ) {
            let caller = starknet::get_caller_address();

            // Ensure the caller is the organization (owner)
            assert!(caller == self.owner.read(), "Unauthorized caller");

            // Retrieve the fund request
            let mut fund_request: FundRequest = self.fund_requests.read((project_id, request_id));

            // Ensure the request is in Pending status
            assert!(fund_request.status == FundRequestStatus::Pending, "Invalid request status");

            // Retrieve the project's remaining budget
            let mut remaining_budget = self.project_budgets.read(project_id);

            // Ensure the project has enough budget
            assert!(remaining_budget >= fund_request.amount, "Insufficient project budget");

            // Update the request status to Approved
            fund_request.status = FundRequestStatus::Approved;
            self.fund_requests.write((project_id, request_id), fund_request);

            // Deduct the amount from the project's remaining budget
            remaining_budget -= fund_request.amount;
            self.project_budgets.write(project_id, remaining_budget);

            // Emit the FundsReleased event
            self
                .emit(
                    Event::FundsReleased(
                        FundsReleased { project_id, request_id, amount: fund_request.amount },
                    ),
                );
        }

        fn get_owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }
    }
}
