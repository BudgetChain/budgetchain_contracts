use budgetchain_contracts::base::errors::*;
use budgetchain_contracts::base::types::{FundRequestStatus, TRANSACTION_FUND_RELEASE};
use budgetchain_contracts::budgetchain::Budget::*;
use budgetchain_contracts::interfaces::IBudget::{IBudgetDispatcher, IBudgetDispatcherTrait};
use core::array::ArrayTrait;
use core::result::ResultTrait;
use core::traits::Into;
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait,
    cheat_caller_address, declare, spy_events,
};
use starknet::{ContractAddress, contract_address_const, get_block_timestamp};

// Utility functions to create test contract addresses from a felt
fn ADMIN() -> ContractAddress {
    contract_address_const::<'ADMIN'>()
}

fn ORGANIZATION() -> ContractAddress {
    contract_address_const::<'ORGANIZATION'>()
}

fn OTHER_ORG() -> ContractAddress {
    contract_address_const::<'OTHER_ORG'>()
}

fn NON_ORG() -> ContractAddress {
    contract_address_const::<'NON_ORG'>()
}

fn REQUESTER() -> ContractAddress {
    contract_address_const::<'REQUESTER'>()
}
// Utility function to setup test data that can be destructured
fn setup_test_data() -> (u64, u256, u256, felt252) {
    (
        1_u64, // milestone id
        1000_u256, // total_budget
        500_u256, // milestone amount
        'Test milestone' // milestone description
    )
}

// Helper function to deploy the Budget contract - updated signature
fn deploy_budget_contract(admin: ContractAddress) -> (ContractAddress, IBudgetDispatcher) {
    let contract_class = declare("Budget").unwrap().contract_class();

    // Set up constructor calldata with admin address
    let mut calldata: Array<felt252> = ArrayTrait::new();
    calldata.append(admin.into());

    // Deploy the contract
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();

    // Return the contract address and dispatcher
    (contract_address, IBudgetDispatcher { contract_address })
}

#[test]
fn test_successful_fund_release() {
    // Setup addresses
    let admin = ADMIN();
    let org = ORGANIZATION();

    // Deploy contract - now using updated function signature
    let (contract_address, dispatcher) = deploy_budget_contract(admin);

    // Setup test data via destructuring
    let (milestone_id, total_budget, amount, description) = setup_test_data();

    // Add organization as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(1));
    dispatcher.create_organization('StarkCorp', org, 'Serenity Max');

    // Create project as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(1));
    let project_id = dispatcher
        .allocate_project_budget(
            org, admin, total_budget, array![description, description], array![amount, amount],
        );

    // Complete milestone and create a new fund request as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(2));
    dispatcher.set_milestone_complete(project_id, milestone_id);
    let request_id = dispatcher.create_fund_request(project_id, milestone_id);

    // Release funds as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(1));
    dispatcher.release_funds(org, project_id, request_id);

    // Perform verification operations as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(3));

    // Check project remaining budget was updated
    let project = dispatcher.get_project(project_id);
    assert(project.total_budget == total_budget - amount, 'Budget not updated correctly');

    // Check milestone is marked as released
    let milestone = dispatcher.get_milestone(project_id, milestone_id);
    assert(milestone.released == true, 'Milestone not marked released');

    // Check request status was updated to Approved
    let request = dispatcher.get_fund_request(project_id, request_id);
    assert(request.status == FundRequestStatus::Approved, 'Request not marked approved');
}

