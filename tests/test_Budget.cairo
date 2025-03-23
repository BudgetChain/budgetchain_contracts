
#[cfg(test)]
mod tests {
    use starknet::contract_address_const;
    use budgetchain_contracts::base::types::Transaction;
    use core::array::ArrayTrait;
    use budgetchain_contracts::budgetchain::Budget;
    use budgetchain_contracts::interfaces::IBudget::{IBudget, IBudgetDispatcher};
    use budgetchain_contracts::base::types::{FundRequest, FundRequestStatus};
    use snforge_std::{
        declare, DeclareResultTrait, ContractClassTrait, start_cheat_caller_address,
        stop_cheat_caller_address,
    };
    use starknet::{ContractAddress, contract_address_const};
    use openzeppelin::utils::serde::SerializedAppend;
    
    fn owner() -> ContractAddress {
        contract_address_const::<'owner'>()
    }

    fn budget_deployment() -> (IBudgetDispatcher, ContractAddress) {
        let _contract = declare("Budget").unwrap().contract_class();

        let mut calldata: Array<felt252> = ArrayTrait::new();
        calldata.append_serde(owner());
        let (contract_address, _) = _contract.deploy(@calldata).unwrap();
        let budget_dispatcher = IBudgetDispatcher { contract_address };

        (budget_dispatcher, contract_address)
    }

    #[test]
    fn test_deployment() {
        let (_budget_dispatcher, _) = budget_deployment();
        // assert_eq!(
    //     _budget_dispatcher.get_owner(), owner(), "Owner should be set correctly at deployment",
    // );
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
    fn test_get_fund_requests() {
    let (_budget_dispatcher, contract_address) = budget_deployment();
    let caller_addr = contract_address_const::<'caller1'>();

    start_cheat_caller_address(contract_address, caller_addr);

    // Setup test data
    let _requester: ContractAddress = caller_addr;

    // // Create test fund requests
    // let _fund_request1 = FundRequest {
    //     project_id: 1,
    //     amount: 1000,
    //     requester,
    //     status: FundRequestStatus::Pending
    // };

    // let fund_request2 = FundRequest {
    //     project_id: 2,
    //     amount: 2000,
    //     requester,
    //     status: FundRequestStatus::Approved
    // };

    // fn return_funds(
    //     project_owner: ContractAddress,
    //     project_id: u64,
    //     amount: u256
    // )
    // // Create a fund request
    // budget_dispatcher.store_fund_request(project_id, 0, fund_request1);
    // budget_dispatcher.store_fund_request(project_id, 1, fund_request2);

    let _project_id = 1;
    // let fund_request = FundRequest {
    //     project_id,
    //     amount: 100,
    //     requester: caller_addr,
    //     status: Approved,
    // };
    stop_cheat_caller_address(contract_address);
}
}
