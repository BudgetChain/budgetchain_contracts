#[cfg(test)]
mod tests {
    use budgetchain_contracts::base::types::Transaction;
    use core::array::ArrayTrait;
    use budgetchain_contracts::base::types::{FundRequest, FundRequestStatus};
    use starknet::{ContractAddress, contract_address_const};
    use budgetchain_contracts::interfaces::IBudget::{IBudgetDispatcher, IBudgetDispatcherTrait};
    use snforge_std::{
        ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
        stop_cheat_caller_address, declare,
    };


    fn setup() -> (ContractAddress, ContractAddress) {
        let admin_address: ContractAddress = contract_address_const::<'admin'>();

        let declare_result = declare("Budget");
        assert(declare_result.is_ok(), 'Contract declaration failed');

        let contract_class = declare_result.unwrap().contract_class();
        let mut calldata = array![admin_address.into()];

        let deploy_result = contract_class.deploy(@calldata);
        assert(deploy_result.is_ok(), 'Contract deployment failed');

        let (contract_address, _) = deploy_result.unwrap();

        // ✅ Ensure we return the tuple correctly
        (contract_address, admin_address)
    }

    #[test]
    fn test_initial_data() {
        let (contract_address, admin_address) = setup();

        let dispatcher = IBudgetDispatcher { contract_address };

        // Ensure dispatcher methods exist
        let admin = dispatcher.get_admin();

        assert(admin == admin_address, 'incorrect admin');
    }
    // Simple tests for the Transaction struct
    #[test]
    fn test_transaction_struct() {
        let tx = Transaction {
            id: 1,
            project_id: 1,
            sender: contract_address_const::<1>(),
            recipient: contract_address_const::<2>(),
            amount: 1000_u128,
            timestamp: 123456789_u64,
            category: 'TEST',
            description: 'Test transaction',
        };

        assert(tx.id == 1, 'ID should be 1');
        assert(tx.amount == 1000_u128, 'Amount should be 1000');
        assert(tx.category == 'TEST', 'Category should be TEST');
    }

    // Function to validate pagination parameters
    fn validate_pagination(page: u64, page_size: u64) -> bool {
        if page == 0 {
            return false;
        }

        if page_size == 0 || page_size > 100 {
            return false;
        }

        true
    }

    #[test]
    fn test_pagination_validation() {
        // Valid parameters
        assert(validate_pagination(1, 10) == true, 'Valid params should pass');
        assert(validate_pagination(2, 50) == true, 'Valid params should pass');

        // Invalid page
        assert(validate_pagination(0, 10) == false, 'Page 0 invalid');

        // Invalid page size
        assert(validate_pagination(1, 0) == false, 'Size 0 invalid');
        assert(validate_pagination(1, 101) == false, 'Size 101 invalid');
    }

    #[test]
    fn test_all_get_fund_requests() {
        let (contract_address, _) = setup();

        let budget_dispatcher = IBudgetDispatcher { contract_address };

        let requester = contract_address_const::<'caller1'>();

        start_cheat_caller_address(contract_address, requester);

        // Create test fund requests
        let fund_request1 = FundRequest {
            project_id: 1, amount: 1000, requester, status: FundRequestStatus::Pending,
        };

        let fund_request2 = FundRequest {
            project_id: 1, amount: 2000, requester, status: FundRequestStatus::Approved,
        };

        // Create a fund request
        budget_dispatcher.set_fund_requests(fund_request1, 0);
        budget_dispatcher.set_fund_requests(fund_request2, 1);

        // Execute function
        let result = budget_dispatcher.get_fund_requests(1);
        stop_cheat_caller_address(contract_address);

        assert(result.len() == 2, 'Should return 2 requests');

        match result.get(0) {
            Option::Some(req) => {
                assert(req.amount == 1000, 'First amount mismatch');
                assert(req.status == FundRequestStatus::Pending, 'Status mismatch');
            },
            Option::None => panic!("Missing first request"),
        }

        match result.get(1) {
            Option::Some(req) => {
                assert(req.amount == 2000, 'Second amount mismatch');
                assert(req.status == FundRequestStatus::Approved, 'Status mismatch');
            },
            Option::None => panic!("Missing second request"),
        }
    }

    #[test]
    #[should_panic]
    fn test_get_fund_requests_empty() {
        let (contract_address, _) = setup();
        let dispatcher = IBudgetDispatcher { contract_address };

        // Attempt to get requests for non-existent project
        dispatcher.get_fund_requests(999_u64);
    }

