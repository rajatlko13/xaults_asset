# AssetToken - Upgradeable Asset Tokenizer

A secure, UUPS-upgradeable ERC-20 smart contract representing a tokenized financial asset with role-based access control and upgrade capability.

## Project Overview

This project implements a complete lifecycle for a tokenized asset:
- **V1**: ERC-20 token with role-based minting and max supply cap
- **V2**: Adds pause/unpause functionality for circuit breaker capabilities
- **Deployment**: ERC1967Proxy-based deployment with full initialization
- **Testing**: Comprehensive Solidity tests validating the upgrade lifecycle
- **Scripts**: Deployment script using Foundry

## Requirements

- [Foundry](https://book.getfoundry.sh/) (forge, anvil, cast)
- Solidity ^0.8.20
- OpenZeppelin Contracts Upgradeable library

## Setup

### 1. Install Dependencies

```bash
forge install OpenZeppelin/openzeppelin-contracts-upgradeable
forge install OpenZeppelin/openzeppelin-contracts
```

### 2. Build the Project

```bash
forge build
```

### 3. Run Tests

```bash
forge test
```

For verbose output:

```bash
forge test -vvv
```

## Contract Architecture

### AssetToken (V1)

**Features:**
- ERC-20 token implementation (Upgradeable)
- UUPS proxy pattern for safe upgrades
- Role-based access control:
  - `DEFAULT_ADMIN_ROLE`: Can grant roles and upgrade
  - `MINTER_ROLE`: Can mint tokens up to max supply
- Custom error: `MaxSupplyExceeded()` when minting exceeds cap

**Key Functions:**
- `initialize(uint256 initialMaxSupply)`: Initialize the token with max supply
- `mint(address to, uint256 amount)`: Mint tokens (MINTER_ROLE only)
- `_authorizeUpgrade(address newImplementation)`: Authorize upgrade (DEFAULT_ADMIN_ROLE only)

### AssetTokenV2

**New Features:**
- Inherits all V1 functionality
- Adds `PausableUpgradeable` for circuit breaker pattern
- New role: `PAUSER_ROLE` for pause/unpause operations
- New functions:
  - `pause()`: Pause all transfers
  - `unpause()`: Resume transfers
- Overrides `_update()` to enforce pause state

## Storage Layout Safety

The upgrade from V1 to V2 is **storage-safe** because:

1. **No storage variable reordering**: V2 maintains all V1 storage variables in the same order
2. **Only new functionality added**: V2 adds `PausableUpgradeable` state, which is appended after existing storage
3. **State preservation**: All user balances, total supply, and maxSupply are preserved
4. **OpenZeppelin patterns**: Both implementations follow OpenZeppelin's upgrade-safe patterns

Storage layout remains compatible because:
- `ERC20Upgradeable`: Storage slots 0-N (unchanged)
- `AccessControlUpgradeable`: Storage slots N+1-M (unchanged)
- `UUPSUpgradeable`: No storage variables (unchanged)
- `PausableUpgradeable`: Appended storage slots M+1+ (new, safe)

## Deployment

### Local Deployment (Anvil)

1. Start a local Ethereum node:

```bash
anvil
```
2. Store PRIVATE_KEY in .env
```bash
PRIVATE_KEY=0xabc
```

3. In another terminal, deploy:

```bash
forge script script/DeployAssetToken.s.sol --rpc-url http://localhost:8545 --broadcast
```

4. Note the deployed proxy address from the output.

### Deployment Output

```
AssetToken V1 Implementation deployed at: 0x...
ERC1967Proxy deployed at: 0x...
Token Name: Asset Token
Token Symbol: ASSET
Max Supply: 1000000000000000000000000
```

## Manual CLI Interaction

Once deployed to a testnet/local node, you can interact using `cast`:

### Check Token Info

```bash
# Replace PROXY_ADDRESS with actual deployed address
PROXY_ADDRESS="0x..."

# Get token name
cast call $PROXY_ADDRESS "name()" --rpc-url http://localhost:8545

# Get total supply
cast call $PROXY_ADDRESS "totalSupply()" --rpc-url http://localhost:8545

# Get max supply
cast call $PROXY_ADDRESS "maxSupply()" --rpc-url http://localhost:8545
```

### Grant Minter Role

```bash
# Get MINTER_ROLE keccak256("MINTER_ROLE")
MINTER_ROLE="0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6"
ADMIN="0x..."
MINTER="0x..."

cast send $PROXY_ADDRESS "grantRole(bytes32,address)" $MINTER_ROLE $MINTER \
  --rpc-url http://localhost:8545 \
  --private-key 0xac...ac
```

### Mint Tokens

```bash
# Mint 100 tokens to an address
RECIPIENT="0x..."
AMOUNT="100000000000000000000"  # 100 tokens with 18 decimals

cast send $PROXY_ADDRESS "mint(address,uint256)" $RECIPIENT $AMOUNT \
  --rpc-url http://localhost:8545 \
  --private-key <MINTER_PRIVATE_KEY>
```

### Check Balance

```bash
ACCOUNT="0x..."

cast call $PROXY_ADDRESS "balanceOf(address)" $ACCOUNT --rpc-url http://localhost:8545
```

### Upgrade to V2

```bash
# Deploy V2 implementation first
IMPL_V2=$(forge create src/AssetTokenV2.sol:AssetTokenV2 \
  --rpc-url http://localhost:8545 \
  --private-key <ADMIN_PRIVATE_KEY> | grep "Deployed to:" | awk '{print $NF}')

# Execute upgrade
cast send $PROXY_ADDRESS "upgradeToAndCall(address,bytes)" $IMPL_V2 0x \
  --rpc-url http://localhost:8545 \
  --private-key <ADMIN_PRIVATE_KEY>
```

### Pause Transfers (V2 only)

```bash
# Grant PAUSER_ROLE first
PAUSER_ROLE="0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a"

cast send $PROXY_ADDRESS "grantRole(bytes32,address)" $PAUSER_ROLE $PAUSER \
  --rpc-url http://localhost:8545 \
  --private-key <ADMIN_PRIVATE_KEY>

# Pause transfers
cast send $PROXY_ADDRESS "pause()" \
  --rpc-url http://localhost:8545 \
  --private-key <PAUSER_PRIVATE_KEY>
```

## Test Suite

The test suite (`test/AssetToken.t.sol`) validates the entire upgrade lifecycle:

### Test Cases

1. **test_Setup_DeployV1ViaProxy**: Verifies V1 deployment via ERC1967Proxy
2. **test_StateCheck_MintAndVerifyBalance**: Mints 100 tokens and verifies balance
3. **test_Minting_RespectMaxSupply**: Ensures minting respects max supply cap
4. **test_Minting_OnlyMinterRole**: Validates MINTER_ROLE access control
5. **test_Upgrade_DeployV2**: Deploys and upgrades to V2
6. **test_PersistenceCheck_BalanceAfterUpgrade**: Verifies state persistence during upgrade
7. **test_NewLogicCheck_PauseFunctionality**: Tests V2 pause/unpause functionality
8. **test_FullUpgradeLifecycle**: Complete end-to-end upgrade lifecycle test

### Run Specific Test

```bash
forge test --match-test test_FullUpgradeLifecycle -vvv
```

## Security Considerations

### Storage Layout Verification

To verify storage layout is safe:

1. **No storage variables deleted**: All V1 variables maintained
2. **No reordering**: Variables appear in same order
3. **Appended-only pattern**: New functionality adds storage at the end
4. **Gap variables**: Not needed here as contracts follow standard patterns

The OpenZeppelin Upgradeable contracts are designed with storage gaps:
- `__gap[50]` is typically present in upgradeable base contracts
- This allows for future storage additions without breaking upgrades

### Access Control

- **Admin-protected operations**: Only DEFAULT_ADMIN_ROLE can grant roles and authorize upgrades
- **Role separation**: DEFAULT_ADMIN_ROLE separated from MINTER_ROLE
- **Initialization safety**: Constructor disabled (`_disableInitializers()`) to prevent implementation initialization

### Error Handling

- Custom error `MaxSupplyExceeded()` for clear failure reasons
- Reverts on unauthorized role access (standard AccessControl behavior)
- Pause mechanism for emergency halting of transfers

## Compilation

```bash
forge build
```

The build output includes:
- Compiled bytecode
- ABI files
- All dependency contracts

## Directory Structure

```
├── src/
│   ├── AssetToken.sol       # V1 implementation
│   └── AssetTokenV2.sol     # V2 implementation
├── script/
│   └── DeployAssetToken.s.sol   # Deployment script
├── test/
│   └── AssetToken.t.sol     # Test suite
├── foundry.toml             # Foundry configuration
└── README.md               # This file
```

## Notes

- All contracts use Solidity ^0.8.20
- Dependencies are from OpenZeppelin Contracts Upgradeable (v5+)
- The project uses Foundry for testing and scripting
- Gas optimization prioritizes security and clarity
- No external calls to untrusted contracts

## Support

For issues or questions, refer to:
- [OpenZeppelin Upgradeable Contracts](https://docs.openzeppelin.com/contracts/5.x/upgradeable)
- [Foundry Documentation](https://book.getfoundry.sh/)
- [UUPS Pattern](https://docs.openzeppelin.com/contracts/5.x/api/proxy#UUPSUpgradeable)
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
