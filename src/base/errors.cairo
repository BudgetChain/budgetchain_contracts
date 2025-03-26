// Access control errors
pub const ERROR_ADMIN_REQUIRED: felt252 = 'Admin role required';
pub const ERROR_CALLER_NOT_ORG: felt252 = 'Caller must be organization';
pub const ERROR_ONLY_ORGANIZATION: felt252 = 'Only organization can release';
pub const ERROR_ONLY_ADMIN: felt252 = 'ONLY ADMIN';
pub const ERROR_UNAUTHORIZED: felt252 = 'Caller not authorized';

// Validation errors
pub const ERROR_ARRAY_LENGTH_MISMATCH: felt252 = 'Array lengths mismatch';
pub const ERROR_BUDGET_MISMATCH: felt252 = 'Milestone sum != total budget';
pub const ERROR_INCOMPLETE_MILESTONE: felt252 = 'Project milestone incomplete';
pub const ERROR_INSUFFICIENT_BUDGET: felt252 = 'Insufficient budget';
pub const ERROR_INVALID_MILESTONE: felt252 = 'Invalid milestone';
pub const ERROR_INVALID_PAGE: felt252 = 'Invalid page number';
pub const ERROR_INVALID_PAGE_SIZE: felt252 = 'Invalid page size';
pub const ERROR_INVALID_PROJECT_ID: felt252 = 'Invalid project ID';
pub const ERROR_INVALID_TRANSACTION_ID: felt252 = 'Invalid transaction ID';
pub const ERROR_MILESTONE_ALREADY_COMPLETED: felt252 = 'Milestone already completed';
pub const ERROR_NO_TRANSACTIONS: felt252 = 'No transactions found';
pub const ERROR_REQUEST_NOT_PENDING: felt252 = 'Request not in Pending status';
pub const ERROR_REWARDED_MILESTONE: felt252 = 'Milestone fund already released';
pub const ERROR_ZERO_ADDRESS: felt252 = 'Zero address forbidden';
pub const ERROR_ZERO_AMOUNT: felt252 = 'Zero amount forbidden';

