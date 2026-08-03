import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';

class BlockchainService {
  // 1. RPC URL (e.g., Sepolia endpoint from Alchemy/Infura or local node)
  final String _rpcUrl = "https://ethereum-sepolia-rpc.publicnode.com";

  // 2. The contract address copied from Remix
  final String _contractAddressHex =
      "0xa8C1Ff6Ee8f8f686AFAB25E3232dE621816c2210";

  late Web3Client _web3client;
  late DeployedContract _contract;

  // Contract functions
  late ContractFunction _addProductFunc;
  late ContractFunction _verifyProductFunc;
  late ContractFunction _markAsSoldFunc;

  /// Initialize the Web3 connection and load the contract ABI
  Future<void> init() async {
    _web3client = Web3Client(_rpcUrl, http.Client());

    // 1. Load ABI from local assets folder
    String abiString = await rootBundle.loadString('assets/contract_abi.json');

    // 2. Instantiate DeployedContract
    _contract = DeployedContract(
      ContractAbi.fromJson(abiString, 'FakeProductDetection'),
      EthereumAddress.fromHex(_contractAddressHex),
    );

    // 3. Bind smart contract functions
    _addProductFunc = _contract.function('addProduct');
    _verifyProductFunc = _contract.function('verifyProduct');
    _markAsSoldFunc = _contract.function('markAsSold');
  }

  /// PRE-FLIGHT CHECK: Estimate gas cost and verify account Sepolia ETH balance
  /// Returns null if balance is sufficient, or a formatted warning string if not.
  Future<String?> checkGasAndBalance({
    required String privateKeyHex,
    required String functionName,
    required List<dynamic> params,
  }) async {
    try {
      final credentials = EthPrivateKey.fromHex(privateKeyHex);
      final senderAddress = credentials.address;

      // 1. Fetch current account balance
      final EtherAmount balance = await _web3client.getBalance(senderAddress);

      // 2. Fetch current network gas price
      final EtherAmount gasPrice = await _web3client.getGasPrice();

      // 3. Select target function
      final function = _contract.function(functionName);

      // 4. Estimate required gas units
      final BigInt estimatedGasLimit = await _web3client.estimateGas(
        sender: senderAddress,
        to: _contract.address,
        data: function.encodeCall(params),
      );

      // 5. Calculate total fee in Wei = Gas Limit * Gas Price
      final BigInt totalCostWei = estimatedGasLimit * gasPrice.getInWei;
      final BigInt balanceWei = balance.getInWei;

      // 6. Compare balance against required gas fee
      if (balanceWei < totalCostWei) {
        final double requiredEth = totalCostWei / BigInt.from(10).pow(18);
        final double currentEth = balanceWei / BigInt.from(10).pow(18);

        return 'Insufficient Sepolia ETH for gas fees!\n\n'
            '• Estimated Fee: ~${requiredEth.toStringAsFixed(6)} ETH\n'
            '• Current Balance: ${currentEth.toStringAsFixed(6)} ETH\n\n'
            'Please top up your wallet with Sepolia test ETH.';
      }

      return null; // Sufficient balance!
    } catch (e) {
      // If estimation fails due to invalid key or format, return null 
      // and let the main execution block surface the explicit error cleanly.
      return null;
    }
  }

  /// READ FUNCTION: Verify product details (Free call, no gas needed)
  Future<Map<String, dynamic>> verifyProduct(String serialNumber) async {
    try {
      final result = await _web3client.call(
        contract: _contract,
        function: _verifyProductFunc,
        params: [serialNumber],
      );

      // Result order matches Solidity return tuple: (name, manufacturer, timestamp, isSold)
      return {
        'name': result[0] as String,
        'manufacturer': (result[1] as EthereumAddress).hex,
        'timestamp': DateTime.fromMillisecondsSinceEpoch(
          (result[2] as BigInt).toInt() * 1000,
        ),
        'isSold': result[3] as bool,
        'isAuthentic': true,
      };
    } catch (e) {
      // If the serial number is not on-chain, contract reverts
      return {
        'isAuthentic': false,
        'error': 'Product not found on blockchain!',
      };
    }
  }

  /// WRITE FUNCTION: Add a new product (Requires manufacturer private key for gas)
  Future<String> addProduct({
    required BigInt id,
    required String serialNumber,
    required String name,
    required String privateKeyHex,
  }) async {
    final credentials = EthPrivateKey.fromHex(privateKeyHex);

    final transactionHash = await _web3client.sendTransaction(
      credentials,
      Transaction.callContract(
        contract: _contract,
        function: _addProductFunc,
        parameters: [id, serialNumber, name],
      ),
      chainId: 11155111,
    );

    return transactionHash;
  }

  /// WRITE FUNCTION: Mark product as sold after retail purchase
  Future<String> markAsSold({
    required String serialNumber,
    required String privateKeyHex,
  }) async {
    final credentials = EthPrivateKey.fromHex(privateKeyHex);

    final transactionHash = await _web3client.sendTransaction(
      credentials,
      Transaction.callContract(
        contract: _contract,
        function: _markAsSoldFunc,
        parameters: [serialNumber],
      ),
      chainId: 11155111,
    );

    return transactionHash;
  }
}