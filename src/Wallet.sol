//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Wallet
 * @author batublockdev
 * @notice This contract allows a users to deposit funds to the owner's wallet,
 * but only the owner can withdraw or transfer funds, the upgrade in this vertion is
 * that users can withdraw funds with the owner premission using a signature, in the same way
 * this vertion accepts ERC20 tokens.
 */

contract Wallet {
    error Wallet_NotOwner();
    error Wallet_NotEnoughFunds();
    error Wallet__TokenNotValid(address token);
    error Wallet__NotApprovedForToken(address token);
    error Wallet__FaildReceiveToken(address token);
    error Wallet_CantBeZero();

    address public immutable i_owner;
    address[] private tokenAddress;
    mapping(address => uint256) tokenAmount;

    modifier onlyOwner() {
        if (msg.sender != i_owner) revert Wallet_NotOwner();
        _;
    }

    modifier EnoughFunds(uint256 amount) {
        if (address(this).balance < amount) revert Wallet_NotEnoughFunds();
        _;
    }
    modifier EnoughFundsToken(address token, uint256 amount) {
        if (tokenAmount[token] < amount) revert Wallet_NotEnoughFunds();
        _;
    }
    modifier cantbezero(uint256 amount) {
        if (amount == amount) revert Wallet_CantBeZero();
        _;
    }
    modifier checkToken(
        address token,
        address to,
        uint256 amount
    ) {
        if (token == address(0)) {
            revert Wallet__TokenNotValid(token);
        }
        if (IERC20(token).transfer(to, amount) == false) {
            revert Wallet__FaildReceiveToken(token);
        }
        _;
    }

    constructor() {
        i_owner = msg.sender;
    }

    /**
     * @dev This function allows users to deposit funds to the contract.
     * @notice The funds are stored in the contract and can be withdrawn or transferred
     * by the owner.
     * @dev The function is payable, so it can receive ether.
     * @dev The function does not return anything.
     */
    function deposit() public payable {}

    function deposit_token(
        address token,
        uint256 amount
    ) public cantbezero(amount) {
        if (token == address(0)) {
            revert Wallet__TokenNotValid(token);
        }
        if (IERC20(token).allowance(msg.sender, address(this)) < amount) {
            revert Wallet__NotApprovedForToken(token);
        }
        if (
            IERC20(token).transferFrom(msg.sender, address(this), amount) ==
            false
        ) {
            revert Wallet__FaildReceiveToken(token);
        }
        tokenAddress.push(token);
        tokenAmount[token] += amount;
    }

    //funtion to withdraw funds
    function withdraw(
        uint256 amount
    ) public onlyOwner cantbezero(amount) EnoughFunds(amount) {
        (bool callSuccess, ) = payable(i_owner).call{value: amount}("");
        require(callSuccess, "Call failedxx");
    }

    function withdraw_token(
        address token,
        uint256 amount
    )
        public
        onlyOwner
        cantbezero(amount)
        EnoughFundsToken(token, amount)
        checkToken(token, i_owner, amount)
    {
        tokenAmount[token] -= amount;
    }

    //funtion to transfer funds
    function transfer(
        address to,
        uint256 amount
    ) public onlyOwner EnoughFunds(amount) {
        require(to != address(0), "Invalid address");
        (bool callSuccess, ) = payable(to).call{value: amount}("");
        require(callSuccess, "Call failed");
    }

    function transfer_token(
        address token,
        address to,
        uint256 amount
    )
        public
        onlyOwner
        EnoughFundsToken(token, amount)
        checkToken(token, to, amount)
    {
        tokenAmount[token] -= amount;
    }

    function getBalance() public view onlyOwner returns (uint256) {
        return address(this).balance;
    }

    fallback() external payable {
        deposit();
    }

    receive() external payable {
        deposit();
    }

    function getTokenAddress()
        public
        view
        onlyOwner
        returns (address[] memory)
    {
        return tokenAddress;
    }

    function getTokenAmount(
        address token
    ) public view onlyOwner returns (uint256) {
        return tokenAmount[token];
    }
}
