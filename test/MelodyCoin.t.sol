// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MelodyCoin} from "../src/MelodyCoin.sol";

contract MelodyCoinTest is Test {
    MelodyCoin public coin;

    function setUp() public {
        string memory _name = "MelodyCoin";
        string memory _symbol = "MLD";
        uint8 _decimals = 18;
        uint256 _initialSupply = 10;
        uint256 _maxCap = 100000;
        coin = new MelodyCoin(_name,_symbol,_decimals,_initialSupply,_maxCap);
    }
    
    function test_InitialSupplyIsTen() public view {
        uint256 totalSupply = coin.totalSupply();
        uint256 expectedTotalSupply = 10000000000000000000;
        assert(totalSupply==expectedTotalSupply);
    }
}