#[test]
fn test_successful_fund_release_transaction_recorded() {
    // Setup addresses
    let admin = ADMIN();
    let org = ORGANIZATION();

    // Deploy contract - now using updated function signature
    let (contract_address, dispatcher) = deploy_budget_contract(admin);

    // Setup test data via destructuring
    let (milestone_id, total_budget, amount, description) = setup_test_data();

    // Add organization as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(1));
    dispatcher.create_organization('StarkCorp', org, 'Serenity Max');

    // Create project as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(1));
    let project_id = dispatcher
        .allocate_project_budget(
            org, admin, total_budget, array![description, description], array![amount, amount],
        );

    // Complete milestone and create a new fund request as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(2));
    dispatcher.set_milestone_complete(project_id, milestone_id);
    let request_id = dispatcher.create_fund_request(project_id, milestone_id);

    // Release funds as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(4));
    dispatcher.release_funds(org, project_id, request_id);

    // Check transaction was recorded
    let tx_counter = dispatcher.get_transaction_count();
    assert(tx_counter == 1, 'Transaction not counted');

    // Check transaction details
    let tx = dispatcher.get_transaction(1).into().unwrap();
    let request = dispatcher.get_fund_request(project_id, request_id);
    assert(tx.project_id == project_id, 'Wrong project ID in tx');
    assert(tx.sender == org, 'Wrong sender in tx');
    assert(tx.recipient == request.requester, 'Wrong recipient in tx');
    assert(tx.amount == amount.try_into().unwrap(), 'Wrong amount in tx');
    assert(tx.timestamp == get_block_timestamp(), 'Wrong block timestamp');
    assert(tx.category == TRANSACTION_FUND_RELEASE, 'Wrong tx category');
    assert(tx.description == description, 'Wrong tx description')
}

#[test]
fn test_successful_fund_release_event() {
    // Setup addresses
    let admin = ADMIN();
    let org = ORGANIZATION();

    // Deploy contract - now using updated function signature
    let (contract_address, dispatcher) = deploy_budget_contract(admin);

    // Setup test data via destructuring
    let (milestone_id, total_budget, amount, description) = setup_test_data();

    // Add organization as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(1));
    dispatcher.create_organization('StarkCorp', org, 'Serenity Max');

    // Create project as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(1));
    let project_id = dispatcher
        .allocate_project_budget(
            org, admin, total_budget, array![description, description], array![amount, amount],
        );

    // Complete milestone and create a new fund request as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(2));
    dispatcher.set_milestone_complete(project_id, milestone_id);
    let request_id = dispatcher.create_fund_request(project_id, milestone_id);

    // Release funds as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(1));

    // Set up event spy
    let mut spy = spy_events();

    // Release funds as organization
    dispatcher.release_funds(org, project_id, request_id);

    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    Budget::Event::FundsReleased(
                        Budget::FundsReleased {
                            project_id,
                            request_id,
                            milestone_id,
                            amount: amount.try_into().unwrap(),
                        },
                    ),
                ),
            ],
        );
}

#[test]
#[should_panic(expected: 'Caller is missing role')]
fn test_non_organization_cannot_release_funds() {
    // Setup addresses
    let admin = ADMIN();
    let non_org = NON_ORG();
    let org = ORGANIZATION();

    // Deploy contract
    let (contract_address, dispatcher) = deploy_budget_contract(admin);

    // Setup test data via destructuring
    let (milestone_id, total_budget, amount, description) = setup_test_data();

    // Add organization as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(1));
    dispatcher.create_organization('StarkCorp', org, 'Serenity Max');

    // Create project as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(1));
    let project_id = dispatcher
        .allocate_project_budget(
            org, admin, total_budget, array![description, description], array![amount, amount],
        );

    // Complete milestone and create a new fund request as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(2));
    dispatcher.set_milestone_complete(project_id, milestone_id);
    let request_id = dispatcher.create_fund_request(project_id, milestone_id);

    // Try to release funds as non-organization (should fail)
    cheat_caller_address(contract_address, non_org, CheatSpan::TargetCalls(1));
    dispatcher.release_funds(org, project_id, request_id);
}

