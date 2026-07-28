import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';

class BlockchainService {
  // 1. RPC URL (e.g., Sepolia endpoint from Alchemy/Infura or local node)
  final String _rpcUrl = "https://ethereum-sepolia-rpc.publicnode.com";

  // 2. The contract address copied from Remix
  // final String _contractAddressHex = "0xd9145CCE52D386f254917e481eB44e9943F39138";

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
      // REPLACE null WITH THE SEPOLIA CHAIN ID
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
      // REPLACE null WITH THE SEPOLIA CHAIN ID
      chainId: 11155111,
    );

    return transactionHash;
  }
}
