// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

library CometStructs {
  struct AssetInfo {
    uint8 offset;
    address asset;
    address priceFeed;
    uint64 scale;
    uint64 borrowCollateralFactor;
    uint64 liquidateCollateralFactor;
    uint64 liquidationFactor;
    uint128 supplyCap;
  }

  struct UserBasic {
    int104 principal;
    uint64 baseTrackingIndex;
    uint64 baseTrackingAccrued;
    uint16 assetsIn;
    uint8 _reserved;
  }

  struct TotalsBasic {
    uint64 baseSupplyIndex;
    uint64 baseBorrowIndex;
    uint64 trackingSupplyIndex;
    uint64 trackingBorrowIndex;
    uint104 totalSupplyBase;
    uint104 totalBorrowBase;
    uint40 lastAccrualTime;
    uint8 pauseFlags;
  }

  struct UserCollateral {
    uint128 balance;
    uint128 _reserved;
  }

  struct RewardOwed {
    address token;
    uint owed;
  }

  struct TotalsCollateral {
    uint128 totalSupplyAsset;
    uint128 _reserved;
  }
}

interface Comet {
  function baseScale() external view returns (uint);
  function supply(address asset, uint amount) external;
  function withdraw(address asset, uint amount) external;

  function getSupplyRate(uint utilization) external view returns (uint);
  function getBorrowRate(uint utilization) external view returns (uint);

  function getAssetInfoByAddress(address asset) external view returns (CometStructs.AssetInfo memory);
  function getAssetInfo(uint8 i) external view returns (CometStructs.AssetInfo memory);


  function getPrice(address priceFeed) external view returns (uint128);

  function userBasic(address) external view returns (CometStructs.UserBasic memory);
  function totalsBasic() external view returns (CometStructs.TotalsBasic memory);
  function userCollateral(address, address) external view returns (CometStructs.UserCollateral memory);

  function baseTokenPriceFeed() external view returns (address);

  function numAssets() external view returns (uint8);

  function getUtilization() external view returns (uint);

  function baseTrackingSupplySpeed() external view returns (uint);
  function baseTrackingBorrowSpeed() external view returns (uint);

  function totalSupply() external view returns (uint256);
  function totalBorrow() external view returns (uint256);

  function baseIndexScale() external pure returns (uint64);

  function totalsCollateral(address asset) external view returns (CometStructs.TotalsCollateral memory);

  function baseMinForRewards() external view returns (uint256);
  function baseToken() external view returns (address);
}

interface CometRewards {
  function getRewardOwed(address comet, address account) external returns (CometStructs.RewardOwed memory);
  function claim(address comet, address src, bool shouldAccrue) external;
}

interface ERC20 {
  function approve(address spender, uint256 amount) external returns (bool);
  function decimals() external view returns (uint);
}

contract CompoundHelper {
  address public cometAddress;
  uint constant public DAYS_PER_YEAR = 365;
  uint constant public SECONDS_PER_DAY = 60 * 60 * 24;
  uint constant public SECONDS_PER_YEAR = SECONDS_PER_DAY * DAYS_PER_YEAR;
  uint public BASE_MANTISSA;
  uint public BASE_INDEX_SCALE;
  uint constant public MAX_UINT = type(uint).max;


  constructor(address _cometAddress) {
    cometAddress = _cometAddress;
    BASE_MANTISSA = Comet(cometAddress).baseScale();
    BASE_INDEX_SCALE = Comet(cometAddress).baseIndexScale();
  }


  function getSupplyApr() public view returns (uint) {
    Comet comet = Comet(cometAddress);
    uint utilization = comet.getUtilization();
    return comet.getSupplyRate(utilization) * SECONDS_PER_YEAR * 100;
  }


  function getBorrowApr() public view returns (uint) {
    Comet comet = Comet(cometAddress);
    uint utilization = comet.getUtilization();
    return comet.getBorrowRate(utilization) * SECONDS_PER_YEAR * 100;
  }


  function getRewardAprForSupplyBase(address rewardTokenPriceFeed) public view returns (uint) {
    Comet comet = Comet(cometAddress);
    uint rewardTokenPriceInUsd = getCompoundPrice(rewardTokenPriceFeed);
    uint usdcPriceInUsd = getCompoundPrice(comet.baseTokenPriceFeed());
    uint usdcTotalSupply = comet.totalSupply();
    uint baseTrackingSupplySpeed = comet.baseTrackingSupplySpeed();
    uint rewardToSuppliersPerDay = baseTrackingSupplySpeed * SECONDS_PER_DAY * (BASE_INDEX_SCALE / BASE_MANTISSA);
    uint supplyBaseRewardApr = (rewardTokenPriceInUsd * rewardToSuppliersPerDay / (usdcTotalSupply * usdcPriceInUsd)) * DAYS_PER_YEAR;
    return supplyBaseRewardApr;
  }


  function getRewardAprForBorrowBase(address rewardTokenPriceFeed) public view returns (uint) {
    Comet comet = Comet(cometAddress);
    uint rewardTokenPriceInUsd = getCompoundPrice(rewardTokenPriceFeed);
    uint usdcPriceInUsd = getCompoundPrice(comet.baseTokenPriceFeed());
    uint usdcTotalBorrow = comet.totalBorrow();
    uint baseTrackingBorrowSpeed = comet.baseTrackingBorrowSpeed();
    uint rewardToSuppliersPerDay = baseTrackingBorrowSpeed * SECONDS_PER_DAY * (BASE_INDEX_SCALE / BASE_MANTISSA);
    uint borrowBaseRewardApr = (rewardTokenPriceInUsd * rewardToSuppliersPerDay / (usdcTotalBorrow * usdcPriceInUsd)) * DAYS_PER_YEAR;
    return borrowBaseRewardApr;
  }


  function getPriceFeedAddress(address asset) public view returns (address) {
    Comet comet = Comet(cometAddress);
    return comet.getAssetInfoByAddress(asset).priceFeed;
  }

  function getBaseTokenPriceFeed() public view returns (address) {
    Comet comet = Comet(cometAddress);
    return comet.baseTokenPriceFeed();
  }

  function getCompoundPrice(address singleAssetPriceFeed) public view returns (uint) {
    Comet comet = Comet(cometAddress);
    return comet.getPrice(singleAssetPriceFeed);
  }

  function getTvl() public view returns (uint) {
    Comet comet = Comet(cometAddress);

    uint baseScale = 10 ** ERC20(cometAddress).decimals();
    uint basePrice = getCompoundPrice(comet.baseTokenPriceFeed());
    uint totalSupplyBase = comet.totalSupply();

    uint tvlUsd = totalSupplyBase * basePrice / baseScale;

    uint8 numAssets = comet.numAssets();
    for (uint8 i = 0; i < numAssets; i++) {
      CometStructs.AssetInfo memory asset = comet.getAssetInfo(i);
      CometStructs.TotalsCollateral memory tc = comet.totalsCollateral(asset.asset);
      uint price = getCompoundPrice(asset.priceFeed);
      uint scale = 10 ** ERC20(asset.asset).decimals();

      tvlUsd += tc.totalSupplyAsset * price / scale;
    }

    return tvlUsd;
  }


  function isInAsset(uint16 assetsIn, uint8 assetOffset) internal pure returns (bool) {
    return (assetsIn & (uint16(1) << assetOffset) != 0);
  }
}