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
fn setup_test_data() -> (u64, u64, u64, u256, u256, felt252) {
    (
        1_u64, // project_id
        1_u64, // milestone_id  
        1_u64, // request_id
        1000_u256, // total_budget
        100_u256, // amount
        'First milestone' // description
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
    let requester = REQUESTER();

    // Deploy contract - now using updated function signature
    let (contract_address, dispatcher) = deploy_budget_contract(admin);

    // Setup test data via destructuring
    let (project_id, milestone_id, request_id, total_budget, amount, description) =
        setup_test_data();

    // Add organization as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(1));
    dispatcher.add_organization(org);

    // Create project as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(5));
    dispatcher.create_project(project_id, org, total_budget);

    // Create milestone and fund request
    dispatcher.create_milestone(project_id, milestone_id, description, amount, false);
    dispatcher.complete_milestone(project_id, milestone_id);
    dispatcher.create_fund_request(project_id, request_id, milestone_id, amount, requester);

    // Release funds as organization
    dispatcher.release_funds(org, project_id, request_id);

    // Perform verification operations as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(3));

    // Check project remaining budget was updated
    let project = dispatcher.get_project(project_id);
    assert(project.remaining_budget == total_budget - amount, 'Budget not updated correctly');

    // Check milestone is marked as released
    let milestone = dispatcher.get_milestone(project_id, milestone_id);
    assert(milestone.is_released == true, 'Milestone not marked released');

    // Check request status was updated to Approved
    let request = dispatcher.get_fund_request(project_id, request_id);
    assert(request.status == FundRequestStatus::Approved, 'Request not marked approved');
}

#[test]
fn test_successful_fund_release_transaction_recorded() {
    // Setup addresses
    let admin = ADMIN();
    let org = ORGANIZATION();
    let requester = REQUESTER();

    // Deploy contract - now using updated function signature
    let (contract_address, dispatcher) = deploy_budget_contract(admin);

    // Setup test data
    let (project_id, milestone_id, request_id, total_budget, amount, description) =
        setup_test_data();

    // Add organization as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(1));
    dispatcher.add_organization(org);

    // Create project as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(5));
    dispatcher.create_project(project_id, org, total_budget);

    // Create milestone and fund request
    dispatcher.create_milestone(project_id, milestone_id, description, amount, false);
    dispatcher.complete_milestone(project_id, milestone_id);
    dispatcher.create_fund_request(project_id, request_id, milestone_id, amount, requester);

    // Release funds as organization
    dispatcher.release_funds(org, project_id, request_id);

    // Perform verification operations as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(3));

    // Check transaction was recorded
    let tx_counter = dispatcher.get_transaction_count();
    assert(tx_counter == 1, 'Transaction not counted');

    // Check transaction was recorded in project transactions
    let project_tx_ids = dispatcher.get_project_transactions(project_id);
    assert(project_tx_ids.len() == 1, 'Transaction not recorded');
    assert(*project_tx_ids.at(0) == 1, 'Wrong transaction ID');

    // Check transaction details
    let tx = dispatcher.get_transaction(1);
    assert(tx.project_id == project_id, 'Wrong project ID in tx');
    assert(tx.transaction_type == TRANSACTION_FUND_RELEASE, 'Wrong tx type');
    assert(tx.amount == amount, 'Wrong amount in tx');
    assert(tx.executor == org, 'Wrong executor in tx');
    assert(tx.timestamp == get_block_timestamp(), 'Wrong block timestamp');
}

#[test]
fn test_successful_fund_release_event() {
    // Setup addresses
    let admin = ADMIN();
    let org = ORGANIZATION();
    let requester = REQUESTER();

    // Deploy contract - now using updated function signature
    let (contract_address, dispatcher) = deploy_budget_contract(admin);

    // Setup test data
    let (project_id, milestone_id, request_id, total_budget, amount, description) =
        setup_test_data();

    // Add organization as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(1));
    dispatcher.add_organization(org);

    // Create project as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(5));
    dispatcher.create_project(project_id, org, total_budget);

    // Create milestone and fund request
    dispatcher.create_milestone(project_id, milestone_id, description, amount, false);
    dispatcher.complete_milestone(project_id, milestone_id);
    dispatcher.create_fund_request(project_id, request_id, milestone_id, amount, requester);

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
                            project_id: 1, request_id: 1, milestone_id: 1, amount: 100,
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
    let requester = REQUESTER();

    // Deploy contract
    let (contract_address, dispatcher) = deploy_budget_contract(admin);

    // Setup test data
    let (project_id, milestone_id, request_id, total_budget, amount, description) =
        setup_test_data();

    // Add organization as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(1));

    // Add organization and create project
    dispatcher.add_organization(org);

    // Perform operations as non-organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(4));

    // Create project, milestone and fund request
    dispatcher.create_project(project_id, org, total_budget);
    dispatcher.create_milestone(project_id, milestone_id, description, amount, false);
    dispatcher.complete_milestone(project_id, milestone_id);
    dispatcher.create_fund_request(project_id, request_id, milestone_id, amount, requester);

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
    let requester = REQUESTER();

    // Deploy contract
    let (contract_address, dispatcher) = deploy_budget_contract(admin);

    // Setup test data
    let (project_id, milestone_id, request_id, total_budget, amount, description) =
        setup_test_data();

    // Add organization as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(2));

    // Add organization and create project
    dispatcher.add_organization(org);
    dispatcher.add_organization(other_org);

    // Perform operations as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(4));

    // Create project, milestone and fund request
    dispatcher.create_project(project_id, org, total_budget);
    dispatcher.create_milestone(project_id, milestone_id, description, amount, false);
    dispatcher.complete_milestone(project_id, milestone_id);
    dispatcher.create_fund_request(project_id, request_id, milestone_id, amount, requester);

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
    let requester = REQUESTER();

    // Deploy contract
    let (contract_address, dispatcher) = deploy_budget_contract(admin);

    // Setup test data
    let (project_id, milestone_id, request_id, total_budget, amount, description) =
        setup_test_data();

    // Add organization as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(1));

    // Add organization and create project
    dispatcher.add_organization(org);

    // Perform operations as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(3));

    // Create project, milestone and fund request
    dispatcher.create_project(project_id, org, total_budget);
    dispatcher.create_milestone(project_id, milestone_id, description, amount, false);
    dispatcher.create_fund_request(project_id, request_id, milestone_id, amount, requester);

    // Try to release funds as non-organization (should fail)
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(1));
    dispatcher.release_funds(org, project_id, request_id);
}