#[test]
#[should_panic(expected: 'Only organization can release')]
fn test_wrong_organization_cannot_release_funds() {
    // Setup addresses
    let admin = ADMIN();
    let org = ORGANIZATION();
    let other_org = OTHER_ORG();

    // Deploy contract
    let (contract_address, dispatcher) = deploy_budget_contract(admin);

    // Setup test data via destructuring
    let (milestone_id, total_budget, amount, description) = setup_test_data();

    // Add organization as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(2));
    dispatcher.create_organization('StarkCorp', org, 'Serenity Max');
    dispatcher.create_organization('ETHMaxiCorp', other_org, 'Serenity Ultra');

    // Create project as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(1));
    let project_id = dispatcher
        .allocate_project_budget(
            org, admin, total_budget, array![description, description], array![amount, amount],
        );

    // Complete milestone and create a new fund request as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(2));
    dispatcher.set_milestone_complete(project_id, milestone_id);
    let request_id = dispatcher.create_fund_request(project_id, milestone_id);

    // Try to release funds as non-organization (should fail)
    cheat_caller_address(contract_address, other_org, CheatSpan::TargetCalls(1));
    dispatcher.release_funds(org, project_id, request_id);
}

#[test]
#[should_panic(expected: 'Project milestone incomplete')]
fn test_cannot_release_funds_for_incomplete_milestone() {
    // Setup addresses
    let admin = ADMIN();
    let org = ORGANIZATION();

    // Deploy contract
    let (contract_address, dispatcher) = deploy_budget_contract(admin);

    // Setup test data via destructuring
    let (milestone_id, total_budget, amount, description) = setup_test_data();

    // Add organization as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(1));
    dispatcher.create_organization('StarkCorp', org, 'Serenity Max');

    // Create project as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(1));
    let project_id = dispatcher
        .allocate_project_budget(
            org, admin, total_budget, array![description, description], array![amount, amount],
        );

    // Create a new fund request as admin for incomplete milestone
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(2));
    let request_id = dispatcher.create_fund_request(project_id, milestone_id);

    // Try to release funds for incomplete milestone (should fail)
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(1));
    dispatcher.release_funds(org, project_id, request_id);
}

#[test]
#[should_panic(expected: 'Request not in Pending status')]
fn test_cannot_release_funds_for_already_approved_request() {
    // Setup addresses
    let admin = ADMIN();
    let org = ORGANIZATION();

    // Deploy contract
    let (contract_address, dispatcher) = deploy_budget_contract(admin);

    // Setup test data via destructuring
    let (milestone_id, total_budget, amount, description) = setup_test_data();

    // Add organization as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(1));
    dispatcher.create_organization('StarkCorp', org, 'Serenity Max');

    // Create project as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(1));
    let project_id = dispatcher
        .allocate_project_budget(
            org, admin, total_budget, array![description, description], array![amount, amount],
        );

    // Complete milestone and create a new fund request as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(2));
    dispatcher.set_milestone_complete(project_id, milestone_id);
    let request_id = dispatcher.create_fund_request(project_id, milestone_id);

    // Release funds for already released request as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(2));
    dispatcher.release_funds(org, project_id, request_id);
    dispatcher.release_funds(org, project_id, request_id);
}

#[test]
#[should_panic(expected: 'Milestone sum != total budget')]
fn test_cannot_release_funds_if_budget_insufficient() {
    // Setup addresses
    let admin = ADMIN();
    let org = ORGANIZATION();

    // Deploy contract
    let (contract_address, dispatcher) = deploy_budget_contract(admin);

    // Setup test data with insufficient budget
    let milestone_id = 1_u64;
    let total_budget: u256 = 50; // Budget is less than request amount
    let amount: u256 = 100; // Amount is greater than budget
    let description = 'Test milestone';

    // Add organization as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(1));
    dispatcher.create_organization('StarkCorp', org, 'Serenity Max');

    // Create project as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(1));
    let project_id = dispatcher
        .allocate_project_budget(
            org, admin, total_budget, array![description, description], array![amount, amount],
        );

    // Complete milestone and create a new fund request as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(2));
    dispatcher.set_milestone_complete(project_id, milestone_id);
    let request_id = dispatcher.create_fund_request(project_id, milestone_id);

    // Try to release funds with insufficient budget (should fail)
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(1));
    dispatcher.release_funds(org, project_id, request_id);
}

