//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title Wallet
 * @author batublockdev
 * @notice This contract allows a users to deposit funds to the owner's wallet,
 * but only the owner can withdraw or transfer funds, the upgrade in this version is
 * that users can withdraw funds with the owner's premission using a signature, aditionally
 * this version accepts ERC20 tokens as a currency.
 */

contract Wallet is EIP712 {
    error Wallet_NotOwner();
    error Wallet_NotEnoughFunds();
    error Wallet__TokenNotValid(address token);
    error Wallet__NotApprovedForToken(address token);
    error Wallet__FaildReceiveToken(address token);
    error Wallet_CantBeZero();
    error Wallet__SpenderNotValid(address spender);
    error Wallet_SignatureInvalid();
    error Wallet_TransferFailed();

    address public immutable i_owner;
    address[] private tokenAddress;
    uint256 private s_nonce;
    mapping(address => uint256) tokenAmount;

    using ECDSA for bytes32;
    using SafeERC20 for IERC20;

    bytes32 private constant MESSAGE_TYPEHASH =
        keccak256("Person(string name,address wallet)");

    // define the message hash struct
    struct CheckClaim {
        address owner;
        address spender;
        address token;
        uint256 value;
        uint256 nonce;
        uint256 deadline;
    }

    /*
     * @dev This modifier checks if the caller is the owner of the contract.
     * If not, it reverts with a custom error.
     */
    modifier onlyOwner() {
        if (msg.sender != i_owner) revert Wallet_NotOwner();
        _;
    }
    /**
     * @dev This modifier checks if the contract has enough funds to withdraw.
     * If not, it reverts with a custom error.
     * @param amount The amount to check.
     */
    modifier EnoughFunds(uint256 amount) {
        if (address(this).balance < amount) revert Wallet_NotEnoughFunds();
        _;
    }
    /**
     * @dev This modifier checks if the contract has enough funds to withdraw.
     * If not, it reverts with a custom error.
     * @param token The address of the token to check.
     * @param amount The amount to check.
     */
    modifier EnoughFundsToken(address token, uint256 amount) {
        if (tokenAmount[token] < amount) revert Wallet_NotEnoughFunds();
        _;
    }
    /**
     * @dev This modifier checks if the amount is not zero.
     * If it is zero, it reverts with a custom error.
     * @param amount The amount to check.
     */
    modifier cantbezero(uint256 amount) {
        if (amount == 0) revert Wallet_CantBeZero();
        _;
    }
    /**
     * @dev This modifier checks if the token is valid and if the transfer was successful.
     * If not, it reverts with a custom error.
     * @param token The address of the token to check.

     */
    modifier checkToken(address token) {
        if (token == address(0)) {
            revert Wallet__TokenNotValid(token);
        }

        _;
    }

    constructor() EIP712("Wallet", "1.0") {
        i_owner = msg.sender;
    }

    fallback() external payable {
        this.deposit();
    }

    receive() external payable {
        this.deposit();
    }

    ////////////////////////////////
    ////// EXTERNAL FUNCTIONS //////
    ////////////////////////////////
    /**
     * @dev This function allows users to deposit funds to the contract.
     * @notice The funds are stored in the contract and can be withdrawn or transferred
     * by the owner.
     * @dev The function is payable, so it can receive ether.
     * @dev The function does not return anything.
     */
    function deposit() external payable {}

    /**
     * @dev This function allows users to deposit ERC20 tokens to the contract.
     * @notice The tokens are stored in the contract and can be withdrawn or transferred
     * by the owner.
     * @param token which token to deposit
     * @param amount to deposit
     */
    function deposit_token(
        address token,
        uint256 amount
    ) external cantbezero(amount) {
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

    /**
     * @dev This function allows the owner to withdraw funds from the contract.
     * @notice The funds are transferred to the owner's address.
     * @param amount The amount to withdraw.
     * @dev The function is only callable by the owner.
     */
    function withdraw(
        uint256 amount
    ) external onlyOwner cantbezero(amount) EnoughFunds(amount) {
        (bool callSuccess, ) = payable(i_owner).call{value: amount}("");
        if (!callSuccess) {
            revert Wallet_TransferFailed();
        }
    }

    /**
     * @dev This function allows the owner to withdraw ERC20 tokens from the contract.
     * @notice The tokens are transferred to the owner's address.
     * @param token The address of the token to withdraw.
     * @param amount The amount to withdraw.
     * @dev The function is only callable by the owner.
     */
    function withdraw_token(
        address token,
        uint256 amount
    )
        external
        onlyOwner
        cantbezero(amount)
        EnoughFundsToken(token, amount)
        checkToken(token)
    {
        tokenAmount[token] -= amount;
        IERC20(token).safeTransfer(i_owner, amount);
    }

    /**
     * @dev This function allows the owner to transfer funds from the contract to a specified address.
     * @notice The funds are transferred to the specified address.
     * @param to The address to transfer the funds to.
     * @param amount The amount to transfer.
     * @dev The function is only callable by the owner.
     */
    function transfer(
        address to,
        uint256 amount
    ) external onlyOwner EnoughFunds(amount) {
        require(to != address(0), "Invalid address");
        (bool callSuccess, ) = payable(to).call{value: amount}("");
        if (!callSuccess) {
            revert Wallet_TransferFailed();
        }
    }

    /**
     * @dev This function allows the owner to transfer ERC20 tokens from the contract to a specified address.
     * @notice The tokens are transferred to the specified address.
     * @param token The address of the token to transfer.
     * @param to The address to transfer the tokens to.
     * @param amount The amount to transfer.
     * @dev The function is only callable by the owner.
     */
    function transfer_token(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner EnoughFundsToken(token, amount) checkToken(token) {
        tokenAmount[token] -= amount;
        IERC20(token).safeTransfer(to, amount);
    }

    /**
     * @dev This function allows the users to claim funds from the contract
     * using a signature sign by the owner.
     * @param account The address to transfer the funds to.
     * @param amount The amount to transfer.
     * @param token The address of the token to transfer.
     * @param _v The recovery byte of the signature.
     * @param _r The r value of the signature.
     * @param _s The s value of the signature.
     */
    function claim_Check(
        address account,
        uint256 amount,
        address token,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {
        if (account == address(0) || account != msg.sender) {
            revert Wallet__SpenderNotValid(account);
        }
        bytes32 digest = _getMessageHash(account, amount, token);
        if (!_isValidSignature(digest, _v, _r, _s)) {
            revert Wallet_SignatureInvalid();
        }
        if (token == address(0)) {
            if (address(this).balance < amount) revert Wallet_NotEnoughFunds();
            (bool callSuccess, ) = payable(account).call{value: amount}("");
            if (!callSuccess) {
                revert Wallet_TransferFailed();
            }
        } else {
            if (tokenAmount[token] < amount) revert Wallet_NotEnoughFunds();
            tokenAmount[token] -= amount;
            IERC20(token).safeTransfer(account, amount);
        }
        s_nonce++;
    }

    ///////////////////////////////
    ////// INTERNAL FUNCTIONS //////
    ///////////////////////////////
    /**
     * @dev This function returns the message hash for the claim_Check function.
     * @param account The address to transfer the funds to.
     * @param amount The amount to transfer.
     * @param token The address of the token to transfer.
     * @return The message hash.
     */

    function _getMessageHash(
        address account,
        uint256 amount,
        address token
    ) internal view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        MESSAGE_TYPEHASH,
                        CheckClaim({
                            owner: i_owner,
                            spender: account,
                            token: token,
                            value: amount,
                            nonce: s_nonce,
                            deadline: block.timestamp + 30 days
                        })
                    )
                )
            );
    }

    /**
     * @dev This function checks if the signature is valid.
     * @param digest The message hash.
     * @param _v The recovery byte of the signature.
     * @param _r The r value of the signature.
     * @param _s The s value of the signature.
     * @return True if the signature is valid, false otherwise.
     */
    function _isValidSignature(
        bytes32 digest,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) internal view returns (bool) {
        // could also use SignatureChecker.isValidSignatureNow(signer, digest, signature)
        (
            address actualSigner /*ECDSA.RecoverError recoverError*/ /*bytes32 signatureLength*/,
            ,

        ) = ECDSA.tryRecover(digest, _v, _r, _s);
        return (actualSigner == i_owner);
    }

    //////////////////////////
    ////// VIEW FUNCTIONS ////
    //////////////////////////
    /**
     * @dev This function returns the message hash for the claim_Check function.
     * @param account The address to transfer the funds to.
     * @param amount The amount to transfer.
     * @param token The address of the token to transfer.
     * @return The message hash.
     * @dev The function is view, so it does not modify the state of the contract.
     */
    function getMessageHash(
        address account,
        uint256 amount,
        address token
    ) external view returns (bytes32) {
        return _getMessageHash(account, amount, token);
    }

    /**
     * @dev This function returns the token list in the contract.
     * @return The token list.
     */
    function getTokenAddress()
        external
        view
        onlyOwner
        returns (address[] memory)
    {
        return tokenAddress;
    }

    /**
     * @dev This function returns the token balance of the contract.
     * @return The balance of the contract.
     */
    function getTokenAmount(
        address token
    ) external view onlyOwner returns (uint256) {
        return tokenAmount[token];
    }
}
