use budgetchain_contracts::interfaces::IBudget::{IBudgetDispatcher, IBudgetDispatcherTrait};
use budgetchain_contracts::budgetchain::Budget;
use budgetchain_contracts::base::types::{FundRequest, FundRequestStatus, Transaction};
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

#[test]
fn test_create_organization() {
    let (contract_address, admin_address) = setup();

    let dispatcher = IBudgetDispatcher { contract_address };

    let name = 'John';
    let org_address = contract_address_const::<'Organization 1'>();
    let mission = 'Help the Poor';

    cheat_caller_address(contract_address, admin_address, CheatSpan::Indefinite);
    let org0_id = dispatcher.create_organization(name, org_address, mission);
    stop_cheat_caller_address(admin_address);
    println!("Organization id: {}", org0_id);

    assert(org0_id == 0, '1st Org ID is 0');
}
#[test]
#[should_panic(expected: 'ONLY ADMIN')]
fn test_create_organization_with_not_admin() {
    let (contract_address, admin_address) = setup();

    let dispatcher = IBudgetDispatcher { contract_address };

    let not_admin = contract_address_const::<'not_admin'>();

    let name = 'John';
    let org_address = contract_address_const::<'Organization 1'>();
    let mission = 'Help the Poor';

    cheat_caller_address(contract_address, not_admin, CheatSpan::Indefinite);
    let org0_id = dispatcher.create_organization(name, org_address, mission);
    stop_cheat_caller_address(not_admin);
    println!("Organization id: {}", org0_id);

    assert(org0_id == 0, '1st Org ID is 0');
}

#[test]
fn test_create_organization_fields_are_populated_properly() {
    let (contract_address, admin_address) = setup();

    let dispatcher = IBudgetDispatcher { contract_address };

    let name = 'John';
    let org_address = contract_address_const::<'Organization 1'>();
    let mission = 'Help the Poor';

    cheat_caller_address(contract_address, admin_address, CheatSpan::Indefinite);
    let org0_id = dispatcher.create_organization(name, org_address, mission);
    stop_cheat_caller_address(admin_address);

    let organization = dispatcher.get_organization(org0_id);
    assert(organization.name == name, 'wrong name');
    assert(organization.address == org_address, 'wrong org_address');
    assert(organization.mission == mission, ' wrong mission');
    assert(organization.is_active, 'Not active');
}

#[test]
fn test_create_two_organization() {
    let (contract_address, admin_address) = setup();

    let dispatcher = IBudgetDispatcher { contract_address };

    let name = 'John';
    let org_address = contract_address_const::<'Organization 1'>();
    let mission = 'Help the Poor';

    let name1 = 'Emmanuel';
    let org_address1 = contract_address_const::<'Organization 2'>();
    let mission1 = 'Build a Church';

    cheat_caller_address(contract_address, admin_address, CheatSpan::Indefinite);
    let org0_id = dispatcher.create_organization(name, org_address, mission);
    stop_cheat_caller_address(admin_address);
    println!("Organization id: {}", org0_id);

    let org1_id = dispatcher.create_organization(name1, org_address1, mission1);
    stop_cheat_caller_address(admin_address);
    println!("Organization 1 id: {}", org1_id);

    assert(org1_id == 1, '1st Org ID is 0');
    let organization1 = dispatcher.get_organization(org1_id);
    assert(organization1.name == name1, 'wrong name');
    assert(organization1.address == org_address1, 'wrong org_address');
    assert(organization1.mission == mission1, ' wrong mission');
    assert(organization1.is_active, 'Not active');
    println!("name: {}", name1);
}

#[test]
fn test_create_milestone_successfully() {
    let (contract_address, admin_address) = setup();

    let dispatcher = IBudgetDispatcher { contract_address };

    let name = 'John';
    let org_address = contract_address_const::<'Organization 1'>();
    let mission = 'Help the Poor';

    cheat_caller_address(contract_address, admin_address, CheatSpan::Indefinite);
    let org0_id = dispatcher.create_organization(name, org_address, mission);
    dispatcher.create_milestone(org_address, 12, 'Feed Dogs in Lekki', 2);
    stop_cheat_caller_address(admin_address);
}

#[test]
fn test_create_multiple_milestone_successfully() {
    let (contract_address, admin_address) = setup();

    let dispatcher = IBudgetDispatcher { contract_address };

    let name = 'John';
    let org_address = contract_address_const::<'Organization 1'>();
    let mission = 'Help the Poor';

    cheat_caller_address(contract_address, admin_address, CheatSpan::Indefinite);
    let org0_id = dispatcher.create_organization(name, org_address, mission);
    dispatcher.create_milestone(org_address, 12, 'Feed Dogs in Lekki', 2);
    dispatcher.create_milestone(org_address, 18, 'Feed Dogs in Kubwa', 20);
    stop_cheat_caller_address(admin_address);
}

#[test]
#[should_panic(expected: 'ONLY ADMIN')]
fn test_create_milestone_should_panic_if_not_organization() {
    let (contract_address, _) = setup();

    let dispatcher = IBudgetDispatcher { contract_address };

    let not_admin = contract_address_const::<'not_admin'>();

    let name = 'John';
    let org_address = contract_address_const::<'Organization 1'>();
    let mission = 'Help the Poor';

    cheat_caller_address(contract_address, not_admin, CheatSpan::Indefinite);
    let org0_id = dispatcher.create_organization(name, org_address, mission);
    dispatcher.create_milestone(org_address, 12, 'Feed Dogs in Lekki', 2);
    stop_cheat_caller_address(not_admin);
    println!("Organization id: {}", org0_id);

    assert(org0_id == 0, '1st Org ID is 0');
}