#[test]
fn test_multiple_fund_releases() {
    // Setup addresses
    let admin = ADMIN();
    let org = ORGANIZATION();

    // Deploy contract
    let (contract_address, dispatcher) = deploy_budget_contract(admin);

    // Setup test data for multiple milestones
    let total_budget: u256 = 1000;
    let amount_1: u256 = 500;
    let amount_2: u256 = 500;

    // Add organization as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(1));
    dispatcher.create_organization('StarkCorp', org, 'Serenity Max');

    // Perform operations as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(1));
    let project_id = dispatcher
        .allocate_project_budget(
            org,
            admin,
            total_budget,
            array!['First milestone', 'Second milestone'],
            array![amount_1, amount_2],
        );

    // Create milestones as admin and set as complete
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(4));
    let milestone_id_1: u64 = 1;
    dispatcher.set_milestone_complete(project_id, milestone_id_1);
    let request_id_1 = dispatcher.create_fund_request(project_id, milestone_id_1);

    let milestone_id_2: u64 = 2;
    dispatcher.set_milestone_complete(project_id, milestone_id_2);
    let request_id_2 = dispatcher.create_fund_request(project_id, milestone_id_2);

    // Release funds as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(2));
    dispatcher.release_funds(org, project_id, request_id_1);
    dispatcher.release_funds(org, project_id, request_id_2);

    // Perform verification operations as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(6));

    // Check remaining budget
    let project = dispatcher.get_project(project_id);
    let expected_remaining = total_budget - (amount_1 + amount_2);
    assert(project.total_budget == expected_remaining, 'Budget not updated correctly');

    // Check transaction counter
    let tx_counter = dispatcher.get_transaction_count();
    assert(tx_counter == 2, 'Transaction not counted');

    // Verify milestones are both released
    let milestone1 = dispatcher.get_milestone(project_id, milestone_id_1);
    let milestone2 = dispatcher.get_milestone(project_id, milestone_id_2);
    assert(milestone1.released == true, 'Milestone 1 not released');
    assert(milestone2.released == true, 'Milestone 2 not released');

    // Verify milestone fund requests are both updated to Approved
    let request1 = dispatcher.get_fund_request(project_id, request_id_1);
    let request2 = dispatcher.get_fund_request(project_id, request_id_2);
    assert(request1.status == FundRequestStatus::Approved, 'Request not marked approved');
    assert(request2.status == FundRequestStatus::Approved, 'Request not marked approved');
}

#[test]
#[should_panic(expected: "No fund requests found for this project ID")]
fn test_get_fund_requests_empty() {
    // Setup addresses
    let admin = ADMIN();
    let org = ORGANIZATION();

    // Deploy contract - now using updated function signature
    let (contract_address, dispatcher) = deploy_budget_contract(admin);

    // Setup test data via destructuring
    let (milestone_id, total_budget, amount, description) = setup_test_data();

    // Add organization as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(1));
    dispatcher.create_organization('StarkCorp', org, 'Serenity Max');

    // Create project as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(1));
    let project_id = dispatcher
        .allocate_project_budget(
            org, admin, total_budget, array![description, description], array![amount, amount],
        );

    // Complete milestone and create a new fund request as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(3));
    dispatcher.set_milestone_complete(project_id, milestone_id);

    //should panic has no create_fund_request yet
    dispatcher.get_fund_requests(project_id);
}

#[test]
fn test_get_multiple_fund_request() {
    // Setup addresses
    let admin = ADMIN();
    let org = ORGANIZATION();

    // Deploy contract - now using updated function signature
    let (contract_address, dispatcher) = deploy_budget_contract(admin);

    // Setup test data via destructuring
    let (milestone_id, total_budget, amount, description) = setup_test_data();

    // Add organization as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(1));
    dispatcher.create_organization('StarkCorp', org, 'Serenity Max');

    // Create project as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(1));
    let project_id = dispatcher
        .allocate_project_budget(
            org, admin, total_budget, array![description, description], array![amount, amount],
        );

    // Complete milestone and create a new fund request as admin
    cheat_caller_address(contract_address, admin, CheatSpan::Indefinite);
    dispatcher.set_milestone_complete(project_id, milestone_id);
    let request_id = dispatcher.create_fund_request(project_id, milestone_id);

    // check fund request status should be pending by default
    // first assertion
    let request = dispatcher.get_fund_request(project_id, request_id);
    assert(request.status == FundRequestStatus::Pending, 'Request should be pending');

    // second assertion
    let request = dispatcher.get_fund_request(project_id, request_id);
    assert(request.status == FundRequestStatus::Pending, 'Request should be pending');

    // third assertion
    let request = dispatcher.get_fund_request(project_id, request_id);
    assert(request.status == FundRequestStatus::Pending, 'Request should be pending');
}

