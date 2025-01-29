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
        coin = new MelodyCoin(_name, _symbol, _decimals, _initialSupply, _maxCap);
    }

    function helper_RequestFaucetAssets(address user, uint8 times) internal {
        vm.startPrank(user);
        for (uint8 i = 0; i < times; i++) {
            vm.warp(block.timestamp + 1 days);
            coin.getFaucetAssets();
        }
        vm.stopPrank();
    }

    // tests for contract configs
    function test_ContractOwner() public view {
        address deployer = coin.owner_();
        assertEq(deployer, sathvik, "Error deployer storage!");
    }

    function test_TokenDetails() public view {
        string memory name = coin.name();
        string memory symbol = coin.symbol();
        uint8 decimals = coin.decimals();
        uint256 maxCap = coin.maxCap_();
        assertEq(name, "MelodyCoin", "Error setting token name");
        assertEq(symbol, "MLD", "Error setting token symbol");
        assertEq(decimals, 18, "Error setting token decimals");
        assertEq(maxCap, 1e23, "Error setting maxCap");
    }

    function test_InitialContractBalance() public view {
        address contractAddress = coin.contractAddress();
        uint256 initialBalance = coin.balanceOf(contractAddress);
        assertEq(initialBalance, 1e19, "Error setting initial supply");
    }

    // tests for contract faucet
    function test_GetAssetFromFaucet() public {
        helper_RequestFaucetAssets(sathvik, 1);
        uint256 balance = coin.balanceOf(sathvik);
        assertEq(balance, 1e17, "Error fetching assets from faucet");
    }

    function test_ExcessBalanceForFaucet() public {
        helper_RequestFaucetAssets(bob, 15);
        vm.expectRevert(abi.encodeWithSignature("TooHighBalance(address)", bob));
        helper_RequestFaucetAssets(bob, 1);
    }

    function test_FrequentFaucetAbuse() public {
        vm.expectRevert(abi.encodeWithSignature("TooFrequentRequests(address)", bob));
        vm.prank(bob);
        coin.getFaucetAssets();
    }

    function test_FaucetReserveAlert() public {
        address[10] memory users;
        for (uint8 i = 0; i < 10; i++) {
            users[i] = address(uint160(i + 3));
        }
        for (uint8 userIndex = 0; userIndex < 9; userIndex++) {
            helper_RequestFaucetAssets(users[userIndex], 10);
        }
        helper_RequestFaucetAssets(users[9], 9);
        vm.expectRevert(abi.encodeWithSignature("DepletedFaucetReserves()"));
        helper_RequestFaucetAssets(users[9], 1);
    }

    // tests for transfer functionalities
    function test_TransferFundsToUser() public {
        address contractAddress = coin.contractAddress();
        helper_RequestFaucetAssets(sathvik, 10);
        vm.startPrank(sathvik);
        coin.transfer(bob, 1e18);
        assertLt(coin.balanceOf(sathvik), 1e18, "Error reducing balance of the sender");
        assertLt(coin.balanceOf(bob), 1e18, "Error burning down tokens");
        assertGt(coin.balanceOf(contractAddress), 0, "Error cutting reserve share in transfer");
    }

    function test_InvalidTransferAddress() public {
        vm.startPrank(sathvik);
        vm.expectRevert(abi.encodeWithSignature("InvalidAddress()"));
        coin.transfer(invalidAddress, 1e17);
        vm.stopPrank();
    }

    function test_PauseTimeTransferCheck() public {
        helper_RequestFaucetAssets(sathvik, 2);
        vm.startPrank(sathvik);
        coin.togglePause();
        vm.expectRevert(abi.encodeWithSignature("ContractPaused()"));
        coin.transfer(bob, 1e17);
        vm.stopPrank();
    }

    function test_InsufficientFundsTransferFailure() public {
        vm.expectRevert(abi.encodeWithSignature("InsufficientFunds(uint256,uint256)", 0, 1e18));
        vm.startPrank(sathvik);
        coin.transfer(bob, 1e18);
        vm.stopPrank();
    }

    // tests for mint functionalities
    function test_OnlyOwnerCanMint() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSignature("NotAnOwner()"));
        coin.mint(bob, 1e18);
    }

    function test_CantMintWhePaused() public {
        vm.startPrank(sathvik);
        coin.togglePause();
        vm.expectRevert(abi.encodeWithSignature("ContractPaused()"));
        coin.mint(sathvik, 1e18);
        vm.stopPrank();
    }

    function test_MintExceedMaxCapCheck() public {
        vm.startPrank(sathvik);
        vm.expectRevert(abi.encodeWithSignature("MaxCapExceeded()"));
        coin.mint(sathvik, 1e24);
        vm.stopPrank();
    }

    function test_ReserveShareDuringMint() public {
        vm.startPrank(sathvik);
        coin.mint(sathvik, 1e20);
        assertEq(
            coin.balanceOf(coin.contractAddress()),
            3e19, // 10 as init supply and 20 as reserve share during mint
            "Error taking reserve sharing during mint"
        );
        vm.stopPrank();
    }

    function test_MintUserShareCheck() public {
        vm.startPrank(sathvik);
        coin.mint(sathvik, 1e20);
        assertLt(coin.balanceOf(coin.contractAddress()), 1e20, "Error calculating user share while minting");
        vm.stopPrank();
    }

    function test_UpdateTotalSupplyOnMint() public {
        vm.startPrank(sathvik);
        coin.mint(sathvik, 1e20);
        assertEq(coin.totalSupply(), 11e19, "Error updating total supply while mint");
        vm.stopPrank();
    }

    // tests for approval, allowance and transfer from
    function test_AllowanceCheck() public {
        helper_RequestFaucetAssets(sathvik, 10);
        vm.startPrank(sathvik);
        coin.approve(bob, 1e17);
        uint256 allowance = coin.allowance(sathvik, bob);
        assertEq(1e17, allowance, "Error updating allowances");
    }

    function test_ApprovalWhilePauseCheck() public {
        helper_RequestFaucetAssets(sathvik, 2);
        vm.startPrank(sathvik);
        coin.togglePause();
        vm.expectRevert(abi.encodeWithSignature("ContractPaused()"));
        coin.approve(bob, 1e14);
        vm.stopPrank();
    }

    function test_TransferFromOnAllowance() public {
        address alice = address(3);
        helper_RequestFaucetAssets(sathvik, 2);
        vm.prank(sathvik);
        coin.approve(bob, 1e15);
        vm.prank(bob);
        coin.transferFrom(sathvik, alice, 1e15);
        uint256 recvBalance = coin.balanceOf(alice);
        uint256 senderBalance = coin.balanceOf(sathvik);
        assertGt(recvBalance, 0, "Error tranferring tokens in transferFrom");
        assertLt(recvBalance, 1e15, "Error burning tokens in transferFrom");
        assertLt(senderBalance, 2e17, "Error cutting tokens from sender in transferFrom");
    }

    function test_TransferFromNoBalanceCheck() public {
        address alice = address(3);
        helper_RequestFaucetAssets(sathvik, 1);
        vm.prank(sathvik);
        coin.approve(bob, 1e20);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSignature("InsufficientFunds(uint256,uint256)", 1e17, 1e20));
        coin.transferFrom(sathvik, alice, 1e20);
    }

    function test_AllowanceOverSpendCheck() public {
        helper_RequestFaucetAssets(sathvik, 1);
        address alice = address(3);
        coin.approve(bob, 1e15);
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSignature("InsufficientAllowance()"));
        coin.transferFrom(sathvik, alice, 1e16);
        vm.stopPrank();
    }

    // users can give allowance for amounts greater than the current balance, the balance sufficiency is only checked when transferring funds
    function test_CanAllowMoreThanBalance() public {
        helper_RequestFaucetAssets(sathvik, 1); // now has only 1MLD or 1e18wei
        coin.approve(bob, 1e20); // more allowance than balance is accepted
    }

    function test_CheckFrontRunRaceCondition() public {
        vm.startPrank(sathvik);
        coin.approve(bob, 1e18);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FrontRunApprovalCheck(string)", "Set allowance to zero first, to avoid frontrun race"
            )
        );
        coin.approve(bob, 1e17);
        vm.stopPrank();
    }

    // tests for pause and unpause contract
    function test_PauseContract() public {
        vm.prank(sathvik);
        coin.togglePause();
        bool isPaused = coin.paused();
        assertEq(isPaused, true, "Error pausing contract");
    }

    function test_UnPauseContract() public {
        vm.startPrank(sathvik);
        coin.togglePause();
        coin.togglePause();
        bool isPaused = coin.paused();
        assertEq(isPaused, false, "Error unpausing contract");
    }

    // test accidental ETH send
    function test_RevertOnEth() public {
        vm.deal(sathvik, 10 ether);
        address contractAddress = coin.contractAddress();
        vm.expectRevert("Contract does not accept ETH");
        payable(contractAddress).transfer(1 ether);
    }
}
