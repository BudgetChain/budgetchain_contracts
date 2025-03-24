#[cfg(test)]
mod tests {
    use starknet::contract_address_const;
    use budgetchain_contracts::base::types::Transaction;

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
}
