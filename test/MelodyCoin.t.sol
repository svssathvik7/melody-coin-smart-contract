// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MelodyCoin} from "../src/MelodyCoin.sol";

contract MelodyCoinTest is Test {
    MelodyCoin public coin;
    address public sathvik;
    address public invalidAddress;
    address public bob;
    function setUp() public {
        string memory _name = "MelodyCoin";
        string memory _symbol = "MLD";
        uint8 _decimals = 18;
        uint256 _initialSupply = 1e19;
        uint256 _maxCap = 1e23;
        invalidAddress = address(0);
        sathvik = address(1);
        bob = address(2);
        vm.prank(sathvik);
        coin = new MelodyCoin(_name,_symbol,_decimals,_initialSupply,_maxCap);
    }

    function test_ContractOwner() public view{
        address deployer = coin.owner_();
        assertEq(deployer,sathvik,"Error deployer storage!");
    }

    function test_TokenDetails() public view{
        string memory name = coin.name();
        string memory symbol = coin.symbol();
        uint8 decimals = coin.decimals();
        uint256 maxCap = coin.maxCap_();
        assertEq(name,"MelodyCoin","Error setting token name");
        assertEq(symbol,"MLD","Error setting token symbol");
        assertEq(decimals,18,"Error setting token decimals");
        assertEq(maxCap,1e23,"Error setting maxCap");
    }

    function test_InitialContractBalance() public view{
        address contractAddress = coin.contractAddress();
        uint256 initialBalance = coin.balanceOf(contractAddress);
        assertEq(initialBalance,1e19,"Error setting initial supply");
    }

    function test_GetAssetFromFaucet() public{
        vm.startPrank(sathvik);
        vm.warp(block.timestamp + 1 days);
        coin.getFaucetAssets();
        vm.stopPrank();
        uint256 balance = coin.balanceOf(sathvik);
        assertEq(balance,1e17,"Error fetching assets from faucet");
    }

    function test_ExcessBalanceForFaucet() public{
        vm.startPrank(bob);
        for(int i=0;i<16;i++){
            uint256 balance = coin.balanceOf(bob);
            vm.warp(block.timestamp + 1 days);
            console.log("User current balance:", balance);
            if(i==15){
                vm.expectRevert(MelodyCoin.TooHighBalance.selector);
            }
            coin.getFaucetAssets();
        }
        vm.stopPrank();
    }
}
