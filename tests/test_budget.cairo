use budgetchain_contracts::interfaces::IBudget::{IBudgetDispatcher, IBudgetDispatcherTrait};
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, stop_cheat_caller_address,
    cheat_caller_address, declare,
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
