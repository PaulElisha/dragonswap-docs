# Tick and Tick Spacing

Ticks are discrete points along the price range in a Dragonswap V2 pool. They serve multiple purposes:





- Define specific price ranges for liquidity.



- Determine if liquidity is active based on whether the pool's current price falls within a selected tick or tick range.

## Role of Ticks in Dragonswap V2

In Dragonswap V1, liquidity is distributed uniformly across the entire price curve, which reduces capital efficiency. In contrast, Dragonswap V2 allows liquidity providers (LPs) to concentrate their liquidity within specific price ranges, creating mini-pools (equivalent to V1-like pools) at each price range. These mini-pools improve capital efficiency by ensuring liquidity is active only within the selected price range.

## Tick Representation

A tick is a specific value used to represent a price point in a pool. To calculate the price corresponding to a particular tick:
[ \text{Price} = 1.001^{\text{tick}} ]

This method defines prices in discrete steps, allowing for granular control over liquidity ranges.

Price Calculation: Ticks vs. sqrtPriceX96

In Dragonswap V2, prices can be calculated using either ticks or sqrtPriceX96. The two methods are complementary:





- Ticks: Define prices using discrete steps along the price range ((1.001^\text{tick})).



- sqrtPriceX96: Represents the square root of the price scaled to 96 bits for high precision.

Both methods are valid, but their usage depends on the specific context within the pool.

```solidity
    function tickToPrice(int24 tick) internal pure returns (uint160 price) {
        // The function `getSqrtRatioAtTick` in Dragonswap V2 is conceptually related to calculating the price at a given tick, but it serves a different purpose and operates differently compared to the simpler `tickToPrice` function provided. Here's how they differ and align:

        // The `getSqrtRatioAtTick` function is tailored for Dragonswap V2's design, where:
        // - Liquidity Math**: The square root of the price ratio is used directly in liquidity and fee calculations to save computational resources.
        // - Fixed-point Representation**: The Q96.96 format is a compact and precise way to represent fractional values, balancing gas cost and accuracy.

        // How `getSqrtRatioAtTick` Implements \( P = 1.0001^{\text{tick}} \):
        // 1. Precomputed Constants**:
        //    - The constants like `0xfffcb933bd6fad37aa2d162d1a594001` correspond to \( \sqrt{1.0001^i} \) for various powers \( i \), precomputed to avoid on-chain floating-point operations.
        //    - The function iteratively multiplies these constants based on the binary representation of `tick`.

        // 2. Handling Negative Ticks**:
        //    - If `tick < 0`, the reciprocal is taken by dividing `type(uint256).max` by the computed ratio.

        // 3. Q128.96 Conversion**:
        //    - The final result is scaled down from Q128.128 to Q96.96 by right-shifting \( 32 \) bits and ensuring rounding consistency.

        // - `tickToPrice`** is simpler, directly implementing \(P = 1.0001^tick) and suitable for general use cases or basic price calculations.
        // - `getSqrtRatioAtTick`** is highly optimized for Dragonswap V2's internal math, focusing on \( \sqrt{1.0001^{\text{tick}}} \) in Q96.96 format for advanced DeFi applications.

        require(tick >= 0, "Tick must be non-negative");

        // Constants
        uint256 logBase = 10001; // Represents 1.0001 * 10^4 (scaling factor for precision)

        // Convert tick to log(1.0001^tick)
        uint256 logPrice = logBase(
            uint256(1e18) * uint256(10001) ** tick,
            logBase
        );

        // Return the result as a price (scaled back to fixed-point)
        price = uint160(logPrice);
    }

	function logBase(uint256 x, uint256 base) internal pure returns (uint256) {
        require(x > 0 && base > 1, "Invalid input");
        uint256 result = 0;
        while (x >= base) {
            x /= base;
            result++;
        }
        // Adjust for precision
        return result * 1e18 + (x * 1e18) / base;
    }
```

For a better implementation, refer to the TickMath.sol library in the Dragonswap V2 Core repository.

## Deriving Tick from Price in Dragonswap V2

In Dragonswap V2, the tick represents a discrete price point and can also be calculated from the price. The price-tick relationship is as follows:
[ \text{Price} = 1.0001^{\text{tick}} ]

Calculating Tick from Price

