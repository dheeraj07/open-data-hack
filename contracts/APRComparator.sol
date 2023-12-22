// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract APRComparator {
    CompoundHelper compoundHelper;
    AaveHelper aaveHelper;

    constructor(address _compoundHelperAddress, address _aaveHelperAddress) {
        compoundHelper = CompoundHelper(_compoundHelperAddress);
        aaveHelper = AaveHelper(_aaveHelperAddress);
    }

    function getBestSupplyApr() public view returns (uint256) {
        uint256 compoundApr = compoundHelper.getSupplyApr();
        uint256 aaveApr = aaveHelper.getSupplyApr();

        return compoundApr > aaveApr ? compoundApr : aaveApr;
    }

    function getBestBorrowApr() public view returns (uint256) {
        uint256 compoundApr = compoundHelper.getBorrowApr();
        uint256 aaveApr = aaveHelper.getBorrowApr();

        return compoundApr < aaveApr ? compoundApr : aaveApr;
    }
}
