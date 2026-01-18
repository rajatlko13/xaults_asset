// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {AssetToken} from "../src/AssetToken.sol";
import {AssetTokenV2} from "../src/AssetTokenV2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract AssetTokenUpgradeTest is Test {
    AssetToken public assetTokenV1;
    AssetTokenV2 public assetTokenV2;
    ERC1967Proxy public proxy;

    address public admin = address(0xABCD);
    address public minter = address(0xBCDE);
    address public user = address(0xCDEF);

    uint256 public constant MAX_SUPPLY = 1_000_000 * 10 ** 18; // 1M tokens

    event Minted(address indexed to, uint256 amount);

    function setUp() public {
        // Deploy V1 implementation
        assetTokenV1 = new AssetToken();

        // Encode the initialize call
        bytes memory initData = abi.encodeCall(AssetToken.initialize, (MAX_SUPPLY));

        // Deploy ERC1967Proxy pointing to V1
        proxy = new ERC1967Proxy(address(assetTokenV1), initData);

        // Cast proxy to AssetToken interface
        assetTokenV1 = AssetToken(address(proxy));

        // Grant roles to admin (since initialize() granted to address(this), the test contract)
        // We need to transfer admin role to our admin variable
        assetTokenV1.grantRole(assetTokenV1.DEFAULT_ADMIN_ROLE(), admin);

        // Grant MINTER_ROLE to minter
        assetTokenV1.grantRole(assetTokenV1.MINTER_ROLE(), minter);
    }

    function test_Setup_DeployV1ViaProxy() public {
        // Assert proxy is deployed
        assertEq(address(proxy), address(assetTokenV1));

        // Assert max supply is set
        assertEq(assetTokenV1.maxSupply(), MAX_SUPPLY);

        // Assert name and symbol
        assertEq(assetTokenV1.name(), "Asset Token");
        assertEq(assetTokenV1.symbol(), "ASSET");
    }

    function test_StateCheck_MintAndVerifyBalance() public {
        // Mint 100 tokens to user
        uint256 mintAmount = 100 * 10 ** 18;

        vm.prank(minter);
        assetTokenV1.mint(user, mintAmount);

        // Assert balance is 100
        assertEq(assetTokenV1.balanceOf(user), mintAmount);

        // Assert total supply
        assertEq(assetTokenV1.totalSupply(), mintAmount);
    }

    function test_Minting_RespectMaxSupply() public {
        uint256 mintAmount = MAX_SUPPLY + 1;

        vm.prank(minter);
        vm.expectRevert(AssetToken.MaxSupplyExceeded.selector);
        assetTokenV1.mint(user, mintAmount);
    }

    function test_Minting_OnlyMinterRole() public {
        uint256 mintAmount = 100 * 10 ** 18;

        vm.prank(user);
        vm.expectRevert();
        assetTokenV1.mint(user, mintAmount);
    }

    function test_Upgrade_DeployV2() public {
        // First, mint some tokens to user on V1
        uint256 mintAmount = 100 * 10 ** 18;
        vm.prank(minter);
        assetTokenV1.mint(user, mintAmount);

        // Deploy V2 implementation
        assetTokenV2 = new AssetTokenV2();

        // Upgrade proxy to V2
        vm.prank(admin);
        AssetToken(address(proxy)).upgradeToAndCall(
            address(assetTokenV2),
            new bytes(0)
        );

        // Cast proxy to AssetTokenV2 interface
        assetTokenV2 = AssetTokenV2(address(proxy));
    }

    function test_PersistenceCheck_BalanceAfterUpgrade() public {
        // Mint 100 tokens on V1
        uint256 mintAmount = 100 * 10 ** 18;
        vm.prank(minter);
        assetTokenV1.mint(user, mintAmount);

        // Record balance before upgrade
        uint256 balanceBefore = assetTokenV1.balanceOf(user);

        // Deploy and execute upgrade to V2
        assetTokenV2 = new AssetTokenV2();
        vm.prank(admin);
        AssetToken(address(proxy)).upgradeToAndCall(
            address(assetTokenV2),
            new bytes(0)
        );

        // Cast to V2
        assetTokenV2 = AssetTokenV2(address(proxy));

        // Assert balance is persisted
        uint256 balanceAfter = assetTokenV2.balanceOf(user);
        assertEq(balanceBefore, balanceAfter);
        assertEq(balanceAfter, mintAmount);
    }

    function test_NewLogicCheck_PauseFunctionality() public {
        // Mint 100 tokens on V1
        uint256 mintAmount = 100 * 10 ** 18;
        vm.prank(minter);
        assetTokenV1.mint(user, mintAmount);

        // Upgrade to V2
        assetTokenV2 = new AssetTokenV2();
        vm.prank(admin);
        AssetToken(address(proxy)).upgradeToAndCall(
            address(assetTokenV2),
            new bytes(0)
        );

        // Cast to V2
        assetTokenV2 = AssetTokenV2(address(proxy));

        // Grant PAUSER_ROLE to admin
        vm.prank(admin);
        assetTokenV2.grantRole(assetTokenV2.PAUSER_ROLE(), admin);

        // Pause the contract
        vm.prank(admin);
        assetTokenV2.pause();

        // Assert transfers revert when paused
        vm.prank(user);
        vm.expectRevert();
        assetTokenV2.transfer(minter, 10 * 10 ** 18);

        // Unpause and verify transfer works
        vm.prank(admin);
        assetTokenV2.unpause();

        vm.prank(user);
        assetTokenV2.transfer(minter, 10 * 10 ** 18);

        // Assert transfer succeeded
        assertEq(assetTokenV2.balanceOf(minter), 10 * 10 ** 18);
    }

    function test_FullUpgradeLifecycle() public {
        // 1. Setup: Deploy V1 via ERC1967Proxy with 1M max supply (in setUp)
        assertEq(assetTokenV1.maxSupply(), MAX_SUPPLY);

        // 2. State Check: Mint 100 tokens to user, assert balance is 100
        uint256 mintAmount = 100 * 10 ** 18;
        vm.prank(minter);
        assetTokenV1.mint(user, mintAmount);
        assertEq(assetTokenV1.balanceOf(user), mintAmount);

        // 3. Upgrade: Deploy V2 and execute upgrade
        assetTokenV2 = new AssetTokenV2();
        vm.prank(admin);
        AssetToken(address(proxy)).upgradeToAndCall(
            address(assetTokenV2),
            new bytes(0)
        );
        assetTokenV2 = AssetTokenV2(address(proxy));

        // 4. Persistence Check: Assert balance is still 100
        assertEq(assetTokenV2.balanceOf(user), mintAmount);

        // 5. New Logic Check: Call pause() and assert transfers revert
        vm.prank(admin);
        assetTokenV2.grantRole(assetTokenV2.PAUSER_ROLE(), admin);

        vm.prank(admin);
        assetTokenV2.pause();

        vm.prank(user);
        vm.expectRevert();
        assetTokenV2.transfer(minter, 10 * 10 ** 18);
    }
}