#[test]
#[should_panic(expected: 'Request not in Pending status')]
fn test_cannot_release_funds_for_already_approved_request() {
    // Setup addresses
    let admin = ADMIN();
    let org = ORGANIZATION();
    let requester = REQUESTER();

    // Deploy contract
    let (contract_address, dispatcher) = deploy_budget_contract(admin);

    // Setup test data
    let (project_id, milestone_id, request_id, total_budget, amount, description) =
        setup_test_data();

    // Add organization as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(1));

    // Add organization and create project
    dispatcher.add_organization(org);

    // Perform operations as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(4));

    // Create project, milestone and fund request
    dispatcher.create_project(project_id, org, total_budget);
    dispatcher.create_milestone(project_id, milestone_id, description, amount, false);
    dispatcher.complete_milestone(project_id, milestone_id);
    dispatcher.create_fund_request(project_id, request_id, milestone_id, amount, requester);

    // Try to release funds as non-organization (should fail)
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(2));
    dispatcher.release_funds(org, project_id, request_id);
    dispatcher.release_funds(org, project_id, request_id);
}

#[test]
#[should_panic(expected: 'Insufficient budget')]
fn test_cannot_release_funds_if_insufficient_budget() {
    // Setup addresses
    let admin = ADMIN();
    let org = ORGANIZATION();
    let requester = REQUESTER();

    // Deploy contract
    let (contract_address, dispatcher) = deploy_budget_contract(admin);

    // Setup test data with insufficient budget
    let project_id = 1_u64;
    let milestone_id = 1_u64;
    let request_id = 1_u64;
    let total_budget: u256 = 50; // Budget is less than request amount
    let amount: u256 = 100; // Amount is greater than budget
    let description = 'First milestone';

    // Add organization as admin accounnt
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(1));

    // Add organization and create project
    dispatcher.add_organization(org);

    // Perform operations as non-organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(4));

    // Create project, milestone and fund request
    dispatcher.create_project(project_id, org, total_budget);
    dispatcher.create_milestone(project_id, milestone_id, description, amount, false);
    dispatcher.complete_milestone(project_id, milestone_id);
    dispatcher.create_fund_request(project_id, request_id, milestone_id, amount, requester);

    // Try to release funds as non-organization (should fail)
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(1));
    dispatcher.release_funds(org, project_id, request_id);
}

