
pragma solidity >=0.6.0 <0.7.0;

import "./MainContract.sol";
import "./ProxyFactory.sol";

/// @title Controlled ERC20 Token Factory
/// @notice Minimal proxy pattern for creating new Controlled ERC20 Tokens
contract MainContractProxyFactory is ProxyFactory {

  /// @notice Contract template for deploying proxied tokens
  MainContract public instance;

  /// @notice Initializes the Factory with an instance of the Controlled ERC20 Token
  constructor () public {
    instance = new MainContract();
  }

  /// @notice Creates a new Controlled ERC20 Token as a proxy of the template instance
  /// @return A reference to the new proxied Controlled ERC20 Token
  function create() external returns (MainContract) {
    return MainContract(deployMinimal(address(instance), ""));
  }
}
