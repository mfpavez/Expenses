# Family Expenses App Documentation

## Overview
This Flutter application is designed to track family expenses, manage budgets, and calculate balances between two users (Manuel and Tamara). It visualizes spending trends, compares actual spending against budgets, and facilitates settling debts through a "payout" mechanism.

## Technical Stack
- **Framework:** Flutter (Material 3 Design)
- **Language:** Dart
- **Navigation:** `go_router`
- **Charting:** `fl_chart`
- **Networking:** `http`
- **State Management:** `setState` (Local state), `AutomaticKeepAliveClientMixin` for preserving tab state.
- **Backend:** n8n Webhooks (Custom API)

## Project Structure

### Entry Point
- **`lib/main.dart`**: Sets up the `MaterialApp`, configures the global theme (using `ThemeService`), and defines the router (`GoRouter`).

### Main Screens
- **`lib/main_screen.dart`**: Implements the `Scaffold` with a `PageView` and a custom bottom navigation bar (using `IconButton`s in the `AppBar`). It manages the navigation between the three core pages:
    1.  **Home Page**: Current month expenses.
    2.  **Balance Page**: Historical trends and net balance.
    3.  **Budget Page**: Budget configuration and savings analysis.

### Core Pages & Features

#### 1. Home Page (`lib/home_page.dart`)
- **Purpose**: Displays the current month's financial activity.
- **Features**:
    - **Summary Cards**: Total expenses and split by payer (Manuel/Tamara).
    - **Category Summary**: Bar chart showing spending distribution by category.
    - **Expense List**: List of individual expenses with swipe-to-edit/delete functionality (`flutter_slidable`).
    - **Budget vs Actual**: Bar chart comparing spending against the budget for each category.
    - **Filtering**: Filter expenses by specific categories.
    - **Add Expense**: Floating action button to open `AddExpensePage`.
- **Logic**: Fetches current month's expenses and budget. Handles "X2" logic (payouts) to exclude them from standard totals.

#### 2. Balance Page (`lib/balance_page.dart`)
- **Purpose**: Long-term analysis and debt settlement.
- **Features**:
    - **Unified Balance Card**: Calculates who owes whom based on total spending and payouts.
    - **Payout Action**: Allows registering a payout ("X2" expense) to reset the balance.
    - **Monthly Summaries**: Shows totals for the current month and the previous two months.
    - **Historical Trend Chart (`LineChart`)**:
        - **Primary Line**: Total expenses over the last 13 months.
        - **Budget Line**: Dashed orange line showing the historical budget for context.
    - **Filtering**: The chart and totals update based on the selected category filter.

#### 3. Budget Config Page (`lib/budget_config_page.dart`)
- **Purpose**: Manage monthly budgets and view annual performance.
- **Features**:
    - **Annual Performance**: Displays Year-to-Date (YTD) budget and savings.
    - **Monthly Details**: Allows selecting a specific month to view/edit budgets.
    - **Edit Budget**: Interface to update the budget cap for specific categories.
    - **Visual Indicators**: Progress bars and text colors indicate if spending is over budget.

### Services

#### `lib/services/expense_service.dart`
- **Responsibility**: Handles all communication with the backend (n8n webhooks).
- **Key Methods**:
    - `fetchExpenses(month)`: Gets expenses for a specific month.
    - `fetchAllExpenses()`: Gets the entire history of expenses.
    - `fetchBudget(month)`: Gets budget configuration (cached mechanism).
    - `updateBudget()`: Updates budget targets.
    - `addExpense`, `updateExpense`, `removeExpense`: CRUD operations.
- **Caching**: Implements a time-based caching mechanism (5 minutes) to reduce network calls.
- **Endpoints**:
    - Get Expenses: `.../webhook/gastos`
    - Add Expense: `.../webhook/add-expense`
    - Remove Expense: `.../webhook/remove-expense`
    - Update Expense: `.../webhook/update-expense-category`
    - Get Budget: `.../webhook/get-budget`
    - Update Budget: `.../webhook/modify-budget`

#### `lib/services/theme_service.dart`
- **Responsibility**: Manages the application's color theme using a seed color.

### Data Models (`lib/models/`)
- **`Expense`**: Represents a single transaction. Includes `item`, `category`, `amount`, `date`, `paidBy`, `rowNumber` (for updates), and `isX2` status.
- **`Category`**: Enum defining available expense categories with associated colors.

### Utilities
- **`lib/utils/month_utils.dart`**: Helper functions for handling month names in Spanish (formatting, normalizing).

## Key Concepts

### "X2" Expenses / Payouts
- **Concept**: To settle debts without deleting expense history, a special "Payout" expense is created.
- **Identifier**: Expense items ending in "X2" (case-insensitive) or categorized as 'PAYOUT'.
- **Logic**: These are excluded from standard spending totals (`_getNonX2Expenses`) but are used in the net balance calculation in `BalancePage`.

### Caching
- The `ExpenseService` stores responses in memory maps (`_cachedExpenses`, `_allBudgetsCache`) with timestamps.
- `refreshCache: true` is passed to force a network reload (e.g., after adding/editing an expense).

## Build Instructions
1.  **Run**: `flutter run`
2.  **Build Android Release**: `flutter run -d <device_id> --release`
3.  **Code Generation** (if needed for JSON): `dart run build_runner build` (currently manual JSON parsing is used).

## Future Considerations
- **Error Handling**: The `ClientException` during heavy loads suggests needing retry logic or better timeout handling in `ExpenseService`.
- **State Management**: As the app grows, moving from `setState` to `Provider` or `Riverpod` might be beneficial for sharing data between screens more efficiently.