    #[test]
    fn test_get_fund_requests_after_multiple_additions() {
        let (contract_address, _) = setup();
        let dispatcher = IBudgetDispatcher { contract_address };
        let requester = contract_address_const::<'caller1'>();

        start_cheat_caller_address(contract_address, requester);
        let project_id = 2_u64;

        // Add 5 test requests with sequential IDs
        let mut request_id = 0_u64;
        while request_id < 5_u64 {
            let request = FundRequest {
                project_id,
                amount: (request_id * 1000_u64).into(),
                requester,
                status: FundRequestStatus::Pending,
            };
            dispatcher.set_fund_requests(request, request_id);
            request_id += 1_u64;
        };

        // Verify count
        let count = dispatcher.get_fund_requests_counts(project_id); // 0_u64 is dummy
        assert(count == 5_u64, 'Count should be 5');

        // Retrieve and verify
        let result = dispatcher.get_fund_requests(project_id);
        stop_cheat_caller_address(contract_address);

        assert(result.len() == 5_u32, 'Should return all 5 requests');

        // Verify order and data integrity
        let mut j = 0_u32;
        while j < 5_u32 {
            match result.get(j) {
                Option::Some(req) => {
                    assert(req.project_id == project_id, 'Project ID mismatch');
                    assert(req.amount == (j * 1000_u32).into(), 'Amount mismatch at index');
                },
                Option::None => panic!("Missing request at index {}", j),
            }
            j += 1_u32;
        }
    }

    #[test]
    fn should_get_project_remaining_budget() {
        let (contract_address, admin_address) = setup();

        let dispatcher = IBudgetDispatcher { contract_address };

        let org_address = contract_address_const::<'Organization'>();
        let name = 'John';
        let mission = 'Help the Poor';
        let proj_owner = contract_address_const::<'Owner'>();

        start_cheat_caller_address(contract_address, admin_address);
        dispatcher.create_organization(name, org_address, mission);
        stop_cheat_caller_address(admin_address);

        start_cheat_caller_address(contract_address, org_address);
        let project_id = dispatcher
            .allocate_project_budget(
                org_address, proj_owner, 100, array!['Milestone1', 'Milestone2'], array![90, 10],
            );
        stop_cheat_caller_address(org_address);

        let remaining_budget = dispatcher.get_project_remaining_budget(project_id);
        assert(remaining_budget == 100, 'incorrect remaining budget');
    }

    #[test]
    fn test_fund_request_counter() {
        let (contract_address, admin_address) = setup();
        let caller = contract_address_const::<'address'>();
        start_cheat_caller_address(contract_address, caller);
        let dispatcher = IBudgetDispatcher { contract_address };
        let counter_before = dispatcher.get_fund_requests_counter();
        assert_eq!(counter_before, 1);
        //Ensure dispatcher method exist
        let dispatch_result = dispatcher.write_fund_request(caller, 10, 10, 10);
        assert_eq!(dispatch_result, true);
    }

    #[test]
    fn test_write_fund_request() {
        let (contract_address, admin_address) = setup();
        let caller = contract_address_const::<'address'>();
        start_cheat_caller_address(contract_address, caller);
        let dispatcher = IBudgetDispatcher { contract_address };

        //Ensure dispatcher method exist
        let dispatch_result = dispatcher.write_fund_request(caller, 10, 10, 10);
        assert_eq!(dispatch_result, true);
    }

    #[test]
    #[should_panic(expected: 'Milestone not completed')]
    fn test__milestone_completed() {
        let (contract_address, admin_address) = setup();
        let caller = contract_address_const::<'address'>();
        start_cheat_caller_address(contract_address, caller);
        let dispatcher = IBudgetDispatcher { contract_address };

        dispatcher.check_milestone(caller, 20, 30);
    }

    #[test]
    #[should_panic(expected: 'Only project owner can request')]
    fn test__unauthorized_collection() {
        let (contract_address, admin_address) = setup();
        let caller = contract_address_const::<'address'>();
        start_cheat_caller_address(contract_address, caller);
        let dispatcher = IBudgetDispatcher { contract_address };

        dispatcher.check_owner(caller, 20);
    }

    #[test]
    fn test_state_change() {
        let (contract_address, admin_address) = setup();
        let dispatcher = IBudgetDispatcher { contract_address };

        let set_fund_request = dispatcher.set_fund_requests_counter(20);
        assert_eq!(set_fund_request, true);
    }

    #[test]
    fn test_data() {
        let (contract_address, admin_address) = setup();
        let dispatcher = IBudgetDispatcher { contract_address };

        // Ensure dispatcher methods exist
        let admin = dispatcher.get_admin();

        assert(admin == admin_address, 'incorrect admin');

        //Ensure dispatcher method exist
        let get_transaction_count = dispatcher.get_transaction_count();
        assert_eq!(get_transaction_count, 10);

        let get_fund_request_counter = dispatcher.get_fund_requests_counter();
        assert_eq!(get_fund_request_counter, 1);
    }
}

