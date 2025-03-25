#[cfg(test)]
mod tests {
    use super::Budget::BudgetImpl;
    use starknet::testing::State;
    use starknet::ContractAddress;
    use starknet::felt252;
    use budgetchain_contracts::base::types::{Project, Transaction, FundRequest, Milestone};

    #[test]
    fn test_allocate_project_budget() {
        let mut state = State::new();
        let admin = ContractAddress::from_felt252(0x1);
        let org = ContractAddress::from_felt252(0x2);
        let project_owner = ContractAddress::from_felt252(0x3);

        let budget_contract = BudgetImpl::deploy(&mut state, admin);

        let milestone_descriptions = ["Design Phase".into(), "Development Phase".into()];
        let milestone_amounts = [1000.into(), 2000.into()];

        let project_id = budget_contract
            .allocate_project_budget(org, project_owner, 3000.into(), milestone_descriptions, milestone_amounts)
            .unwrap();

        let remaining_budget = budget_contract.get_project_remaining_budget(project_id);
        assert_eq!(remaining_budget, 3000.into());
    }

    #[test]
    fn test_fund_request_creation() {
        let mut state = State::new();
        let admin = ContractAddress::from_felt252(0x1);
        let budget_contract = BudgetImpl::deploy(&mut state, admin);

        let fund_request = FundRequest {
            project_id: 1,
            request_id: 1,
            amount: 500.into(),
            reason: "Equipment purchase".into(),
            approved: false,
        };

        budget_contract.set_fund_requests(fund_request, 1);

        let stored_requests = budget_contract.get_fund_requests(1);
        assert_eq!(stored_requests.len(), 1);
        assert_eq!(stored_requests[0].amount, 500.into());
    }

    #[test]
    fn test_fund_transfer_between_budgets() {
        let mut state = State::new();
        let admin = ContractAddress::from_felt252(0x1);
        let budget_contract = BudgetImpl::deploy(&mut state, admin);

        let org = ContractAddress::from_felt252(0x2);
        let project_owner = ContractAddress::from_felt252(0x3);

        let milestone_descriptions = ["Phase 1".into(), "Phase 2".into()];
        let milestone_amounts = [2000.into(), 3000.into()];

        let project_id = budget_contract
            .allocate_project_budget(org, project_owner, 5000.into(), milestone_descriptions, milestone_amounts)
            .unwrap();

        let initial_budget = budget_contract.get_project_remaining_budget(project_id);
        assert_eq!(initial_budget, 5000.into());

        // Transfer 1000 from Phase 1 to Phase 2
        budget_contract.transfer_funds(project_id, 2000.into(), 3000.into(), 1000.into());

        let updated_budget = budget_contract.get_project_remaining_budget(project_id);
        assert_eq!(updated_budget, 5000.into()); // Total remains the same

        let phase1_budget = budget_contract.get_project_remaining_budget(2000.into());
        let phase2_budget = budget_contract.get_project_remaining_budget(3000.into());
        assert_eq!(phase1_budget, 1000.into()); // Reduced
        assert_eq!(phase2_budget, 4000.into()); // Increased
    }

    #[test]
    fn test_unauthorized_budget_allocation() {
        let mut state = State::new();
        let admin = ContractAddress::from_felt252(0x1);
        let unauthorized_user = ContractAddress::from_felt252(0x4);
        let budget_contract = BudgetImpl::deploy(&mut state, admin);

        let milestone_descriptions = ["Phase 1".into()];
        let milestone_amounts = [1000.into()];

        let result = budget_contract.allocate_project_budget(
            unauthorized_user,
            unauthorized_user,
            1000.into(),
            milestone_descriptions,
            milestone_amounts,
        );

        assert!(result.is_err()); // Should fail because the user is unauthorized
    }
}
