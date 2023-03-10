// SPDX-License-Identifier: BlueOak-1.0.0
pragma solidity 0.8.9;

import "../../libraries/Fixed.sol";
import "./CTokenFiatCollateral.sol";
import "./ICToken.sol";
import "./OracleLib.sol";

/**
 * @title CTokenNonFiatCollateral
 * @notice Collateral plugin for a cToken of nonfiat collateral that requires default checks,
 * like cWBTC. Expected: {tok} != {ref}, {ref} == {target}, {target} != {UoA}
 */
contract CTokenNonFiatCollateral is CTokenFiatCollateral {
    using FixLib for uint192;
    using OracleLib for AggregatorV3Interface;

    AggregatorV3Interface public immutable targetUnitChainlinkFeed; // {UoA/target}

    /// @param config.chainlinkFeed Feed units: {target/ref}
    /// @param targetUnitChainlinkFeed_ Feed units: {UoA/target}
    /// @param comptroller_ The CompoundFinance Comptroller
    constructor(
        CollateralConfig memory config,
        AggregatorV3Interface targetUnitChainlinkFeed_,
        IComptroller comptroller_
    ) CTokenFiatCollateral(config, comptroller_) {
        require(
            address(targetUnitChainlinkFeed_) != address(0),
            "missing target unit chainlink feed"
        );
        targetUnitChainlinkFeed = targetUnitChainlinkFeed_;
    }

    /// Can revert, used by other contract functions in order to catch errors
    /// @param low {UoA/tok} The low price estimate
    /// @param high {UoA/tok} The high price estimate
    /// @param pegPrice {target/ref}
    function tryPrice()
        external
        view
        override
        returns (
            uint192 low,
            uint192 high,
            uint192 pegPrice
        )
    {
        pegPrice = chainlinkFeed.price(oracleTimeout); // {target/ref}

        uint192 pricePerTarget = targetUnitChainlinkFeed.price(oracleTimeout); // {UoA/target}

        // {UoA/tok} = {UoA/target} * {target/ref} * {ref/tok}
        uint192 p = pricePerTarget.mul(pegPrice).mul(refPerTok());

        // this oracleError is already the combined total oracle error
        uint192 delta = p.mul(oracleError);
        low = p - delta;
        high = p + delta;
    }
}
