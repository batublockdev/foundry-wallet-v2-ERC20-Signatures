// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Wallet} from "../../src/Wallet.sol";
import {Script} from "forge-std/Script.sol";
import {DeployWallet} from "../../script/DeployWallet.s.sol";
import {ERC20Mock} from "../mock/ERC20Mock.sol";

contract WalletTest is Test {
    Wallet wallet;
    address xuserx = makeAddr("xuserx");
    address freind = makeAddr("freind");
    address owner;
    uint256 ownerPrivKey;
    ERC20Mock token;
    address[] addressTokens;

    function setUp() public {
        (owner, ownerPrivKey) = makeAddrAndKey("owner");
        vm.startPrank(owner);
        wallet = new Wallet();
        vm.stopPrank();
        vm.deal(xuserx, 100 ether);

        // Set up the mock ERC20 token
        token = new ERC20Mock("Mock Token", "MOCK", 100 ether, freind);
    }

    modifier execution() {
        vm.startPrank(xuserx);
        wallet.deposit{value: 100 ether}();
        vm.stopPrank();
        _;
    }
    modifier execution_token() {
        vm.startPrank(freind);
        token.approve(address(wallet), 100 ether);
        wallet.deposit_token(address(token), 100 ether);
        vm.stopPrank();
        _;
    }

    function test_deposit_token() public {
        vm.startPrank(freind);
        token.approve(address(wallet), 100 ether);
        wallet.deposit_token(address(token), 100 ether);
        assertEq(token.balanceOf(address(wallet)), 100 ether);
        vm.startPrank(owner);
        assertEq(wallet.getTokenAmount(address(token)), 100 ether);
        addressTokens = wallet.getTokenAddress();
        assertEq(addressTokens[0], address(token));
        vm.stopPrank();
    }

    function test_Deposit_x() public {
        vm.prank(xuserx);
        wallet.deposit{value: 100 ether}();
        assertEq(address(wallet).balance, 100 ether);
    }

    function test_Withdraw() public execution {
        vm.prank(owner);
        wallet.withdraw(50 ether);
        assertEq(address(wallet).balance, 50 ether);
        assertEq(owner.balance, 50 ether);
    }

    function test_withdraw_token() public execution_token {
        vm.startPrank(owner);
        wallet.withdraw_token(address(token), 50 ether);
        assertEq(wallet.getTokenAmount(address(token)), 50 ether);
        vm.stopPrank();
        assertEq(token.balanceOf(address(wallet)), 50 ether);
        assertEq(token.balanceOf(address(owner)), 50 ether);
    }

    function test_Transfer() public execution {
        vm.prank(owner);
        wallet.transfer(freind, 50 ether);
        assertEq(address(wallet).balance, 50 ether);
        assertEq(freind.balance, 50 ether);
    }

    function test_Transfer_token() public execution_token {
        vm.startPrank(owner);
        wallet.transfer_token(address(token), freind, 50 ether);
        assertEq(wallet.getTokenAmount(address(token)), 50 ether);
        vm.stopPrank();
        assertEq(token.balanceOf(address(wallet)), 50 ether);
        assertEq(token.balanceOf(freind), 50 ether);
    }

    function signMessage(
        uint256 privKey,
        address account,
        uint256 amount,
        address s_token
    ) public view returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 hashedMessage = wallet.getMessageHash(account, amount, s_token);
        (v, r, s) = vm.sign(privKey, hashedMessage);
    }

    function test_claim_check() public execution {
        // get the signature
        vm.startPrank(owner);
        (uint8 v, bytes32 r, bytes32 s) = signMessage(
            ownerPrivKey,
            freind,
            50 ether,
            address(0)
        );
        vm.stopPrank();
        vm.prank(freind);
        wallet.claim_Check(freind, 50 ether, address(0), v, r, s);
        assertEq(address(wallet).balance, 50 ether);
        assertEq(freind.balance, 50 ether);
    }

    function test_claim_check_token() public execution_token {
        // get the signature
        vm.startPrank(owner);
        (uint8 v, bytes32 r, bytes32 s) = signMessage(
            ownerPrivKey,
            freind,
            50 ether,
            address(token)
        );
        vm.stopPrank();
        vm.prank(freind);
        wallet.claim_Check(freind, 50 ether, address(token), v, r, s);
        assertEq(token.balanceOf(address(wallet)), 50 ether);
        assertEq(token.balanceOf(freind), 50 ether);
    }

    function test_Owner() public {
        vm.prank(xuserx);
        vm.expectRevert();
        wallet.withdraw(100);
    }

    function test_notEnoughFunds() public execution {
        vm.expectRevert();
        wallet.withdraw(200);
    }

    receive() external payable {}

    fallback() external payable {}
}
