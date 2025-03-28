use budgetchain_contracts::interfaces::IBudget::{IBudgetDispatcher, IBudgetDispatcherTrait};
use budgetchain_contracts::budgetchain::Budget;
use budgetchain_contracts::base::types::{FundRequest, FundRequestStatus, Transaction, Project, Milestone};
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address, cheat_caller_address, declare, spy_events, EventSpyAssertionsTrait,
};
use starknet::{ContractAddress, contract_address_const};

fn setup() -> (ContractAddress, ContractAddress) {
    let admin_address: ContractAddress = contract_address_const::<'admin'>();

    let declare_result = declare("Budget");
    assert(declare_result.is_ok(), 'Contract declaration failed');

    let contract_class = declare_result.unwrap().contract_class();
    let mut calldata = array![admin_address.into()];

    let deploy_result = contract_class.deploy(@calldata);
    assert(deploy_result.is_ok(), 'Contract deployment failed');

    let (contract_address, _) = deploy_result.unwrap();

    (contract_address, admin_address)
}

/// Setup a test environment with an organization, project, and milestones
fn setup_project_with_milestones() -> (
    ContractAddress, ContractAddress, ContractAddress, ContractAddress, u64, u256
) {
    let (contract_address, admin_address) = setup();
    let dispatcher = IBudgetDispatcher { contract_address };

    // Create organization
    let org_name = 'Test Org';
    let org_address = contract_address_const::<'Organization'>();
    let org_mission = 'Testing Budget Chain';

    // Create project owner
    let project_owner = contract_address_const::<'ProjectOwner'>();
    
    // Set admin as caller to create organization
    cheat_caller_address(contract_address, admin_address, CheatSpan::Indefinite);
    let org_id = dispatcher.create_organization(org_name, org_address, org_mission);
    stop_cheat_caller_address(admin_address);
    
    // Create project with initial budget of 1000
    let total_budget: u256 = 1000;
    
    // Set milestone descriptions and amounts
    let mut milestone_descriptions = array!['Initial Setup'];
    let mut milestone_amounts = array![total_budget];
    
    // Set org_address as caller to create project
    cheat_caller_address(contract_address, org_address, CheatSpan::Indefinite);
    let project_id = dispatcher.allocate_project_budget(
        org_address,
        project_owner, 
        total_budget, 
        milestone_descriptions, 
        milestone_amounts
    );
    stop_cheat_caller_address(org_address);
    
    (contract_address, admin_address, org_address, project_owner, project_id, total_budget)
}

#[test]
fn test_get_project_remaining_budget_initial() {
    // Setup project with milestones
    let (contract_address, admin_address, org_address, project_owner, project_id, total_budget) = 
        setup_project_with_milestones();
    
    let dispatcher = IBudgetDispatcher { contract_address };
    
    // Test that initial remaining budget equals total budget
    let remaining_budget = dispatcher.get_project_remaining_budget(project_id);
    assert(remaining_budget == total_budget, 'Initial budget incorrect');
}

#[test]
fn test_get_project_remaining_budget_after_milestone_creation() {
    // Setup project with milestones
    let (contract_address, admin_address, org_address, project_owner, project_id, total_budget) = 
        setup_project_with_milestones();
    
    let dispatcher = IBudgetDispatcher { contract_address };
    
    // Create additional milestones by admin
    cheat_caller_address(contract_address, admin_address, CheatSpan::Indefinite);
    
    // Create milestone 1 (400 tokens)
    let milestone1_amount: u256 = 400;
    dispatcher.create_milestone(org_address, project_id, 'Milestone 1', milestone1_amount);
    
    // Create milestone 2 (300 tokens)
    let milestone2_amount: u256 = 300;
    dispatcher.create_milestone(org_address, project_id, 'Milestone 2', milestone2_amount);
    
    stop_cheat_caller_address(admin_address);
    
    // Test that creating milestones doesn't affect remaining budget
    let remaining_budget = dispatcher.get_project_remaining_budget(project_id);
    assert(remaining_budget == total_budget, 'Creation changes budget');
}

