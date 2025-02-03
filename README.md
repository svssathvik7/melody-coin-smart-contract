# MelodyCoin (MLD)

## Introduction

MelodyCoin is an ERC20-compatible token with built-in tokenomics features including:

- Automatic burn mechanism
- Reserve accumulation system
- Faucet distribution for new users
- Front-running protection
- Pausable operations

## Tokenomics

### Core Parameters

- **Reserve Rate**: 20% (2/10)

  - Applied on mints and transfers
  - Accumulated in contract's reserve

- **Burn Rate**: 0.2% (2/1000)

  - Applied on every transfer
  - Permanently reduces total supply

- **Faucet System**:
  - Delivery Amount: 0.1 tokens per request
  - Maximum Balance: 1.5 tokens per user
  - Cooldown Period: 24 hours between requests

### Supply Management

- Initial Supply: Configurable at deployment
- Maximum Cap: Configurable at deployment
- Supply Control:
  - Minting: Owner only
  - Burning: Automatic on transfers
  - Reserve: Auto-accumulation

## Testing Coverage

### Unit Tests

- Contract Configuration

  - Owner assignment
  - Token details (name, symbol, decimals)
  - Initial supply and balance

- Transfer Functions

  - Standard transfers
  - Delegated transfers (transferFrom)
  - Zero address protection
  - Insufficient balance handling

- Approval System

  - Standard approvals
  - Front-running protection
  - Allowance management

- Faucet Operations
  - Rate limiting
  - Balance caps
  - Reserve depletion protection

### Fuzz Testing

- Token Deployment

  - Random parameters within bounds
  - Supply cap enforcement

- Transfer Operations
  - Random amounts and addresses
  - Edge case handling
  - Balance consistency

## Security Features

### Access Control

- Owner-restricted functions
  - Minting
  - Pause/Unpause

### Protection Mechanisms

- Front-running protection on approvals
- Reentrancy guards through checks-effects-interactions
- Arithmetic overflow protection (Solidity ^0.8.19)
- ETH transfer rejection

### Emergency Controls

- Pause mechanism for all operations
- Reserve accumulation for sustainability

## Development

### Prerequisites

- Foundry toolkit
- Solidity ^0.8.19

### Quick Start

```bash
# Clone repository
git clone https://github.com/svssathvik7/melody-coin-smart-contract.git

# Install dependencies
forge install

# Run tests
forge test

# Run specific test suite
forge test --match-contract MelodyCoinTest

# Find test coverage reports
forge coverage --skip script
```