#[test]
fn test_create_milestone_data_saved() {
    let (contract_address, admin_address) = setup();

    let dispatcher = IBudgetDispatcher { contract_address };

    let name = 'John';
    let org_address = contract_address_const::<'Organization 1'>();
    let mission = 'Help the Poor';
    let project_id = 12;
    let milestone_description = 'Feed Dogs in Lekki';
    let milestone_amount = 2;

    cheat_caller_address(contract_address, admin_address, CheatSpan::Indefinite);
    let org0_id = dispatcher.create_organization(name, org_address, mission);
    let milestone_id = dispatcher
        .create_milestone(org_address, project_id, milestone_description, milestone_amount);
    stop_cheat_caller_address(admin_address);

    let first_milestone = dispatcher.get_milestone(project_id, milestone_id);
    assert(milestone_id == 1, 'Milestone not saved');
    assert(first_milestone.organization == org_address, 'Org didnt create the miestone');
    assert(first_milestone.project_id == 12, 'Org project id didnt match');
    assert(
        first_milestone.milestone_description == milestone_description,
        'Org description id didnt match',
    );
    assert(first_milestone.milestone_amount == milestone_amount, 'Org amount id didnt match');
}
fn test_allocate_project_budget_success() {
    let (contract_address, admin_address) = setup();

    let org_address = contract_address_const::<'Organization'>();
    let name = 'John';
    let mission = 'Help the Poor';
    let proj_owner = contract_address_const::<'Owner'>();
    let mut spy = spy_events();

    let dispatcher = IBudgetDispatcher { contract_address };

    cheat_caller_address(contract_address, admin_address, CheatSpan::Indefinite);
    dispatcher.create_organization(name, org_address, mission);
    stop_cheat_caller_address(admin_address);

    cheat_caller_address(contract_address, org_address, CheatSpan::Indefinite);
    let project_id = dispatcher
        .allocate_project_budget(
            org_address, proj_owner, 100, array!['Milestone1', 'Milestone2'], array![90, 10],
        );
    stop_cheat_caller_address(org_address);

    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    Budget::Budget::Event::ProjectAllocated(
                        Budget::Budget::ProjectAllocated {
                            project_id,
                            org: org_address,
                            project_owner: proj_owner,
                            total_budget: 100,
                        },
                    ),
                ),
            ],
        );
    let milestone1 = dispatcher.get_milestone(project_id, 0);
    let milestone2 = dispatcher.get_milestone(project_id, 1);
    assert(milestone1.milestone_description == 'Milestone1', 'incorrect milestone description');
    assert(milestone1.milestone_amount == 90, 'incorrect amount');
}

#[test]
#[should_panic(expected: 'Caller must be organization')]
fn test_allocate_project_budget_not_org() {
    let (contract_address, admin_address) = setup();

    let org_address = contract_address_const::<'Organization'>();
    let name = 'John';
    let mission = 'Help the Poor';
    let proj_owner = contract_address_const::<'Owner'>();

    let dispatcher = IBudgetDispatcher { contract_address };

    cheat_caller_address(contract_address, admin_address, CheatSpan::Indefinite);
    dispatcher.create_organization(name, org_address, mission);
    stop_cheat_caller_address(admin_address);

    dispatcher
        .allocate_project_budget(
            org_address, proj_owner, 100, array!['Milestone1', 'Milestone2'], array![90, 10],
        );
}

#[test]
#[should_panic(expected: 'Milestone sum != total budget')]
fn test_allocate_project_budget_total_budget_mismatch() {
    let (contract_address, admin_address) = setup();

    let org_address = contract_address_const::<'Organization'>();
    let name = 'John';
    let mission = 'Help the Poor';
    let proj_owner = contract_address_const::<'Owner'>();

    let dispatcher = IBudgetDispatcher { contract_address };

    cheat_caller_address(contract_address, admin_address, CheatSpan::Indefinite);
    dispatcher.create_organization(name, org_address, mission);
    stop_cheat_caller_address(admin_address);

    cheat_caller_address(contract_address, org_address, CheatSpan::Indefinite);
    dispatcher
        .allocate_project_budget(
            org_address, proj_owner, 100, array!['Milestone1', 'Milestone2'], array![90, 100],
        );
    stop_cheat_caller_address(org_address);
}

#[test]
#[should_panic(expected: 'Array lengths mismatch')]
fn test_allocate_project_budget_array_mismatch() {
    let (contract_address, admin_address) = setup();

    let org_address = contract_address_const::<'Organization'>();
    let name = 'John';
    let mission = 'Help the Poor';
    let proj_owner = contract_address_const::<'Owner'>();

    let dispatcher = IBudgetDispatcher { contract_address };

    cheat_caller_address(contract_address, admin_address, CheatSpan::Indefinite);
    dispatcher.create_organization(name, org_address, mission);
    stop_cheat_caller_address(admin_address);

    cheat_caller_address(contract_address, org_address, CheatSpan::Indefinite);
    dispatcher
        .allocate_project_budget(
            org_address, proj_owner, 100, array!['Milestone1', 'Milestone2'], array![90, 5, 5],
        );
    stop_cheat_caller_address(org_address);
}

#[test]
#[should_panic(expected: 'Caller not authorized')]
fn test_allocate_project_budget_not_authorized() {
    let (contract_address, _) = setup();

    let org_address = contract_address_const::<'Organization'>();
    let proj_owner = contract_address_const::<'Owner'>();

    let dispatcher = IBudgetDispatcher { contract_address };

    dispatcher
        .allocate_project_budget(
            org_address, proj_owner, 100, array!['Milestone1', 'Milestone2'], array![90, 10],
        );
}

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
    assert_eq!(get_transaction_count, 0);

    let get_fund_request_counter = dispatcher.get_fund_requests_counter();
    assert_eq!(get_fund_request_counter, 1);
}
