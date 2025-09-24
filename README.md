# 🌱 Tokenised Renewable Energy Trading

A decentralized marketplace for trading renewable energy tokens on the Stacks blockchain. This smart contract enables energy producers to tokenize their renewable energy production and allows consumers to purchase these tokens directly.

## ⚡ Features

- 🔋 **Energy Token Minting**: Verified producers can mint tokens representing renewable energy units
- 🛒 **Decentralized Trading**: Create and execute buy/sell orders for energy tokens
- ✅ **Producer Verification**: Contract owner can verify legitimate energy producers
- 💰 **Dynamic Pricing**: Producers set their own token prices
- 📊 **Reputation System**: Track producer reputation based on successful trades
- 🔄 **Order Management**: Cancel active buy/sell orders anytime
- 💸 **Platform Fees**: Configurable platform fees for sustainable operations

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://docs.hiro.so/stacks/clarinet) installed
- [Node.js](https://nodejs.org/) for testing

### Installation

```bash
git clone <repository-url>
cd Tokenised-Renewable-Energy-Trading
clarinet check
```

## 📖 Usage Guide

### For Energy Producers 🏭

1. **Register as Producer**
   ```clarity
   (contract-call? .Tokenised-Renewable-Energy-Trading register-producer u1000000)
   ```

2. **Wait for Verification** (done by contract owner)

3. **Mint Energy Tokens**
   ```clarity
   (contract-call? .Tokenised-Renewable-Energy-Trading mint-energy-tokens u100)
   ```

4. **Create Sell Orders**
   ```clarity
   (contract-call? .Tokenised-Renewable-Energy-Trading create-sell-order u50 u1000000)
   ```

### For Energy Consumers 🏠

1. **Browse Available Orders**
   ```clarity
   (contract-call? .Tokenised-Renewable-Energy-Trading get-sell-order u1)
   ```

2. **Execute Buy Orders**
   ```clarity
   (contract-call? .Tokenised-Renewable-Energy-Trading execute-sell-order u1)
   ```

3. **Create Buy Orders**
   ```clarity
   (contract-call? .Tokenised-Renewable-Energy-Trading create-buy-order u25 u1200000)
   ```

### For Contract Administrators 👨‍💼

1. **Verify Producers**
   ```clarity
   (contract-call? .Tokenised-Renewable-Energy-Trading verify-producer 'SP1234...)
   ```

2. **Set Platform Fees**
   ```clarity
   (contract-call? .Tokenised-Renewable-Energy-Trading set-platform-fee-rate u50)
   ```

## 🔧 Contract Functions

### Read-Only Functions

- `get-energy-producer(principal)` - Get producer information
- `get-energy-consumer(principal)` - Get consumer statistics
- `get-sell-order(uint)` - Get sell order details
- `get-buy-order(uint)` - Get buy order details
- `get-token-balance(principal)` - Get token balance
- `get-total-supply()` - Get total token supply
- `get-platform-stats()` - Get platform statistics

### Public Functions

#### Producer Functions
- `register-producer(price-per-token)` - Register as energy producer
- `mint-energy-tokens(amount)` - Mint tokens (verified producers only)
- `update-producer-price(new-price)` - Update token price

#### Trading Functions
- `create-sell-order(amount, price-per-token)` - Create sell order
- `create-buy-order(amount, max-price)` - Create buy order
- `execute-sell-order(order-id)` - Buy from sell order
- `execute-buy-order(order-id)` - Sell to buy order
- `cancel-sell-order(order-id)` - Cancel own sell order
- `cancel-buy-order(order-id)` - Cancel own buy order

#### General Functions
- `transfer-tokens(amount, recipient)` - Transfer tokens
- `verify-producer(producer)` - Verify producer (owner only)
- `set-platform-fee-rate(new-rate)` - Set platform fee (owner only)

## 💡 Token Economics

- **Token Symbol**: Green Energy Token
- **Decimals**: 6 (1,000,000 = 1 MWh)
- **Platform Fee**: Default 0.25% (configurable)
- **Pricing**: Market-driven by producers and consumers

## 🧪 Testing

```bash
npm install
npm test
```

## 📊 Platform Statistics

The contract tracks:
- Total energy produced and consumed
- Token supply and circulation
- Producer reputation scores
- Consumer purchase history

## 🛡️ Security Featuress

- Producer verification system
- Balance checks before transfers
- Order ownership validation
- Platform fee limits (max 10%)



## 📄 License

This project is licensed under the MIT License.

## 🌐 Network Information

- **Testnet**: Deploy with Clarinet
- **Mainnet**: Coming soon

---

Made with 💚 for a sustainable future
