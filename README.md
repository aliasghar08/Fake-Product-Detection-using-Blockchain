# 🛡️ Decentralized Anti-Counterfeit Product Verification App

A blockchain-powered mobile supply chain verification system built with **Flutter**, **Dart**, and **EVM Smart Contracts (Solidity)**. 

This application bridges physical products with the Ethereum (Sepolia) blockchain using encrypted QR codes. It enables manufacturers to mint verifiable product tokens, retailers to mark items as sold upon purchase, and consumers to scan and verify product authenticity, ownership provenance, and scan locations in real time.

---

## 📸 Key Features

### 🔍 Consumer Portal (Product Verification)
* **Real-time QR Scanning:** Fast camera-based scanning powered by custom camera overlay logic.
* **GPS Anti-Photocopy Defense:** Captures geographic coordinates at the exact moment of scanning and provides a direct, one-tap link to view the scan origin in Google Maps to prevent QR cloning/photocopy attacks.
* **Product Timeline Sheet:** Interactive visual provenance timeline displaying manufacture timestamp, manufacturer address, and current ownership/sale status.
* **Local Scan History Ledger:** Persistent local storage of past scans with visual status indicators (Authentic, Warning/Sold, or Fake) and map location shortcuts.
* **Clone & Fraud Prevention:** Automatic flagging of potential duplicate/cloned items (e.g., items already marked as sold on-chain).

### 🏭 Manufacturer Portal (Minting & Physical Link)
* **On-Chain Product Registration:** Mints unique digital identifiers (Product ID, Serial Number, Name) directly to the smart contract.
* **Pre-Flight Network Protection:** Built-in native DNS lookups (`NetworkService`) instantly detect offline states to prevent blockchain transaction crashes and graceful error feedback.
* **QR Code Generation & PNG Export:** Generates high-resolution QR codes with white borders and exports them directly to the device's camera roll for label printing.

### 🛒 Retailer Checkout Portal
* **Automated POS Settlement:** Authorized retailers execute `markAsSold` transactions on-chain during customer purchase.
* **Gas-Optimized Signing:** Seamless transaction execution using locally stored wallet credentials.

### ⚙️ Developer & Settings Control Panel
* **Dynamic Contract & RPC Configurator:** Allows real-time on-the-fly updates to the Sepolia smart contract address and RPC endpoint configuration straight from the app settings UI—ideal for live FYP demonstrations without recompiling code.
* **Zero-Package Private Key Encryption:** Lightweight, custom software-level **Bitwise XOR Cipher + Base64 encoding** service (`StorageService`) safely persisting sensitive private keys on-device.

---

## 🛠️ Tech Stack & Dependencies

* **Frontend Framework:** [Flutter](https://flutter.dev) (Dart SDK `^3.12.2`)
* **Blockchain Interoperability:** `web3dart` & `http`
* **Network Target:** Ethereum Testnet (Sepolia Testnet via RPC)
* **Smart Contracts:** Solidity (EVM)
* **Location & Maps:** `geolocator`, `url_launcher`
* **Local Persistence:** `shared_preferences`
* **Media & Utilities:** `image_gallery_saver`, `qr_flutter`, `cupertino_icons`

---

## 🚀 Getting Started

### Prerequisites

1. Install [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.12+ recommended).
2. Android Studio / Antigravity IDE (VS Code architecture) with Flutter and Dart plugins configured.
3. An active Ethereum testnet wallet (e.g., MetaMask on Sepolia) with test ETH for transaction fees.
