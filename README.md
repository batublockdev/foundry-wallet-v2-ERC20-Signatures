# 👜 Wallet Smart Contract

A secure, owner-controlled smart wallet built in Solidity, enabling flexible deposit, withdrawal, and transfer of Ether and ERC20 tokens — with off-chain authorized withdrawals via EIP-712 signatures.

---

## 📌 Summary

- 🔐 **Owner-based fund management**
- 💸 **Users can deposit Ether or ERC20 tokens**
- ✍️ **Users can withdraw if authorized by the owner’s EIP-712 signature**
- 🔁 **Replay protection with nonces**
- ✅ **ERC20 support using SafeERC20 from OpenZeppelin**

---

## 🧱 Deployment

```solidity
constructor() EIP712("Wallet", "1.0") {
    i_owner = msg.sender;
}
```

- The deployer becomes the immutable owner (`i_owner`).
- Initializes EIP-712 domain separator (`Wallet`, version `1.0`).

---

## 🔐 Roles

| Role    | Description                             |
|---------|-----------------------------------------|
| Owner   | Only address that can withdraw or transfer funds. |
| User    | Can deposit funds or claim with a valid signature. |

---

## ⚙️ Functions

### 📥 Deposits

| Function | Description |
|----------|-------------|
| `deposit()` | Accepts Ether via `payable` fallback or direct call. |
| `deposit_token(address token, uint256 amount)` | Deposit ERC20 tokens after approval. |

### 💸 Withdrawals (Owner only)

| Function | Description |
|----------|-------------|
| `withdraw(uint256 amount)` | Withdraw Ether to owner’s wallet. |
| `withdraw_token(address token, uint256 amount)` | Withdraw specified ERC20 token to owner. |
| `transfer(address to, uint256 amount)` | Transfer Ether to another address. |
| `transfer_token(address token, address to, uint256 amount)` | Transfer ERC20 tokens to another address. |

### 🖊️ Off-Chain Authorized Claims

```solidity
claim_Check(
  address account,
  uint256 amount,
  address token,
  uint8 v,
  bytes32 r,
  bytes32 s
)
```

- Verifies EIP-712 signature by the owner.
- Lets `account` claim funds (ETH or ERC20).
- Uses nonce to prevent replay attacks.
- Valid for `30 days` from signature time.

### 📄 View Functions

| Function | Returns |
|----------|---------|
| `getMessageHash(address account, uint256 amount, address token)` | Message hash used in EIP-712 signing. |
| `getTokenAddress()` | Returns array of ERC20 token addresses. |
| `getTokenAmount(address token)` | Returns token balance held in the contract. |

---

## 🧱 Data Structures

### 🔹 `CheckClaim` struct

```solidity
struct CheckClaim {
    address owner;
    address spender;
    address token;
    uint256 value;
    uint256 nonce;
    uint256 deadline;
}
```

Used for signing and verifying off-chain approvals.

---

## 🛡️ Modifiers

| Modifier | Purpose |
|----------|---------|
| `onlyOwner` | Restricts functions to contract owner. |
| `EnoughFunds(uint256 amount)` | Ensures sufficient Ether. |
| `EnoughFundsToken(address token, uint256 amount)` | Ensures sufficient token balance. |
| `cantbezero(uint256 amount)` | Prevents 0-value operations. |
| `checkToken(address token)` | Validates non-zero token address. |

---

## 🧠 Internal Logic

### `_getMessageHash(...)`

Generates EIP-712 typed message hash used for signature verification.

### `_isValidSignature(...)`

Uses `ECDSA.tryRecover` to validate that the message was signed by `i_owner`.

---

## 🧰 Custom Errors

| Error | Trigger |
|-------|--------|
| `Wallet_NotOwner()` | Caller is not the contract owner. |
| `Wallet_NotEnoughFunds()` | Contract lacks sufficient ETH/token. |
| `Wallet__TokenNotValid(token)` | Zero-address token used. |
| `Wallet__NotApprovedForToken(token)` | User didn’t approve token allowance. |
| `Wallet__FaildReceiveToken(token)` | ERC20 transfer failed. |
| `Wallet_CantBeZero()` | Value is 0. |
| `Wallet__SpenderNotValid(spender)` | Invalid spender or mismatch. |
| `Wallet_SignatureInvalid()` | Signature doesn’t match owner. |
| `Wallet_TransferFailed()` | ETH transfer failed. |

---

## 🔐 Security Best Practices

- ✅ EIP-712 signature prevents unauthorized withdrawals.
- ✅ Nonce prevents replay attacks.
- ✅ `SafeERC20` used to safely interact with tokens.
- ❌ No reentrancy protection — should be added for production.
- ❌ No event logging — consider emitting events for deposits, withdrawals, and claims.

---

## 🧪 EIP-712 Signature Integration Example

To authorize a user off-chain:

```js
const domain = {
  name: "Wallet",
  version: "1.0",
  chainId,
  verifyingContract: contractAddress,
};

const types = {
  Person: [
    { name: "owner", type: "address" },
    { name: "spender", type: "address" },
    { name: "token", type: "address" },
    { name: "value", type: "uint256" },
    { name: "nonce", type: "uint256" },
    { name: "deadline", type: "uint256" },
  ],
};

const value = {
  owner: ownerAddress,
  spender: userAddress,
  token: tokenAddress,
  value: amount,
  nonce,
  deadline: Math.floor(Date.now() / 1000) + 30 * 24 * 60 * 60,
};

const signature = await signer._signTypedData(domain, types, value);
```

Then the user calls `claim_Check(...)` on-chain using that signature.

---

## ✅ TODOs

- [ ] Add `event` logging for better observability
- [ ] Add `ReentrancyGuard` to prevent attack vectors
- [ ] Add revocation logic for signatures if needed
- [ ] Consider gas optimizations for token address tracking

---

## 🧾 License

[MIT](./LICENSE)

---

## 👤 Author

**batublockdev**
