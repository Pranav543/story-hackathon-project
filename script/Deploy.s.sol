// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Script, console } from "forge-std/Script.sol";
import { IPCollateralLending } from "../src/IPCollateralLending.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Story Protocol contract addresses (testnet)
        address ipAssetRegistry = 0x77319B4031e6eF1250907aa00018B8B1c67a244b;
        address licenseRegistry = 0x529a750E02d8E2f15649c13D69a465286a780e24;
        address licensingModule = 0x04fbd8a2e56dd85CFD5500A4A4DfA955B9f1dE6f;
        address royaltyModule = 0xD2f60c40fEbccf6311f8B47c4f2Ec6b040400086;
        address pilTemplate = 0x2E896b0b2Fdb7457499B56AAaA4AE55BCB4Cd316;

        console.log("Deploying IPCollateralLending...");
        
        IPCollateralLending lendingProtocol = new IPCollateralLending(
            ipAssetRegistry,
            licenseRegistry,
            licensingModule,
            royaltyModule,
            pilTemplate
        );

        console.log("IPCollateralLending deployed at:", address(lendingProtocol));
        
        // Setup supported tokens
        console.log("Setting up supported tokens...");
        lendingProtocol.setSupportedToken(0xF2104833d386a2734a4eB3B8ad6FC6812F29E38E, true); // USDC
        
        console.log("Deployment completed successfully!");
        console.log("Contract Address:", address(lendingProtocol));
        console.log("Owner:", lendingProtocol.owner());

        vm.stopBroadcast();
    }
}