#[test]
#[should_panic(expected: 'Caller not authorized')]
fn test_get_fund_request_with_unauthorize_caller() {
    // Setup addresses
    let admin = ADMIN();
    let org = ORGANIZATION();
    let non_org = NON_ORG();

    // Deploy contract - now using updated function signature
    let (contract_address, dispatcher) = deploy_budget_contract(admin);

    // Setup test data via destructuring
    let (milestone_id, total_budget, amount, description) = setup_test_data();

    // Add organization as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(1));
    dispatcher.create_organization('StarkCorp', org, 'Serenity Max');

    // Create project as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(1));
    let project_id = dispatcher
        .allocate_project_budget(
            org, admin, total_budget, array![description, description], array![amount, amount],
        );

    // Complete milestone and create a new fund request as admin
    cheat_caller_address(contract_address, non_org, CheatSpan::Indefinite);
    dispatcher.set_milestone_complete(project_id, milestone_id);
    let request_id = dispatcher.create_fund_request(project_id, milestone_id);

    // check fund request status should be pending by default
    // first assertion
    let request = dispatcher.get_fund_request(project_id, request_id);
    assert(request.status == FundRequestStatus::Pending, 'Request should be pending');
}

#[test]
fn test_write_fund_request() {
    // Setup addresses
    let admin = ADMIN();
    let org = ORGANIZATION();

    // Deploy contract - now using updated function signature
    let (contract_address, dispatcher) = deploy_budget_contract(admin);

    // Setup test data via destructuring
    let (milestone_id, total_budget, amount, description) = setup_test_data();

    // Add organization as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(1));
    dispatcher.create_organization('StarkCorp', org, 'Serenity Max');

    // Create project as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(1));
    let project_id = dispatcher
        .allocate_project_budget(
            org, admin, total_budget, array![description, description], array![amount, amount],
        );

    // Create milestones as admin and set as complete
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(3));
    let milestone_id_1: u64 = 1;
    let requester_id_1: u64 = 19;
    dispatcher.set_milestone_complete(project_id, milestone_id_1);
    // first write request by admin
    dispatcher.write_fund_request(admin, project_id, milestone_id_1, requester_id_1);

    let milestone_id_2: u64 = 1;
    let requester_id_2: u64 = 19;
    // second write request by org
    dispatcher.write_fund_request(admin, project_id, milestone_id_2, requester_id_2);
}

