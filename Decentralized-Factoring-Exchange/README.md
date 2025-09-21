# Decentralized Factoring Exchange

A smart contract marketplace for trading business receivables on the Stacks blockchain, enabling businesses to factor their invoices and accounts receivable in a decentralized manner.

## Overview

The Decentralized Factoring Exchange allows businesses to:
- List their receivables (invoices/accounts receivable) for sale at a discount
- Purchase receivables from other businesses for immediate cash flow
- Manage the entire factoring lifecycle on-chain with built-in escrow protection

## Features

### Core Functionality
- **Receivable Creation**: Businesses can list their receivables with customizable discount rates
- **Marketplace Trading**: Buyers can purchase receivables at discounted prices
- **Escrow Protection**: Built-in escrow system protects both buyers and sellers
- **Payment Tracking**: Automated tracking of receivable payments and defaults
- **User Profiles**: Reputation system based on trading history

### Security Features
- **Access Control**: Role-based permissions for different operations
- **Validation**: Comprehensive input validation and business logic checks
- **Expiration Handling**: Automatic handling of expired receivables
- **Default Management**: Built-in default detection and management

## Contract Structure

### Data Models

#### Receivables
```clarity
{
  seller: principal,           // Business selling the receivable
  debtor: principal,          // Customer who owes the money
  face-value: uint,           // Original invoice amount
  discount-rate: uint,        // Discount rate in basis points
  discounted-price: uint,     // Price after discount
  due-date: uint,            // When payment is due
  description: string,        // Invoice description
  status: uint,              // Current status
  created-at: uint,          // Creation timestamp
  buyer: optional principal,  // Who purchased it
  purchased-at: optional uint // Purchase timestamp
}
```

#### User Profiles
```clarity
{
  total-sold: uint,          // Total amount sold
  total-purchased: uint,     // Total amount purchased
  reputation-score: uint,    // Reputation rating
  verified: bool            // Verification status
}
```

### Status Types
- `status-active` (1): Available for purchase
- `status-sold` (2): Purchased, awaiting payment
- `status-paid` (3): Successfully paid by debtor
- `status-defaulted` (4): Payment defaulted
- `status-cancelled` (5): Cancelled by seller

## Usage Examples

### Creating a Receivable
```clarity
(contract-call? .factoring-exchange create-receivable
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7  ;; debtor
  u10000                                          ;; $100.00 face value
  u500                                           ;; 5% discount rate
  u1000150                                       ;; due date (block height)
  "Invoice #12345 - Web Development Services"    ;; description
)
```

### Purchasing a Receivable
```clarity
(contract-call? .factoring-exchange purchase-receivable u1)
```

### Marking as Paid (by debtor)
```clarity
(contract-call? .factoring-exchange mark-as-paid u1)
```

## Configuration

### Platform Settings
- **Platform Fee**: 2.5% (250 basis points) - configurable by owner
- **Minimum Discount**: 1% (100 basis points)
- **Maximum Discount**: 30% (3000 basis points)

### Discount Rate Calculation
The discounted price is calculated as:
```
Discounted Price = Face Value - (Face Value × Discount Rate / 10000)
```

## Read-Only Functions

### Query Functions
- `get-receivable(receivable-id)`: Get receivable details
- `get-user-profile(user)`: Get user profile and stats
- `get-platform-fee-rate()`: Get current platform fee rate
- `calculate-discounted-price(face-value, discount-rate)`: Calculate discounted price
- `is-receivable-expired(receivable-id)`: Check if receivable is expired

## Public Functions

### Trading Functions
- `create-receivable()`: List a new receivable for sale
- `purchase-receivable()`: Buy a receivable at discounted price
- `mark-as-paid()`: Mark receivable as paid (debtor only)
- `cancel-receivable()`: Cancel active receivable (seller only)
- `mark-as-defaulted()`: Mark as defaulted after due date (buyer only)

### Admin Functions
- `set-platform-fee-rate()`: Update platform fee (owner only)
- `set-discount-rate-limits()`: Update discount rate limits (owner only)
- `verify-user()`: Verify user account (owner only)
- `withdraw-fees()`: Withdraw platform fees (owner only)

## Error Codes

- `u100`: Owner only operation
- `u101`: Receivable not found
- `u102`: Unauthorized operation
- `u103`: Invalid amount
- `u104`: Invalid status
- `u105`: Insufficient funds
- `u106`: Already exists
- `u107`: Expired
- `u108`: Invalid discount rate

## Security Considerations

### Access Control
- Only receivable sellers can cancel their listings
- Only debtors can mark receivables as paid
- Only buyers can mark receivables as defaulted (after due date)
- Only contract owner can modify platform settings

### Validation
- All amounts must be positive
- Discount rates must be within configured limits
- Due dates must be in the future
- Status transitions are strictly controlled

### Escrow Protection
- Funds are held in escrow during the transaction lifecycle
- Automatic release mechanisms protect both parties
- Platform fees are collected transparently

## Deployment

1. Deploy the contract to Stacks blockchain
2. Configure platform fee rate and discount limits
3. Set up user verification process
4. Initialize marketplace operations

## Testing

Key test scenarios:
- Receivable creation with various parameters
- Purchase flow with escrow handling
- Payment completion and fund release
- Default handling after due dates
- Admin function access control
- Edge cases and error conditions

## Future Enhancements

- Multi-token support (beyond STX)
- Automated payment reminders
- Advanced reputation algorithms
- Insurance integration
- Bulk receivable operations
- API integration for external systems

## License

This smart contract is provided as-is for educational and commercial use. Please ensure compliance with local regulations regarding factoring and financial services.

## Support

For technical support or questions about the Decentralized Factoring Exchange, please refer to the Stacks documentation or community forums.