If the price is given, you can derive the tick using the formula:
[ \text{tick} = \frac{\log\left((\text{sqrtPriceX96} \cdot Q96)^2\right)}{\log(1.0001)} ]

Where:





sqrtPriceX96: The square root of the price scaled by (2^{96}).



Q96: The scaling factor for fixed-point precision in Dragonswap V2 ((2^{96})).





`Price and sqrtPriceX96 Relationship:`
The price can be computed as:
[ \text{Price} = \left(\frac{\text{sqrtPriceX96}}{Q96}\right)^2 ]



`Deriving the Tick:`
Rearranging the formula for price, the tick is calculated by taking the logarithm of the squared ratio of sqrtPriceX96 to (Q96) and dividing it by the logarithm of (1.0001).

```solidity
    function priceToTick(
        uint160 sqrtPriceX96
    ) public pure returns (int24 tick) {
        // Step 1: Calculate the price (sqrtPriceX96 / Q96)^2
        uint256 priceSquared = (uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) /
            Q96;

        // Step 2: Calculate the tick by taking the logarithm base 1.0001 of price
        // To avoid direct log calculation, we use an iterative method or approximations for logs

        // Using a simple approximation of log(1.0001) = 0.00004342 (from known values)
        require(priceSquared > 0, "Price must be greater than 0");

        // Constants
        uint256 logBase = 10001; // 1.0001 scaled by 10^4
        uint256 logPrice = logBase(priceSquared, logBase);

        int256 result = int256(logPrice / logBase);
        tick = int24(result);
    }
```

For a better implementation, refer to the TickMath.sol library in the Dragonswap V2 Core repository.

## Ticks and Price Ranges in Dragonswap V2

Ticks divide the entire price curve into discrete steps, creating defined price ranges. Each tick corresponds to a specific price point, calculated as:
[ \text{Price at Tick (t)} = 1.0001^t ]

Tick-Based Price Ranges

Ticks form contiguous price ranges, enabling liquidity to be allocated efficiently:





Tick1: Price1 = (1.0001^{t1})



Tick2: Price2 = (1.0001^{t2})

A price range is defined as:
[ \text{Price1} < \text{Price} < \text{Price2} ]

Liquidity providers (LPs) can allocate liquidity to specific tick boundaries, concentrating their capital within these predefined price ranges.

## How Ticks Enable Concentrated Liquidity





- Liquidity Allocation:





LPs choose tick boundaries to define the price range for their liquidity.



Liquidity is active only when the pool's price falls within the selected range.



- Trading Within a Tick Range:





Trades that occur within a tick range consume liquidity in that range.



As the price moves outside the range, it crosses to the next tick, activating liquidity in the adjacent range.



- Efficient Capital Utilization:





By concentrating liquidity in active price ranges, ticks minimize capital inefficiency compared to evenly distributing liquidity across the entire price curve.



This reduces fragmented liquidity, making trading more efficient.

## Ticks in Dragonswap V2

The Tick.sol library is a library with some implementation details. 

It includes:

- Tick Info: details about a particular tick.

liquidityGross - total liquidity in a tick.
liquidityNet - the liquidity added or removed from that tick. When liquidity is added to the lowerTick, it adds a liquidityNet that is positive, otherwise it removes a liquidityNet that is negative at the upperTick. It is the amount of tokens between a price range as the price changess.
initialized - whether the tick is activated or not. It is based on whether the liquidityGross is 0

```solidity
    // info stored for each initialized individual tick
    struct Info {
        // the total position liquidity that references this tick
        uint128 liquidityGross;
        // amount of net liquidity added (subtracted) when tick is crossed from left to right (right to left),
        int128 liquidityNet;
        // fee growth per unit of liquidity on the _other_ side of this tick (relative to the current tick)
        // only has relative meaning, not absolute — the value depends on when the tick is initialized
        uint256 feeGrowthOutside0X128;
        uint256 feeGrowthOutside1X128;
        // the cumulative tick value on the other side of the tick
        int56 tickCumulativeOutside;
        // the seconds per unit of liquidity on the _other_ side of this tick (relative to the current tick)
        // only has relative meaning, not absolute — the value depends on when the tick is initialized
        uint160 secondsPerLiquidityOutsideX128;
        // the seconds spent on the other side of the tick (relative to the current tick)
        // only has relative meaning, not absolute — the value depends on when the tick is initialized
        uint32 secondsOutside;
        // true iff the tick is initialized, i.e. the value is exactly equivalent to the expression liquidityGross != 0
        // these 8 bits are set to prevent fresh sstores when crossing newly initialized ticks
        bool initialized;
    }

```

