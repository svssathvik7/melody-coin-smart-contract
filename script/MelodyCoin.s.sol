// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MelodyCoin} from "../src/MelodyCoin.sol";

contract MelodyCoinScript is Script {
    string public constant NAME = "MelodyCoin";
    string public constant SYMBOL = "MLD";
    uint8 public constant DECIMALS = 18;
    uint256 public constant INIT_SUPPLY = 1e21;
    uint256 public constant MAX_CAP = 1e40;

    function setUp() public {}

    function run() public returns (MelodyCoin) {
        uint256 privateKey = vm.envUint("DEV_PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        MelodyCoin melodyCoin = new MelodyCoin(NAME, SYMBOL, DECIMALS, INIT_SUPPLY, MAX_CAP);
        vm.stopBroadcast();
        console.log("Contract deployed at : ", address(melodyCoin));
        console.log("Contract name : ", melodyCoin.name());
        console.log("Contract symbol : ", melodyCoin.symbol());
        console.log("Contract total supply : ", melodyCoin.totalSupply());
        return melodyCoin;
    }
}
