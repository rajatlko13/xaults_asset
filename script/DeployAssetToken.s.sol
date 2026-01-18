// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {AssetToken} from "../src/AssetToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {console} from "forge-std/console.sol";

contract DeployAssetToken is Script {
    uint256 public constant MAX_SUPPLY = 1_000_000 * 10 ** 18; // 1M tokens

    function run() public {
        // Get deployment private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcast
        vm.startBroadcast(deployerPrivateKey);

        // Deploy V1 implementation
        AssetToken assetTokenImpl = new AssetToken();
        console.log("AssetToken V1 Implementation deployed at:", address(assetTokenImpl));

        // Encode initialization call
        bytes memory initData = abi.encodeCall(
            AssetToken.initialize,
            (MAX_SUPPLY)
        );

        // Deploy ERC1967Proxy
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(assetTokenImpl),
            initData
        );
        console.log("ERC1967Proxy deployed at:", address(proxy));

        // Cast proxy to AssetToken for logging
        AssetToken proxyAsToken = AssetToken(address(proxy));

        // Log initialization details
        console.log("Token Name:", proxyAsToken.name());
        console.log("Token Symbol:", proxyAsToken.symbol());
        console.log("Max Supply:", proxyAsToken.maxSupply());
        console.log("Deployer address:", vm.addr(deployerPrivateKey));

        vm.stopBroadcast();

        console.log("\n=== Deployment Summary ===");
        console.log("Implementation:", address(assetTokenImpl));
        console.log("Proxy:", address(proxy));
        console.log("Max Supply:", MAX_SUPPLY);
    }
}