- maxLiquidityPerTick: This is the maximum liquidity that can be added to a tick. Simply by substracting the min tick from the max tick, we identify the range of marked ticks. Dividing the range by the tick soacing will return the number of tick.

Since liquidity is of type uint128, max liquidity is the max of uint128 - type(uint128).max

Max liquidity for each tick is type(uint128).max / number of ticks

```solidity
    function tickSpacingToMaxLiquidityPerTick(int24 tickSpacing) internal pure returns (uint128) {
        int24 minTick = (TickMath.MIN_TICK / tickSpacing) * tickSpacing;
        int24 maxTick = (TickMath.MAX_TICK / tickSpacing) * tickSpacing;
        uint24 numTicks = uint24((maxTick - minTick) / tickSpacing) + 1;
        return type(uint128).max / numTicks;
    }
```
Reference link.

- `update()` function: It is used to update the tick by updating the tick info struct. 

It gets the liquidityGrossBefore and add the liqudityDelta to return the liqudityGrossAfter.

If liqudityGrossBefore is zero, that is the liquidity hasn't been initialized before, then it initializes it and moves the tick from left to right.

```solidity
        if (liquidityGrossBefore == 0) {
            // by convention, we assume that all growth before a tick was initialized happened _below_ the tick
            if (tick <= tickCurrent) {
                info.feeGrowthOutside0X128 = feeGrowthGlobal0X128;
                info.feeGrowthOutside1X128 = feeGrowthGlobal1X128;
                info.secondsPerLiquidityOutsideX128 = secondsPerLiquidityCumulativeX128;
                info.tickCumulativeOutside = tickCumulative;
                info.secondsOutside = time;
            }
            info.initialized = true;
        }    
```

Otherwise, it updates the liquidityGrossAfter in the tick info. If the liquidityGrossAfter moves from 0 to a value, then tick is added lower and updates the liqudityNet by adding to it. If the liquidityGrossAfter moves from a value to 0, then tick is removed upper and updates the liquidityNet by removing liquidity.

The code below explains it, if liquidity is added upper, we are adding a negative liquidityNet otherwise, we are adding a positive liquidityNet.

```solidity

        info.liquidityGross = liquidityGrossAfter;

        // when the lower (upper) tick is crossed left to right (right to left), liquidity must be added (removed)
        info.liquidityNet = upper
            ? int256(info.liquidityNet).sub(liquidityDelta).toInt128()
            : int256(info.liquidityNet).add(liquidityDelta).toInt128();

```

- `cross()` function: It crosses the next tick based on price movement. It crosses the tick from left to right when liquidity is added and right to left when liquidity is removed.

The next tick is calculated before crossing it. We can calculate the next tick based on price movement using the helper function below:

```solidity
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
```


# Tick-Spacing in Dragonswap V2

Tick-spacing refers to the interval between two ticks, which defines the granularity of price ranges in a Dragonswap V2 pool. When a pool is created, it is initialized with a specific tick-spacing, determining the space between two consecutive ticks. This interval specifies where liquidity can be added or removed and directly affects the precision of price ranges.

### How Tick-Spacing Works.





Tick-spacing defines the gap between two ticks, which in turn determines the price range where liquidity can be placed.



Each price range is defined by two ticks:





tickLower (t1): The lower bound of the price range.



tickUpper (t2): The upper bound of the price range.

Thus, tick-spacing governs how far apart the ticks are, and by extension, defines the price range over which liquidity can be concentrated.

Example: Price Range Between Two Ticks

For example, consider the following:





tickLower (t1) = 100:
(\text{Price}_{\text{lower}} = 1.0001^{100})



tickUpper (t2) = 200:
(\text{Price}_{\text{upper}} = 1.0001^{200})

The price range between these two ticks would be:
[ [\text{Price}{\text{lower}}, \text{Price}{\text{upper}}] ]

This defines the interval in which liquidity can be added or removed within the pool.