#[test]
#[should_panic(expected: 'Caller not authorized')]
fn test_write_fund_request_unauthorize_caller() {
    // Setup addresses
    let admin = ADMIN();
    let org = ORGANIZATION();
    let non_org = NON_ORG();

    // Deploy contract - now using updated function signature
    let (contract_address, dispatcher) = deploy_budget_contract(admin);

    // Setup test data via destructuring
    let (milestone_id, total_budget, amount, description) = setup_test_data();

    // Add organization as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(1));
    dispatcher.create_organization('StarkCorp', org, 'Serenity Max');

    // Create project as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(1));
    let project_id = dispatcher
        .allocate_project_budget(
            org, admin, total_budget, array![description, description], array![amount, amount],
        );

    // Create milestones as admin and set as complete
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(2));
    let milestone_id_1: u64 = 1;
    let requester_id_1: u64 = 19;
    dispatcher.set_milestone_complete(project_id, milestone_id_1);

    //test will panic when non_org try perform a write fn
    dispatcher.write_fund_request(non_org, project_id, milestone_id_1, requester_id_1);
}
#[test]
fn test_fund_request_counter() {
    // Setup addresses
    let admin = ADMIN();
    let org = ORGANIZATION();

    // Deploy contract - now using updated function signature
    let (contract_address, dispatcher) = deploy_budget_contract(admin);

    // Setup test data via destructuring
    let (milestone_id, total_budget, amount, description) = setup_test_data();

    // Add organization as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(1));
    dispatcher.create_organization('StarkCorp', org, 'Serenity Max');

    // Create project as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(1));
    let project_id = dispatcher
        .allocate_project_budget(
            org, admin, total_budget, array![description, description], array![amount, amount],
        );
    // Complete milestone and create a new fund request as admin
    cheat_caller_address(contract_address, admin, CheatSpan::Indefinite);
    dispatcher.set_milestone_complete(project_id, milestone_id);
    let request_id = dispatcher.create_fund_request(project_id, milestone_id);

    // set and get fund count
    let fund_request = dispatcher.get_fund_request(project_id, request_id);
    dispatcher.set_fund_requests(fund_request, request_id);
    let count = dispatcher.get_fund_requests_counts(project_id);

    assert!(count == request_id + 1, "fund request count is not updated");
}

#[test]
fn test_get_project_remaining_budget() {
    // Setup addresses
    let admin = ADMIN();
    let org = ORGANIZATION();

    // Deploy contract - now using updated function signature
    let (contract_address, dispatcher) = deploy_budget_contract(admin);

    // Setup test data via destructuring
    let (milestone_id, total_budget, amount, description) = setup_test_data();

    // Add organization as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(1));
    dispatcher.create_organization('StarkCorp', org, 'Serenity Max');

    // Create project as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(1));
    let project_id = dispatcher
        .allocate_project_budget(
            org, admin, total_budget, array![description, description], array![amount, amount],
        );

    // Complete milestone and create a new fund request as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(2));
    dispatcher.set_milestone_complete(project_id, milestone_id);
    let request_id = dispatcher.create_fund_request(project_id, milestone_id);

    // Release funds as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(1));
    dispatcher.release_funds(org, project_id, request_id);

    // Perform verification operations as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(3));

    // Check project remaining budget was updated
    let project = dispatcher.get_project(project_id);
    assert(project.total_budget == total_budget - amount, 'Budget not updated correctly');
}

#[test]
#[should_panic(expected: 'Budget not updated correctly')]
fn test_get_project_remaining_budget_with_wrong_budget_update() {
    // Setup addresses
    let admin = ADMIN();
    let org = ORGANIZATION();

    // Deploy contract - now using updated function signature
    let (contract_address, dispatcher) = deploy_budget_contract(admin);

    // Setup test data via destructuring
    let (milestone_id, total_budget, amount, description) = setup_test_data();

    // Add organization as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(1));
    dispatcher.create_organization('StarkCorp', org, 'Serenity Max');

    // Create project as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(1));
    let project_id = dispatcher
        .allocate_project_budget(
            org, admin, total_budget, array![description, description], array![amount, amount],
        );

    // Complete milestone and create a new fund request as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(2));
    dispatcher.set_milestone_complete(project_id, milestone_id);
    let request_id = dispatcher.create_fund_request(project_id, milestone_id);

    // Release funds as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(1));
    dispatcher.release_funds(org, project_id, request_id);

    // Perform verification operations as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(3));

    // Check project remaining budget was updated
    let project = dispatcher.get_project(project_id);
    assert(project.total_budget == total_budget - amount + 100, 'Budget not updated correctly');
}

