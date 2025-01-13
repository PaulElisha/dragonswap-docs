// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "v3-core/contracts/libraries/FixedPoint96.sol";
import "v3-core/contracts/libraries/FullMath.sol";
import "v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "./lib/Math.sol";

library UniswapV3Helpers {
    /// @notice Calculate the amount of token Y (USDC) needed given token X (ETH) and price bounds.
    /// @param x The amount of token X (ETH) in units.
    /// @param sqrtPriceP The square root of the current price (√P) in Q96 format.
    /// @param sqrtPricePa The square root of the lower price bound (√Pa) in Q96 format.
    /// @param sqrtPricePb The square root of the upper price bound (√Pb) in Q96 format.
    /// @return y The required amount of token Y (USDC) in units.
    function calculateUSDCAmount(
        uint256 x,
        uint160 sqrtPriceP,
        uint160 sqrtPricePa,
        uint160 sqrtPricePb
    ) external pure returns (uint256 y) {
        require(
            sqrtPricePa > 0 && sqrtPriceP > 0 && sqrtPricePb > 0,
            "Invalid prices"
        );

        // Calculate liquidity from x (ETH)
        uint256 liquidityX = FullMath.mulDiv(
            x * FixedPoint96.Q96,
            sqrtPricePb - sqrtPriceP, // √Pb - √P
            uint256(sqrtPricePb) * sqrtPriceP // √Pb * √P
        );

        // Calculate required y (USDC) from liquidity
        y = FullMath.mulDiv(
            liquidityX * FixedPoint96.Q96,
            sqrtPriceP - sqrtPricePa, // √P - √Pa
            uint256(sqrtPriceP) * sqrtPricePa // √P * √Pa
        );

        return y;
    }

    /// @notice Calculate the amount of token X (ETH) needed given token Y (USDC) and price bounds.
    /// @param y The amount of token Y (USDC) in units.
    /// @param sqrtPriceP The square root of the current price (√P) in Q96 format.
    /// @param sqrtPricePa The square root of the lower price bound (√Pa) in Q96 format.
    /// @param sqrtPricePb The square root of the upper price bound (√Pb) in Q96 format.
    /// @return x The required amount of token X (ETH) in units.
    function calculateETHAmount(
        uint256 y,
        uint160 sqrtPriceP,
        uint160 sqrtPricePa,
        uint160 sqrtPricePb
    ) external pure returns (uint256 x) {
        require(
            sqrtPricePa > 0 && sqrtPriceP > 0 && sqrtPricePb > 0,
            "Invalid prices"
        );

        // Calculate liquidity from y (USDC)
        uint256 liquidityY = FullMath.mulDiv(
            y * FixedPoint96.Q96,
            uint256(sqrtPriceP) * sqrtPricePa, // √P * √Pa
            sqrtPriceP - sqrtPricePa // √P - √Pa
        );

        // Calculate required x (ETH) from liquidity
        x = FullMath.mulDiv(
            liquidityY * FixedPoint96.Q96,
            uint256(sqrtPricePb) * sqrtPriceP, // √Pb * √P
            sqrtPricePb - sqrtPriceP // √Pb - √P
        );

        return x;
    }

    /// @notice Calculate the square root of the lower price bound (Pa) given liquidity amounts and upper price bound (Pb).
    /// @param amountX The amount of token X (e.g., ETH).
    /// @param amountY The amount of token Y (e.g., USDC).
    /// @param sqrtPriceB The square root of the upper price bound (√Pb).
    /// @return sqrtPriceA The square root of the lower price bound (√Pa).
    function calculateSqrtPriceA(
        uint256 amountX,
        uint256 amountY,
        uint160 sqrtPriceB
    ) external pure returns (uint160 sqrtPriceA) {
        require(amountX > 0, "Invalid amountX");
        require(amountY > 0, "Invalid amountY");
        require(sqrtPriceB > 0, "Invalid sqrtPriceB");

        // Numerator: amountY * Q96
        uint256 numerator = FullMath.mulDiv(amountY, FixedPoint96.Q96, 1);

        // Denominator: amountY + sqrtPriceB * amountX
        uint256 denominator = FullMath.mulDiv(
            uint256(sqrtPriceB),
            amountX,
            FixedPoint96.Q96
        ) + amountY;

        // sqrtPriceA = numerator / denominator
        sqrtPriceA = uint160(FullMath.mulDiv(numerator, 1, denominator));
    }

    /// @notice Convert a square root price to the actual price.
    /// @param sqrtPrice The square root price.
    /// @return price The actual price.
    function sqrtPriceToPrice(
        uint160 sqrtPrice
    ) external pure returns (uint256 price) {
        // price = (sqrtPrice^2) / Q96^2
        price = FullMath.mulDiv(
            uint256(sqrtPrice),
            uint256(sqrtPrice),
            FixedPoint96.Q96 * FixedPoint96.Q96
        );
    }

    /// @notice Calculate the square root of the upper price bound (Pb) given liquidity amounts and lower price bound (Pa).
    /// @param amountX The amount of token X (e.g., ETH).
    /// @param amountY The amount of token Y (e.g., USDC).
    /// @param sqrtPriceA The square root of the lower price bound (√Pa).
    /// @return sqrtPriceB The square root of the upper price bound (√Pb).
    function calculateSqrtPriceB(
        uint256 amountX,
        uint256 amountY,
        uint160 sqrtPriceA
    ) external pure returns (uint160 sqrtPriceB) {
        require(amountX > 0, "Invalid amountX");
        require(amountY > 0, "Invalid amountY");
        require(sqrtPriceA > 0, "Invalid sqrtPriceA");

        // Numerator: amountY * sqrtPriceA
        uint256 numerator = FullMath.mulDiv(
            amountY,
            uint256(sqrtPriceA),
            FixedPoint96.Q96
        );

        // Denominator: amountX + (amountY / sqrtPriceA)
        uint256 denominator = FullMath.mulDiv(
            uint256(sqrtPriceA),
            amountX,
            FixedPoint96.Q96
        ) + amountY;

        // sqrtPriceB = numerator / denominator
        sqrtPriceB = uint160(
            FullMath.mulDiv(numerator, FixedPoint96.Q96, denominator)
        );
    }

    /// @notice Calculate the updated balances of x and y after a price change.
    /// @param sqrtPriceP The initial square root price (√P) in Q96 format.
    /// @param sqrtPricePPrime The new square root price (√P') in Q96 format.
    /// @param sqrtPricePa The square root of the lower price bound (√Pa) in Q96 format.
    /// @param sqrtPricePb The square root of the upper price bound (√Pb) in Q96 format.
    /// @param liquidity The liquidity (L) of the position in Q96 format.
    /// @return xPrime The updated balance of x (ETH).
    /// @return yPrime The updated balance of y (USDC).
    function calculateAssetsAfterPriceChange(
        uint160 sqrtPriceP,
        uint160 sqrtPricePPrime,
        uint160 sqrtPricePa,
        uint160 sqrtPricePb,
        uint256 liquidity
    ) external pure returns (uint256 xPrime, uint256 yPrime) {
        require(sqrtPriceP > 0, "Invalid sqrtPriceP");
        require(sqrtPricePPrime > 0, "Invalid sqrtPricePPrime");
        require(sqrtPricePa > 0, "Invalid sqrtPricePa");
        require(sqrtPricePb > 0, "Invalid sqrtPricePb");

        // Calculate x' (updated balance of x)
        uint256 numeratorX = FullMath.mulDiv(
            liquidity,
            sqrtPricePb - sqrtPricePPrime,
            FixedPoint96.Q96
        );
        uint256 denominatorX = FullMath.mulDiv(
            sqrtPricePPrime,
            sqrtPricePb,
            FixedPoint96.Q96
        );
        xPrime = FullMath.mulDiv(numeratorX, FixedPoint96.Q96, denominatorX);

        // Calculate y' (updated balance of y)
        uint256 numeratorY = FullMath.mulDiv(
            liquidity,
            sqrtPricePPrime - sqrtPricePa,
            FixedPoint96.Q96
        );
        uint256 denominatorY = FullMath.mulDiv(
            sqrtPricePPrime,
            sqrtPricePa,
            FixedPoint96.Q96
        );
        yPrime = FullMath.mulDiv(numeratorY, FixedPoint96.Q96, denominatorY);
    }

    function calculateTicks(
        int24 tick,
        address _pool
    ) external view returns (int24 tickLower, int24 tickUpper) {
        IUniswapV3Pool pool = IUniswapV3Pool(_pool);
        int24 tickSpacing = pool.tickSpacing();

        // Calculate tickLower by rounding down to the nearest multiple of tickSpacing
        tickLower = (tick / tickSpacing) * tickSpacing;

        // Calculate tickUpper by adding tickSpacing to tickLower
        tickUpper = tickLower + tickSpacing;

        return (tickLower, tickUpper);
    }

    function isLiquidityAvailable(address _pool) external view returns (bool) {
        IUniswapV3Pool pool = IUniswapV3Pool(_pool);

        // Fetch the current tick and liquidity
        (uint160 sqrtPriceX96, int24 tick, , , , , ) = pool.slot0();
        uint128 liquidity = pool.liquidity();

        // Check if liquidity is above the threshold
        if (liquidity <= 0) {
            return false; // Liquidity is near depletion
        }

        // Optionally, check if the current price is near an extreme (tick range)
        int24 tickSpacing = pool.tickSpacing();
        int24 lowerTick = (tick / tickSpacing) * tickSpacing;
        int24 upperTick = lowerTick + tickSpacing;

        if (tick <= lowerTick || tick >= upperTick) {
            return false; // Price is near an extreme, liquidity may be depleted
        }

        return true; // Liquidity is sufficient
    }

    // To protect slippage
    function calculateAmountOutMinimum(
        uint256 amountIn,
        uint256 expectedPrice,
        uint16 slippageTolerance // e.g., 50 for 0.5%
    ) internal pure returns (uint256 amountOutMin) {
        uint256 slippageFactor = (10000 - slippageTolerance);
        return (amountIn * expectedPrice * slippageFactor) / 10000;
    }

    function tickToPrices(
        int24 tick,
        uint8 decimal1,
        uint8 decimal0
    ) public pure returns (uint256 price0, uint256 price1) {
        require(tick != 0, "Tick cannot be zero");

        // Calculate price0 using logarithmic scaling
        uint256 logPrice = Math.logBase(
            uint256(10001) ** uint256(uint24(tick)),
            10001
        ); // 1.0001^tick
        uint256 scaleFactor = uint256(10 ** (decimal1 - decimal0));

        // price0 calculation (using logPrice and scaleFactor)
        price0 = logPrice / scaleFactor;

        // Calculate price1 as the inverse of price0
        price1 = uint256(1e18) / price0; // We use 1e18 to avoid fractional results in price1
    }

    /// @notice Estimate the value of a position in terms of a single token
    /// @param amountX Amount of token X in the position.
    /// @param amountY Amount of token Y in the position.
    /// @param price Current price of token X in terms of token Y.
    /// @return value Total value of the position in terms of token Y.
    function estimatePositionValue(
        uint256 amountX,
        uint256 amountY,
        uint256 price
    ) external pure returns (uint256 value) {
        value = amountY + FullMath.mulDiv(amountX, price, FixedPoint96.Q96);
    }

    /// @notice Calculate fees earned in a position
    /// @param liquidity Liquidity of the position.
    /// @param feeGrowthInsideLastX96 Last recorded fee growth inside the range for token X.
    /// @param feeGrowthInsideLastY96 Last recorded fee growth inside the range for token Y.
    /// @param feeGrowthGlobalX96 Current global fee growth for token X.
    /// @param feeGrowthGlobalY96 Current global fee growth for token Y.
    /// @return feesX Fees earned in token X.
    /// @return feesY Fees earned in token Y.
    function calculateFeesEarned(
        uint128 liquidity,
        uint256 feeGrowthInsideLastX96,
        uint256 feeGrowthInsideLastY96,
        uint256 feeGrowthGlobalX96,
        uint256 feeGrowthGlobalY96
    ) external pure returns (uint256 feesX, uint256 feesY) {
        feesX = FullMath.mulDiv(
            uint256(liquidity),
            feeGrowthGlobalX96 - feeGrowthInsideLastX96,
            FixedPoint96.Q96
        );

        feesY = FullMath.mulDiv(
            uint256(liquidity),
            feeGrowthGlobalY96 - feeGrowthInsideLastY96,
            FixedPoint96.Q96
        );
    }

    /// @notice Calculate the price impact of a given trade size on the pool
    /// @param amountIn Amount of the token being swapped in.
    /// @param sqrtPriceP The current square root price (√P).
    /// @param liquidity The liquidity of the pool.
    /// @return priceImpact The price impact as a percentage (scaled by 1e6).
    function calculatePriceImpact(
        uint256 amountIn,
        uint160 sqrtPriceP,
        uint256 liquidity
    ) external pure returns (uint256 priceImpact) {
        require(amountIn > 0, "Invalid amountIn");
        require(liquidity > 0, "Invalid liquidity");

        // Calculate the new price after the trade
        uint256 amountInScaled = amountIn * FixedPoint96.Q96;
        uint256 newPrice = FullMath.mulDiv(
            uint256(sqrtPriceP),
            liquidity,
            liquidity + amountInScaled
        );

        // Calculate price impact
        uint256 priceDifference = sqrtPriceP > newPrice
            ? sqrtPriceP - newPrice
            : newPrice - sqrtPriceP;

        priceImpact = FullMath.mulDiv(priceDifference, 1e6, sqrtPriceP);
    }

    function calculateNextTicks(
        uint160 currentPrice,
        uint24 tickSpacing
    ) private pure returns (int24 lowerTick, int24 upperTick) {
        int24 currentTick = TickMath.getTickAtSqrtPrice(currentPrice);

        lowerTick = (currentTick / int24(tickSpacing)) * int24(tickSpacing);

        upperTick = lowerTick + int24(tickSpacing);

        require(
            upperTick > lowerTick,
            "Upper tick must be greater than lower tick"
        );
    }
}
