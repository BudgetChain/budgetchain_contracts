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
    fn test_get_project_transactions_basic() {
        let (contract_address, _) = setup();
        let dispatcher = IBudgetDispatcher { contract_address };
        let recipient = contract_address_const::<'recipient'>();
        let project_id: u64 = 42;
        let category: felt252 = project_id.into();
        let description = 'Test transaction';
        // Create 5 transactions for the project
        let mut i = 0_u64;
        while i < 5_u64 {
            dispatcher.create_transaction(recipient, 1000, category, description).unwrap();
            i += 1_u64;
        };
        // Retrieve all transactions (page 1, size 5)
        let (txs, total) = dispatcher.get_project_transactions(project_id, 1, 5).unwrap();

        assert(total == 5_u64, 'Total should be 5');
        assert(txs.len() == 5_u32, 'Should return 5 transactions');
    }

    #[test]
    fn test_get_project_transactions_pagination_and_integrity() {
        let (contract_address, _) = setup();
        let dispatcher = IBudgetDispatcher { contract_address };
        let recipient = contract_address_const::<'recipient'>();
        let project_id: u64 = 42;
        let category: felt252 = project_id.into();
        let description = 'Test transaction';
        // Create 25 transactions for the project
        let mut i = 0_u64;
        while i < 25_u64 {
            let amount: u128 = (1000 + i).into();
            dispatcher.create_transaction(recipient, amount, category, description).unwrap();
            i += 1_u64;
        };

        // Retrieve first page (page 1, size 10)
        let (txs, total) = dispatcher.get_project_transactions(project_id, 1, 10).unwrap();
        assert(total == 25_u64, 'Total should be 25');
        assert(txs.len() == 10_u32, 'Should return 10 transactions');
        // Check data integrity and order
        let mut j = 0_u32;
        while j < 10_u32 {
            let tx = txs.get(j).unwrap();
            let expected_id: u64 = j.into();
            let expected_amount: u128 = (1000 + j).into();

            assert(tx.id == expected_id, 'ID mismatch');
            assert(tx.amount == expected_amount, 'Amount mismatch');
            assert(tx.category == category, 'Category mismatch');
            assert(tx.description == description, 'Description mismatch');
            j += 1_u32;
        };

        // Retrieve last page (page 3, size 10)
        let (txs_last, _) = dispatcher.get_project_transactions(project_id, 3, 10).unwrap();
        assert(txs_last.len() == 5_u32, 'Page should have 5 transactions');
        // Retrieve out-of-range page (page 4, size 10)
        let (txs_empty, _) = dispatcher.get_project_transactions(project_id, 4, 10).unwrap();
        assert(txs_empty.len() == 0_u32, 'Out-of-range, should be empty');
    }

    #[test]
    #[should_panic]
    fn test_get_project_transactions_no_transactions() {
        let (contract_address, _) = setup();
        let dispatcher = IBudgetDispatcher { contract_address };
        let project_id: u64 = 9999;
        dispatcher.get_project_transactions(project_id, 1, 10).unwrap();
    }

    #[test]
    #[should_panic]
    fn test_get_project_transactions_invalid_page() {
        let (contract_address, _) = setup();
        let dispatcher = IBudgetDispatcher { contract_address };
        let project_id: u64 = 1;
        dispatcher.get_project_transactions(project_id, 0, 10).unwrap();
    }

    #[test]
    #[should_panic]
    fn test_get_project_transactions_invalid_page_size_zero() {
        let (contract_address, _) = setup();
        let dispatcher = IBudgetDispatcher { contract_address };
        let project_id: u64 = 1;
        dispatcher.get_project_transactions(project_id, 1, 0).unwrap();
    }

    #[test]
    #[should_panic]
    fn test_get_project_transactions_invalid_page_size_too_large() {
        let (contract_address, _) = setup();
        let dispatcher = IBudgetDispatcher { contract_address };
        let project_id: u64 = 1;
        dispatcher.get_project_transactions(project_id, 1, 101).unwrap();
    }

    #[test]
    fn test_get_project_transactions_single_transaction() {
        let (contract_address, _) = setup();
        let dispatcher = IBudgetDispatcher { contract_address };
        let recipient = contract_address_const::<'recipient'>();
        let project_id: u64 = 7;
        let category: felt252 = project_id.into();
        let description = 'Single transaction';
        dispatcher.create_transaction(recipient, 1234, category, description).unwrap();
        let (txs, total) = dispatcher.get_project_transactions(project_id, 1, 10).unwrap();
        assert(total == 1_u64, 'Total should be 1');
        assert(txs.len() == 1_u32, 'Should return 1 transaction');
        let tx = txs.get(0).unwrap();
        assert(tx.amount == 1234, 'Amount mismatch');
        assert(tx.description == description, 'Description mismatch');
    }

    #[test]
    fn test_get_project_transactions_multiple_projects_isolation() {
        let (contract_address, _) = setup();
        let dispatcher = IBudgetDispatcher { contract_address };
        let recipient = contract_address_const::<'recipient'>();
        let project_id1: u64 = 100;
        let project_id2: u64 = 200;
        let category1: felt252 = project_id1.into();
        let category2: felt252 = project_id2.into();
        dispatcher.create_transaction(recipient, 1, category1, 'P1-T1').unwrap();
        dispatcher.create_transaction(recipient, 2, category2, 'P2-T1').unwrap();
        dispatcher.create_transaction(recipient, 3, category1, 'P1-T2').unwrap();
        let (txs1, total1) = dispatcher.get_project_transactions(project_id1, 1, 10).unwrap();
        let (txs2, total2) = dispatcher.get_project_transactions(project_id2, 1, 10).unwrap();
        assert!(total1 == 2_u64, "Project 1 should have 2 transactions");
        assert!(total2 == 1_u64, "Project 2 should have 1 transaction");
        assert!(txs1.len() == 2_u32, "Project 1 should return 2 transactions");
        assert!(txs2.len() == 1_u32, "Project 2 should return 1 transaction");
        assert(txs1.get(0).unwrap().description == 'P1-T1', 'Project 1, Tx 1 desc mismatch');
        assert(txs1.get(1).unwrap().description == 'P1-T2', 'Project 1, Tx 2 desc mismatch');
        assert(txs2.get(0).unwrap().description == 'P2-T1', 'Project 2, Tx 1 desc mismatch');
    }

    #[test]
    fn test_project_transaction_count_and_storage() {
        let (contract_address, _) = setup();
        let dispatcher = IBudgetDispatcher { contract_address };
        let recipient = contract_address_const::<'recipient'>();
        let project_id: u64 = 55;
        let category: felt252 = project_id.into();
        let description = 'Count test';
        // Add 3 transactions
        dispatcher.create_transaction(recipient, 1, category, description).unwrap();
        dispatcher.create_transaction(recipient, 2, category, description).unwrap();
        dispatcher.create_transaction(recipient, 3, category, description).unwrap();
        let (txs, total) = dispatcher.get_project_transactions(project_id, 1, 10).unwrap();
        assert(total == 3_u64, 'Total should be 3');
        assert(txs.len() == 3_u32, 'Should return 3 transactions');
        // Check order and IDs
        assert(txs.get(0).unwrap().id == 0_u64, 'First tx id should be 0');
        assert(txs.get(1).unwrap().id == 1_u64, 'Second tx id should be 1');
        assert(txs.get(2).unwrap().id == 2_u64, 'Third tx id should be 2');
    }
}