#[test]
fn test_get_project_remaining_budget_after_fund_release() {
    // Setup project with milestones
    let (contract_address, admin_address, org_address, project_owner, project_id, total_budget) = 
        setup_project_with_milestones();
    
    let dispatcher = IBudgetDispatcher { contract_address };
    
    // Create milestone by admin (replaces the default milestone)
    cheat_caller_address(contract_address, admin_address, CheatSpan::Indefinite);
    
    // Create milestone 1 (400 tokens)
    let milestone1_amount: u256 = 400;
    let milestone1_id = dispatcher.create_milestone(org_address, project_id, 'Milestone 1', milestone1_amount);
    
    stop_cheat_caller_address(admin_address);
    
    // Mark milestone as complete
    cheat_caller_address(contract_address, project_owner, CheatSpan::Indefinite);
    dispatcher.set_milestone_complete(project_id, milestone1_id);
    stop_cheat_caller_address(project_owner);
    
    // Create fund request
    cheat_caller_address(contract_address, project_owner, CheatSpan::Indefinite);
    let request_id = dispatcher.create_fund_request(project_id, milestone1_id);
    stop_cheat_caller_address(project_owner);
    
    // Release funds for the milestone
    cheat_caller_address(contract_address, org_address, CheatSpan::Indefinite);
    dispatcher.release_funds(org_address, project_id, request_id);
    stop_cheat_caller_address(org_address);
    
    // Test that remaining budget is updated after fund release
    let remaining_budget = dispatcher.get_project_remaining_budget(project_id);
    assert(remaining_budget == total_budget - milestone1_amount, 'Budget after release wrong');
}

#[test]
fn test_get_project_remaining_budget_multiple_releases() {
    // Setup project with milestones
    let (contract_address, admin_address, org_address, project_owner, project_id, total_budget) = 
        setup_project_with_milestones();
    
    let dispatcher = IBudgetDispatcher { contract_address };
    
    // Create milestones by admin
    cheat_caller_address(contract_address, admin_address, CheatSpan::Indefinite);
    
    // Create milestone 1 (400 tokens)
    let milestone1_amount: u256 = 400;
    let milestone1_id = dispatcher.create_milestone(org_address, project_id, 'Milestone 1', milestone1_amount);
    
    // Create milestone 2 (300 tokens)
    let milestone2_amount: u256 = 300;
    let milestone2_id = dispatcher.create_milestone(org_address, project_id, 'Milestone 2', milestone2_amount);
    
    stop_cheat_caller_address(admin_address);
    
    // Process milestone 1
    // Mark milestone 1 as complete
    cheat_caller_address(contract_address, project_owner, CheatSpan::Indefinite);
    dispatcher.set_milestone_complete(project_id, milestone1_id);
    stop_cheat_caller_address(project_owner);
    
    // Create fund request for milestone 1
    cheat_caller_address(contract_address, project_owner, CheatSpan::Indefinite);
    let request1_id = dispatcher.create_fund_request(project_id, milestone1_id);
    stop_cheat_caller_address(project_owner);
    
    // Release funds for milestone 1
    cheat_caller_address(contract_address, org_address, CheatSpan::Indefinite);
    dispatcher.release_funds(org_address, project_id, request1_id);
    stop_cheat_caller_address(org_address);
    
    // Check intermediate budget
    let remaining_budget_after_first_release = dispatcher.get_project_remaining_budget(project_id);
    assert(
        remaining_budget_after_first_release == total_budget - milestone1_amount, 
        'First release budget wrong'
    );
    
    // Process milestone 2
    // Mark milestone 2 as complete
    cheat_caller_address(contract_address, project_owner, CheatSpan::Indefinite);
    dispatcher.set_milestone_complete(project_id, milestone2_id);
    stop_cheat_caller_address(project_owner);
    
    // Create fund request for milestone 2
    cheat_caller_address(contract_address, project_owner, CheatSpan::Indefinite);
    let request2_id = dispatcher.create_fund_request(project_id, milestone2_id);
    stop_cheat_caller_address(project_owner);
    
    // Release funds for milestone 2
    cheat_caller_address(contract_address, org_address, CheatSpan::Indefinite);
    dispatcher.release_funds(org_address, project_id, request2_id);
    stop_cheat_caller_address(org_address);
    
    // Test that remaining budget is updated after both fund releases
    let final_remaining_budget = dispatcher.get_project_remaining_budget(project_id);
    assert(
        final_remaining_budget == total_budget - milestone1_amount - milestone2_amount, 
        'Final budget wrong'
    );
}