#[test]
fn test_successful_request_funds(){
    // Setup addresses
    let admin = ADMIN();
    let org = ORGANIZATION();

    // Deploy contract - now using updated function signature
    let (contract_address, dispatcher) = deploy_budget_contract(admin);

    // Setup test data via destructuring
    let (milestone_id, total_budget, amount, description) = setup_test_data();

    // Add organization as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(1));
    dispatcher.create_organization('StarkCorp', org, 'Serenity Max');

    // Create project as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(1));
    let project_id = dispatcher
        .allocate_project_budget(
            org, admin, total_budget, array![description, description], array![amount, amount],
        );

    // Complete milestone and create a new fund request as admin
    cheat_caller_address(contract_address, admin, CheatSpan::Indefinite);
    dispatcher.set_milestone_complete(project_id, milestone_id);
    let request_id = dispatcher.create_fund_request(project_id, milestone_id);
    //request for fund as a admin
    dispatcher.request_funds(admin, project_id, milestone_id, request_id);
    // Check fund request status should be pending by default
    // first assertion
    let request = dispatcher.get_fund_request(project_id, request_id);
    assert(request.status == FundRequestStatus::Pending, 'Request should be pending');
    // second assertion
    let request = dispatcher.get_fund_request(project_id, request_id);
    assert(request.status == FundRequestStatus::Pending, 'Request should be pending');
    // third assertion
    let request = dispatcher.get_fund_request(project_id, request_id);
    assert(request.status == FundRequestStatus::Pending, 'Request should be pending');
    
}

#[test]
#[should_panic(expected: 'Only project owner can request')]
fn test_unauthorize_caller_request_funds(){
    // Setup addresses
    let admin = ADMIN();
    let org = ORGANIZATION();
    let non_org = NON_ORG();

    // Deploy contract - now using updated function signature
    let (contract_address, dispatcher) = deploy_budget_contract(admin);

    // Setup test data via destructuring
    let (milestone_id, total_budget, amount, description) = setup_test_data();

    // Add organization as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(1));
    dispatcher.create_organization('StarkCorp', org, 'Serenity Max');

    // Create project as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(1));
    let project_id = dispatcher
        .allocate_project_budget(
            org, admin, total_budget, array![description, description], array![amount, amount],
        );

    // Complete milestone and create a new fund request as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(2));
    dispatcher.set_milestone_complete(project_id, milestone_id);
    let request_id = dispatcher.create_fund_request(project_id, milestone_id);

    //request for fund as a non_org
    dispatcher.request_funds(non_org, project_id, milestone_id, request_id);
}

#[test]
#[should_panic(expected: 'Funds already released')]
fn test_is_fund_release_request_funds(){
    // Setup addresses
    let admin = ADMIN();
    let org = ORGANIZATION();

    // Deploy contract - now using updated function signature
    let (contract_address, dispatcher) = deploy_budget_contract(admin);

    // Setup test data via destructuring
    let (milestone_id, total_budget, amount, description) = setup_test_data();

    // Add organization as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(1));
    dispatcher.create_organization('StarkCorp', org, 'Serenity Max');

    // Create project as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(1));
    let project_id = dispatcher
        .allocate_project_budget(
            org, admin, total_budget, array![description, description], array![amount, amount],
        );

    // Complete milestone and create a new fund request as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(2));
    dispatcher.set_milestone_complete(project_id, milestone_id);
    let request_id = dispatcher.create_fund_request(project_id, milestone_id);

    // Release funds as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(2));
    // Release funds as organization
    dispatcher.release_funds(org, project_id, request_id);
    dispatcher.request_funds(org, project_id, milestone_id, request_id);


}

#[test]
#[should_panic(expected: 'Project milestone incomplete')]
fn test_milestone_not_complete_request_funds(){
    // Setup addresses
    let admin = ADMIN();
    let org = ORGANIZATION();

    // Deploy contract - now using updated function signature
    let (contract_address, dispatcher) = deploy_budget_contract(admin);

    // Setup test data via destructuring
    let (milestone_id, total_budget, amount, description) = setup_test_data();

    // Add organization as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(1));
    dispatcher.create_organization('StarkCorp', org, 'Serenity Max');

    // Create project as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(1));
    let project_id = dispatcher
        .allocate_project_budget(
            org, admin, total_budget, array![description, description], array![amount, amount],
        );

    // create a new fund request as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(2));
    let request_id = dispatcher.create_fund_request(project_id, milestone_id);
    dispatcher.request_funds(org, project_id, milestone_id, request_id);
}