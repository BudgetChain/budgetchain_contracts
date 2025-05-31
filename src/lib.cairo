// Make modules public so they can be accessed
pub mod base {
    pub mod errors;
    pub mod types;
}

pub mod interfaces {
    pub mod IBudget;
    pub mod IMilestoneManager;
}

pub mod budgetchain {
    pub mod Budget;
    pub mod MilestoneManager;
}

// Re-export the main modules for easier access
pub use budgetchain::Budget;
pub use budgetchain::MilestoneManager;
pub use interfaces::IBudget;
pub use interfaces::IMilestoneManager;
