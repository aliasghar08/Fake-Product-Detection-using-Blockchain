# 🛡️ Decentralized Anti-Counterfeit Product Verification App

A blockchain-powered mobile supply chain verification system built with **Flutter**, **Dart**, **Native Android (Kotlin MethodChannels)**, and **EVM Smart Contracts (Solidity)**. 

This application bridges physical products with the Ethereum (Sepolia) blockchain using encrypted QR codes. It enables manufacturers to mint verifiable product tokens, retailers to settle items as sold upon purchase, and consumers to scan and verify product authenticity, ownership provenance, and scan locations in real time.

---

## 📸 Key Features

### 🔍 Consumer Portal (Product Verification)
* **Real-time QR Scanning:** Fast camera-based scanning powered by custom camera overlay logic.
* **GPS Anti-Photocopy Defense:** Captures geographic coordinates at the exact moment of scanning and provides a direct, one-tap link to view the scan origin in Google Maps to mitigate QR cloning and photocopy attacks.
* **Product Timeline Sheet:** Interactive visual provenance timeline displaying manufacture timestamp, manufacturer address, and current ownership/sale status.
* **Local Scan History Ledger:** Persistent local storage of past scans with visual status indicators (*Authentic*, *Warning/Sold*, or *Fake*) and map location shortcuts.
* **Clone & Fraud Prevention:** Automatic flagging of potential duplicate/cloned items (e.g., items already marked as sold on-chain).

### 🏭 Manufacturer Portal (Minting & Physical Link)
* **On-Chain Product Registration:** Mints unique digital identifiers (Product ID, Serial Number, Name) directly to the smart contract with pre-flight network and gas fee validation.
* **Native Biometric Lock:** Protects saved manufacturer credentials behind Android's native `BiometricPrompt` (Fingerprint / Face ID).
* **Live QR Preview Dialog:** Displays an interactive, bordered high-res QR code preview inside the success dialog upon minting.
* **Zero-Package Native Gallery Export:** Writes raw image byte streams directly to the Android `MediaStore` via a custom Kotlin `MethodChannel`, bypassing third-party gallery packages.

### 🛒 Retailer Checkout Portal
* **Automated POS Settlement:** Authorized retailers execute `markAsSold` transactions on-chain during customer purchase.
* **Biometric Wallet Unlocking:** Hardware-backed biometric authentication required prior to loading saved wallet credentials into memory.

### 🔐 Native Security & Cryptography Architecture
* **Dual-Role XOR Cryptographic Engine:** A custom software-level **Bitwise XOR Cipher + Base64 encoding** algorithm (`StorageService`) persisting sensitive credentials securely on-device with isolated storage keys for Manufacturer and Retailer roles.
* **Zero-Package MethodChannel Architecture:** Native communication bridge between Flutter Dart and Android Kotlin (`FlutterFragmentActivity`) for direct OS API access.

### ⚙️ Developer & Settings Control Panel
* **Dynamic Contract & RPC Configurator:** Real-time on-the-fly updates to the Sepolia smart contract address and RPC endpoint configuration straight from the app UI—ideal for live demonstrations without recompiling code.

---

## 🛠️ Tech Stack & Architecture

### **Core Framework & Languages**
* **Frontend Framework:** [Flutter](https://flutter.dev) (Dart SDK `^3.12.2`)
* **Native Platform Code:** Android Kotlin (`FlutterFragmentActivity`, `MethodChannel`)

### **Blockchain & Cryptography**
* **Smart Contracts:** Solidity (EVM)
* **Network Target:** Ethereum Testnet (Sepolia via JSON-RPC)
* **Blockchain Interoperability:** `web3dart` & `http`
* **Local Encryption:** Bitwise XOR Cipher + Base64 Encoding over `SharedPreferences`

### **Hardware Integration & Native APIs**
* **Biometrics:** Android Native `BiometricPrompt` (`androidx.biometric:biometric:1.1.0`)
* **Gallery & Storage:** Android Native `MediaStore` Content Resolver via `MethodChannel`
* **Location & Maps:** `geolocator`, `url_launcher`

---

## 🚀 Getting Started

### Prerequisites

1. Install [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.12+ recommended).
2. Android Studio with Flutter and Dart plugins configured.
3. Physical Android device running Android 10+ (API level 29+) with biometric authentication enabled.
4. An active Ethereum testnet wallet (e.g., MetaMask on Sepolia) funded with test ETH.