#[test]
fn test_get_project_remaining_budget_zero_funding() {
    // Setup project with no budget
    let (contract_address, admin_address) = setup();
    let dispatcher = IBudgetDispatcher { contract_address };

    // Create organization
    let org_name = 'Test Org';
    let org_address = contract_address_const::<'Organization'>();
    let org_mission = 'Testing Budget Chain';

    // Create project owner
    let project_owner = contract_address_const::<'ProjectOwner'>();
    
    // Set admin as caller to create organization
    cheat_caller_address(contract_address, admin_address, CheatSpan::Indefinite);
    let org_id = dispatcher.create_organization(org_name, org_address, org_mission);
    stop_cheat_caller_address(admin_address);
    
    // Create project with zero budget
    let total_budget: u256 = 0;
    
    // Set milestone descriptions and amounts
    let mut milestone_descriptions = array!['Empty Milestone'];
    let mut milestone_amounts = array![total_budget];
    
    // Set org_address as caller to create project
    cheat_caller_address(contract_address, org_address, CheatSpan::Indefinite);
    let project_id = dispatcher.allocate_project_budget(
        org_address, 
        project_owner, 
        total_budget, 
        milestone_descriptions, 
        milestone_amounts
    );
    stop_cheat_caller_address(org_address);
    
    // Test that remaining budget is zero
    let remaining_budget = dispatcher.get_project_remaining_budget(project_id);
    assert(remaining_budget == 0, 'Zero budget incorrect');
}

#[test]
fn test_get_project_remaining_budget_full_utilization() {
    // Setup project with milestones
    let (contract_address, admin_address, org_address, project_owner, project_id, total_budget) = 
        setup_project_with_milestones();
    
    let dispatcher = IBudgetDispatcher { contract_address };
    
    // Create one milestone for the full budget
    cheat_caller_address(contract_address, admin_address, CheatSpan::Indefinite);
    let milestone_id = dispatcher.create_milestone(org_address, project_id, 'Full Budget Milestone', total_budget);
    stop_cheat_caller_address(admin_address);
    
    // Mark milestone as complete
    cheat_caller_address(contract_address, project_owner, CheatSpan::Indefinite);
    dispatcher.set_milestone_complete(project_id, milestone_id);
    stop_cheat_caller_address(project_owner);
    
    // Create fund request
    cheat_caller_address(contract_address, project_owner, CheatSpan::Indefinite);
    let request_id = dispatcher.create_fund_request(project_id, milestone_id);
    stop_cheat_caller_address(project_owner);
    
    // Release all funds
    cheat_caller_address(contract_address, org_address, CheatSpan::Indefinite);
    dispatcher.release_funds(org_address, project_id, request_id);
    stop_cheat_caller_address(org_address);
    
    // Test that remaining budget is zero after full utilization
    let remaining_budget = dispatcher.get_project_remaining_budget(project_id);
    assert(remaining_budget == 0, 'Budget utilization wrong');
}

#[test]
#[should_panic(expected: 'Invalid project ID')]
fn test_get_project_remaining_budget_invalid_project() {
    let (contract_address, _) = setup();
    let dispatcher = IBudgetDispatcher { contract_address };
    
    // Try to get remaining budget for a non-existent project
    dispatcher.get_project_remaining_budget(999);
} 