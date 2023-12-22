// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import {IVariableDebtToken} from "@aave/core-v3/contracts/interfaces/IVariableDebtToken.sol";

library DataTypes {
  struct ReserveData {
    ReserveConfigurationMap configuration;
    uint128 liquidityIndex;
    uint128 currentLiquidityRate;
    uint128 variableBorrowIndex;
    uint128 currentVariableBorrowRate;
    uint128 currentStableBorrowRate;
    uint40 lastUpdateTimestamp;
    uint16 id;
    address aTokenAddress;
    address stableDebtTokenAddress;
    address variableDebtTokenAddress;
    address interestRateStrategyAddress;
    uint128 accruedToTreasury;
    uint128 unbacked;
    uint128 isolationModeTotalDebt;
  }

  struct ReserveConfigurationMap {
    uint256 data;
  }
}

contract AaveHelper {

    IPoolAddressesProvider public immutable aaveAddressProvider;
    IPool public immutable aavePool;

    address private immutable daiAddress =
        0xc8c0Cf9436F4862a8F60Ce680Ca5a9f0f99b5ded;
    IERC20 private dai;

    uint256 private constant MAX_INT =
        115792089237316195423570985008687907853269984665640564039457584007913129639935;

    event Borrow_Asset(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint256 referralCode,
        address onBehalfOf
    );
    event Supplied_Liquidity(
        address suppliedToken,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    );

    event Borrow_Error(bytes);

    constructor() {
        aaveAddressProvider = IPoolAddressesProvider(0x4CeDCB57Af02293231BAA9D39354D6BFDFD251e0);
        aavePool = IPool(aaveAddressProvider.getPool());
        dai = IERC20(daiAddress);
    }

function getSupplyApr() public view returns (uint256) {
    uint currentLiquidityRate = aavePool.getReserveData(daiAddress).currentLiquidityRate;
    return currentLiquidityRate / 1e18;
}

    function getBorrowApr() public view returns (uint256) {
        uint currentVariableBorrowRate = aavePool.getReserveData(daiAddress).currentVariableBorrowRate;
         return currentVariableBorrowRate / 1e18;
    }


    function getTokenAddress() public view returns (address) {
        return address(dai);
    }
}