#[test]
fn test_multiple_fund_releases() {
    // Setup addresses
    let admin = ADMIN();
    let org = ORGANIZATION();
    let requester = REQUESTER();

    // Deploy contract
    let (contract_address, dispatcher) = deploy_budget_contract(admin);

    // Setup test data for multiple milestones
    let project_id = 1_u64;
    let total_budget: u256 = 1000;

    // Add organization as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(1));

    // Add organization and create project
    dispatcher.add_organization(org);

    // Perform operations as organization
    cheat_caller_address(contract_address, org, CheatSpan::TargetCalls(9));
    dispatcher.create_project(project_id, org, total_budget);

    // Create milestone 1
    let milestone_id_1 = 1_u64;
    let request_id_1 = 1_u64;
    let amount_1: u256 = 200;
    dispatcher.create_milestone(project_id, milestone_id_1, 'First milestone', amount_1, false);
    dispatcher.complete_milestone(project_id, milestone_id_1);
    dispatcher.create_fund_request(project_id, request_id_1, milestone_id_1, amount_1, requester);

    // Create milestone 2
    let milestone_id_2 = 2_u64;
    let request_id_2 = 2_u64;
    let amount_2: u256 = 300;
    dispatcher.create_milestone(project_id, milestone_id_2, 'Second milestone', amount_2, false);
    dispatcher.complete_milestone(project_id, milestone_id_2);
    dispatcher.create_fund_request(project_id, request_id_2, milestone_id_2, amount_2, requester);

    // Release funds for milestone 1
    dispatcher.release_funds(org, project_id, request_id_1);

    // Release funds for milestone 2
    dispatcher.release_funds(org, project_id, request_id_2);

    // Perform verification operations as admin
    cheat_caller_address(contract_address, admin, CheatSpan::TargetCalls(7));

    // Check remaining budget
    let expected_remaining = total_budget - amount_1 - amount_2;
    let project = dispatcher.get_project(project_id);
    assert(project.remaining_budget == expected_remaining, 'Budget not updated correctly');

    // Check transaction counter
    let tx_counter = dispatcher.get_transaction_count();
    assert(tx_counter == 2, 'Transaction not counted');

    // Check project transactions
    let project_tx_ids = dispatcher.get_project_transactions(project_id);
    assert(project_tx_ids.len() == 2, 'Project transaction count wrong');
    assert(*project_tx_ids.at(0) == 1, 'First tx ID wrong');
    assert(*project_tx_ids.at(1) == 2, 'Second tx ID wrong');

    // Verify milestones are both released
    let milestone1 = dispatcher.get_milestone(project_id, milestone_id_1);
    let milestone2 = dispatcher.get_milestone(project_id, milestone_id_2);
    assert(milestone1.is_released == true, 'Milestone 1 not released');
    assert(milestone2.is_released == true, 'Milestone 2 not released');

    // Verify milestone fund requests are both updated to Approved
    let request1 = dispatcher.get_fund_request(project_id, request_id_1);
    let request2 = dispatcher.get_fund_request(project_id, request_id_2);
    assert(request1.status == FundRequestStatus::Approved, 'Request not marked approved');
    assert(request2.status == FundRequestStatus::Approved, 'Request not marked approved');
}
