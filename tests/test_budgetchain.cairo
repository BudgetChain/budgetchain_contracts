use budgetchain_contracts::interfaces::ibudget::{IBudgetDispatcher, IBudgetDispatcherTrait};

use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
use starknet::{ContractAddress, get_block_timestamp};


fn owner() -> ContractAddress {
    'owner'.try_into().unwrap()
}
fn deploy_budget() -> IBudgetDispatcher {
    let contract_class = declare("budget").unwrap().contract_class();

    let (contract_address, _) = contract_class.deploy(@array![].into()).unwrap();
    (IBudgetDispatcher { contract_address })
}


#[test]
fn test_create_pool() {
    let contract = deploy_budget();
}