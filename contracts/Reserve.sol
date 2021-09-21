

pragma solidity >=0.5.0 <0.7.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./ReserveInterface.sol";
import "./libraries/SafeERC20.sol";

/// @title Interface that allows a user to draw an address using an index
contract Reserve is OwnableUpgradeable, ReserveInterface {

  using SafeERC20 for IERC20;
  event ReserveRateMantissaSet(uint256 rateMantissa);

  uint256 public rateMantissa;

  constructor () public {
    __Ownable_init();
  }

  function setRateMantissa(
    uint256 _rateMantissa
  )
    external
    onlyOwner
  {
    require(_rateMantissa<3e16,"Too high rate");
    rateMantissa = _rateMantissa;

    emit ReserveRateMantissaSet(rateMantissa);
  }

  function withdrawReserve(address token, address to,uint256 amount) external onlyOwner {
    IERC20(token).safeTransfer(to, amount);
  }

  function reserveRateMantissa(address) external view override returns (uint256) {
    return rateMantissa;
  }
}
