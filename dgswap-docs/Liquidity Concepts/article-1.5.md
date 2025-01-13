# Price Curve in Dragonswap V2

Dragonswap V2 introduces a more efficient model for liquidity distribution compared to Dragonswap V2. In V1, liquidity is spread across all price points in the price curve according to the constant product formula, ( x \times y = k ), where x is the reserve of token A, y is the reserve of token B, and k is a constant representing the pool's liquidity, making liquidity even. This means that liquidity is available at all price points, from the minimum 0 to the maximum ∞.

However, this approach results in inefficient use of liquidity, especially at price points where there is little to no trading activity. For example, liquidity is available at extreme high and low prices, but it’s unlikely that trades will occur there. This inefficiency is what led to the creation of Dragonswap V2's concentrated liquidity model.

Dragonswap V2 introduces a price curve which models that of Dragonswap V1 but with a key difference: liquidity is not evenly distributed across all price ranges. This is because a Dragonswap V2 pool is divided into ticks which bounds price forming a mini v2-pool. So liquidity is only distributed in a specific price range according to the constant product formula, ( x \times y = k ), where x is the reserve of token A, y is the reserve of token B, and k is a constant. This makes liquidity usage more capital-efficient by ensuring that liquidity is focused on price ranges with higher trading activity, rather than being spread thin across all possible prices. The essence of this is that in a V1 pool, since price has been distributed, the amount traded at a specific price point does not reflect the liquidity deposited but in a V2 pool the amount traded in a V2 pool reflects the liquidity deposited making it concentrated.

## Difference Between Dragonswap V2 Price Curve and Dragonswap V2 Virtual Curve

The key difference between the Dragonswap V2 Price Curve and the Dragonswap V2 Virtual Curve lies in the distribution of liquidity across price ranges, and how liquidity is used during trades. Let’s break down these differences clearly:

### Liquidity Distribution:





`Dragonswap V1 Price Curve:`





Liquidity Distribution: In V1, liquidity is evenly distributed across all price points. The constant product formula ( x * y = k ) ensures that liquidity is available at every possible price along the curve, from extremely low to extremely high prices.



Inefficiency: Since liquidity is evenly spread across all prices, much of it is allocated to areas where there is little to no trading activity (i.e., extreme high or low prices). This can lead to inefficient capital usage.



`Dragonswap V2 Virtual Curve:`





Liquidity Distribution: In V2, liquidity is concentrated within specific price ranges selected by liquidity providers. Instead of spreading liquidity across the entire curve, liquidity is only available within the price ranges that liquidity providers choose, making the system more capital-efficient.



Efficiency: V2's virtual curve enables liquidity providers to concentrate their liquidity within a price range, which maximizes their capital efficiency and reduces the amount of capital needed to provide meaningful liquidity.

## Liquidity in Dragonswap V2

Like I said earlier that in a V1 pool, liquidity is evenly distributed across all price points in a price curve from 0 to ∞, so liquidity is always at the current price but the amount of assets traded at a specific price doesn’t necessarily reflect the actual liquidity deposited. When swap occur the amount of liquidity is determined if either of the reserve is near depletion (where price is at extreme).

In contrast, a Dragonswap V2 pool is segmented into bounds of tick and liquidity exists in a price range. If price is at the extreme (where the range is either token is near depletion) then the amount of liquidity can be denominated in token B and vice versa but if price is not at the extreme, the amount of liquidity is in both tokens.

In the code below, `liquidityDelta` is the liquidity we want to either provide to the pool or remove from the pool. But then as said that extreme prices determine the amount of liquidity as liquidity could be denominated in either both tokens, token0 or token1.

The extreme prices was determined by checking if the current pool tick is outside the Lowertick, that is when price is at the extreme, liqudity will be denominated in token0 and that is why we could only get amount0 out as the optimal amount of liqudityDelta to add if price reaches that point, and vice versa if price is outside the Uppertick, we can only get the optimal amount of tokens to provide.

The middle ground is we can get an optimal amount of token0 and token1 to provide should be equivalent to liquidityDelta if liquidity is not at extreme prices.

See the code below:

```solidity
if (params.liquidityDelta != 0) {
            if (_slot0.tick < params.tickLower) {
                // current tick is below the passed range; liquidity can only become in range by crossing from left to
                // right, when we'll need _more_ token0 (it's becoming more valuable) so user must provide it
                amount0 = SqrtPriceMath.getAmount0Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower),
                    TickMath.getSqrtRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                );
            } else if (_slot0.tick < params.tickUpper) {
                // current tick is inside the passed range
                uint128 liquidityBefore = liquidity; // SLOAD for gas optimization

                // write an oracle entry
                (slot0.observationIndex, slot0.observationCardinality) = observations.write(
                    _slot0.observationIndex,
                    _blockTimestamp(),
                    _slot0.tick,
                    liquidityBefore,
                    _slot0.observationCardinality,
                    _slot0.observationCardinalityNext
                );

                amount0 = SqrtPriceMath.getAmount0Delta(
                    _slot0.sqrtPriceX96,
                    TickMath.getSqrtRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                );
                amount1 = SqrtPriceMath.getAmount1Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower),
                    _slot0.sqrtPriceX96,
                    params.liquidityDelta
                );

                liquidity = LiquidityMath.addDelta(liquidityBefore, params.liquidityDelta);
            } else {
                // current tick is above the passed range; liquidity can only become in range by crossing from right to
                // left, when we'll need _more_ token1 (it's becoming more valuable) so user must provide it
                amount1 = SqrtPriceMath.getAmount1Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower),
                    TickMath.getSqrtRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                );
            }
```

Reference link.

If a swap is to occur at the extreme prices, we can see that the amount in the pool is the total amount deposited but denominated in token0 or token1. Since upon swaps, the other token depletes till it gets to the point where trading could no longer occur.

## Extreme Prices

The price when either of the tokens in a pool is near depletion when swap occur.

### Example:

If 10,000 DAI and 10 ETH is available in ETH/DAI pool. 

The constant is 100,000, k = x * y

Price of ETH expressed in terms of DAI = 10,000 / 10 = 1,000 DAI / ETH.

As a result of swap, if the amount of ETH depletes to 5 ETH, the price of ETH in terms of DAI is 20,000 DAI. This is an extreme price.



The amount of liquidity ( x and y) at an extreme price determine the trading that can happen.

This is exactly how liquidity works in Dragonswap V2; but extreme prices are defined in bounds in a price range (lower and upper bound). Unlike in the Dragonswap V1, the pool’s reserve determines the natural bound for trading because it is not fragmented into ticks, the extreme prices that determine trading are determined implicitly by the constant product function (x * y = k).

The V2 bounds are - the lower and upper bound.


The lower bound - where token X is always high and token Y is near zero.
The upper bound - where token Y is always high and token X is near zero.


The amount of assets available for trading near the boundaries matches the total deposited liquidity in that range.

Extreme Prices and Imbalance liquidity is one of the major causes of slippage. Slippage happens when a user wants to trade a tiny amount of asset at an extreme price in the lower range.

The code below shows how V2 protect slippage:

```solidity
// places a limit on the price to ensure that it doesn't cross to the extreme price

uint160 sqrtPriceLimitX96
```

```solidity
// it checks that the sqrtPrice is within the minimum and maximum sqrt ratio at that tick

sqrtPriceLimitX96 > TickMath.MIN_SQRT_RATIO
sqrtPriceLimitX96 < TickMath.MAX_SQRT_RATIO
```

Reference link.

If a developer integrating V2 in an application wants to control slippage, the code below works:

```solidity
    // To protect slippage
    function calculateAmountOutMinimum(
        uint256 amountIn,			// amount of input token
        uint256 expectedPrice,		// output per input token 	
        uint16 slippageTolerance	// 50 for 0.5% or 100 for 1%
    ) internal pure returns (uint256 amountOutMin) {
        uint256 slippageFactor = (10000 - slippageTolerance);
        return (amountIn * expectedPrice * slippageFactor) / 10000;
    }

function executeTradeWithSlippageProtection(
        IDragonswapV2Router router,
        ExactInputSingleParams memory params,
        uint256 expectedPrice,
        uint16 slippageTolerance
    ) internal returns (uint256 amountOut) {
        // Calculate minimum acceptable output
        params.amountOutMinimum = calculateAmountOutMinimum(
            params.amountIn,
            expectedPrice,
            slippageTolerance
        );

        // Call the router's exactInputSingle function
        amountOut = router.exactInputSingle(abi.encode(params));
        require(amountOut >= params.amountOutMinimum, "Slippage exceeded");
    }
```

## Example of Price Approaching the Lower Bound:

Let’s say the price of ETH/DAI is 1,000 DAI/ETH, and this is the lower bound of the active range:





At this point, most of the liquidity in the pool is held in ETH because DAI has been swapped out.



As traders continue to sell DAI for ETH, the pool’s virtual liquidity diminishes because there is less DAI left.



Price slippage increases as the price moves closer to the lower bound.

## Example of Price Approaching the Upper Bound:

If the price of ETH/DAI is 2,000 DAI/ETH, which is the upper bound:





Most of the liquidity in the pool is held in DAI because ETH has been swapped out.



As traders buy ETH using DAI, the pool’s liquidity in ETH diminishes.



Price slippage increases significantly as the price moves toward the upper bound.

## A Scenario:

Consider a liquidity provider who deposits:





10 ETH and 20,000 DAI into a range where the price is between 1,000 DAI/ETH and 2,000 DAI/ETH.

If the price approaches the lower bound (1,000 DAI/ETH):





Most of the liquidity in the pool will be held in ETH, because DAI will have been mostly swapped out.



As the price moves toward the lower bound, the pool will have little DAI left, reflecting the depletion of liquidity in this price range.



Price slippage will increase as the price nears the lower bound.

On the other hand, if the price moves toward the upper bound (2,000 DAI/ETH):





Most of the liquidity will be held in DAI, because ETH will have been mostly swapped out.



As the price moves toward the upper bound, liquidity will be depleted in ETH, and price slippage will increase as fewer ETH tokens remain in the pool.



If the price approaches the boundaries of a liquidity range, the pool's ability to facilitate trades diminishes because liquidity becomes scarce.

## Liquidity Amounts in Dragonswap V2

In Dragonswap V2, liquidity is determined both from virtual reserves and real reserves. Both approaches should yield the same liquidity calculation, but the methods differ in terms of how they handle price ranges and the liquidity behavior at different price levels.

- Liquidity from Virtual Reserves

Liquidity based on virtual reserves simulates how liquidity behaves at different price points, even in ranges where liquidity has not yet been provided by liquidity providers. This approach models the distribution of liquidity across price ranges.

The liquidity calculation from virtual reserves is as follows:

[ L_{\text{virtual}} = x_{\text{virtual}} \times y_{\text{virtual}} ]

Where:





( x_{\text{virtual}} ) is the virtual reserve of token X at the current price.



( y_{\text{virtual}} ) is the virtual reserve of token Y at the current price.

The virtual reserves are determined by the current price ( p' ), the lower price bound ( p_l ), and the upper price bound ( p_u ). These virtual reserves simulate liquidity behavior and how much liquidity would be available if the price moved into that range.

-  Liquidity from Real Reserves

Liquidity based on real reserves is calculated using the actual reserves of tokens that liquidity providers have deposited in the pool. This formula calculates the liquidity available within a specific price range.





`Liquidity for Token X is calculated as:`

[ L_x = x \times \frac{p' - p_l}{p_u - p_l} ]

Where:





( x ) is the amount of token X provided by the liquidity provider.



( p' ) is the current price (in terms of token X to token Y).



( p_l ) is the lower price bound of the range.



( p_u ) is the upper price bound of the range.

This formula determines how much liquidity for token X is available in the price range between ( p_l ) and ( p_u ).





`Liquidity for Token Y is calculated as:`

[ L_y = y \times \frac{p_u - p'}{p_u - p_l} ]

Where:





( y ) is the amount of token Y provided by the liquidity provider.



( p' ) is the current price (in terms of token X to token Y).



( p_l ) is the lower price bound of the range.



( p_u ) is the upper price bound of the range.

## Liquidity Calculation Formula in Dragonswap V2

The liquidity calculation in Dragonswap V2 can be done using both real reserves and virtual reserves, with the following formulas:

- Liquidity Formula Using Virtual Reserves:

The liquidity ( L ) in a given price range is determined by the virtual reserves of token X and token Y. This can be expressed as:

[ L = \sqrt{x_{\text{virtual}} \times y_{\text{virtual}}} ]

Where:





( x_{\text{virtual}} ) and ( y_{\text{virtual}} ) are the virtual reserves for token X and token Y, respectively, at the current price.

``The relationship between the virtual reserves and the real reserves is as follows:``

\[
L^2 = x_{\text{virtual}} \times y_{\text{virtual}}
\]

Where ( x ) and ( y ) are the real reserves for token X and token Y, respectively.

To determine the virtual reserves, we use:

\[
x_{\text{virtual}} = x_{\text{real}} + \frac{L}{\sqrt{p_b}}
\]

Where:





( x_{\text{real}} ) and ( y_{\text{real}} ) are the real reserves of token X and token Y.



( p_a ) and ( p_b ) are the lower and upper bounds of the price range, respectively.

When expanded, the relationship becomes:

[ L^2 = \left( x_{\text{real}} + \frac{L}{\sqrt{p_b}} \right) \times \left( y_{\text{real}} + L \sqrt{p_a} \right) ]

- Liquidity When Token X is Deposited:

When token X is deposited in the liquidity pool, the liquidity ( L ) for token X within a specific price range can be calculated as:

[ L = x \left( \frac{\sqrt{p_b} \cdot \sqrt{p_a}}{\sqrt{p_b} - \sqrt{p_a}} \right) ]

Where:





( x ) is the amount of token X deposited.



( p_a ) is the lower price bound.



( p_b ) is the upper price bound.

```solidity
    // Function to calculate liquidity when token X is deposited
    function liquidityWhenXDeposited(
        uint256 x,
        uint256 pA,
        uint256 pB
    ) public pure returns (uint256) {
        uint256 sqrtPB = sqrt(pB);
        uint256 sqrtPA = sqrt(pA);

        // Ensure that pB > pA to avoid division by zero
        require(sqrtPB > sqrtPA, "pB must be greater than pA");

        uint256 numerator = sqrtPB * sqrtPA;
        uint256 denominator = sqrtPB - sqrtPA;

        return (x * numerator) / denominator;
    }

	    // Helper function to calculate the square root
    function sqrt(uint256 a) internal pure returns (uint256) {
        uint256 x = a;
        uint256 y = (x + 1) / 2;
        while (y < x) {
            x = y;
            y = (x + a / x) / 2;
        }
        return x;
    }
```

For a better implementation, refer to the LiquidityAmounts.sol library in the Dragonswap V2 Core repository.

`Amount of Token X Deposited:`

To determine how much of token X is deposited for a given liquidity ( L ), we use the formula:

[ x = L \left( \frac{\sqrt{p_b} - \sqrt{p_a}}{\sqrt{p_a} \times \sqrt{p_b}} \right) ]

```solidity
    // Function to calculate the amount of token X deposited
    function amountOfXDeposited(
        uint256 L,
        uint256 pA,
        uint256 pB
    ) public pure returns (uint256) {
        uint256 sqrtPB = sqrt(pB);
        uint256 sqrtPA = sqrt(pA);

        // Ensure that pB > pA to avoid division by zero
        require(sqrtPB > sqrtPA, "pB must be greater than pA");

        uint256 numerator = sqrtPB - sqrtPA;
        uint256 denominator = sqrtPA * sqrtPB;

        return (L * numerator) / denominator;
    }
```

For a better implementation, refer to the LiquidityAmounts.sol library in the Dragonswap V2 Core repository.

- Amount of Token Y Deposited:

Similarly, to determine how much of token Y is deposited for a given liquidity ( L ), we use:

[ y = L \left( p_b - p_a \right) ]

```solidity
    // Function to calculate the amount of token Y deposited
    function amountOfYDeposited(
        uint256 L,
        uint256 pA,
        uint256 pB
    ) public pure returns (uint256) {
        return L * (pB - pA);
    }
```

For a better implementation, refer to the LiquidityAmounts.sol library in the Dragonswap V2 Core repository.

- Liquidity When Token Y is Deposited:

When token Y is deposited, the liquidity ( L ) for token Y within a specific price range can be calculated as:

[ L = \frac{y}{\sqrt{p_b - p_a}} ]

Where:





( y ) is the amount of token Y deposited.



( p_a ) and ( p_b ) are the lower and upper bounds of the price range, respectively.

```solidity
    // Function to calculate liquidity when token Y is deposited
    function liquidityWhenYDeposited(
        uint256 y,
        uint256 pA,
        uint256 pB
    ) public pure returns (uint256) {
        require(pB > pA, "pB must be greater than pA");
        return y / (pB - pA);
    }
```

For a better implementation, refer to the LiquidityAmounts.sol library in the Dragonswap V2 Core repository.

These formulas allow for calculating liquidity within a specific price range for both token X and token Y, depending on whether the liquidity is being calculated using real or virtual reserves.

Note: The same expression used to calculate the amount of tokens deposited is used to get the delta amounts. The difference is that it rounds up and is good for swap if we want to get the amountIn, we will go into the details in the swap section.

```solidity
    function getAmount0Delta(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity,
        bool roundUp
    ) internal pure returns (uint256 amount0) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        uint256 numerator1 = uint256(liquidity) << FixedPoint96.RESOLUTION;
        uint256 numerator2 = sqrtRatioBX96 - sqrtRatioAX96;

        require(sqrtRatioAX96 > 0);

        return
            roundUp
                ? UnsafeMath.divRoundingUp(
                    FullMath.mulDivRoundingUp(numerator1, numerator2, sqrtRatioBX96),
                    sqrtRatioAX96
                )
                : FullMath.mulDiv(numerator1, numerator2, sqrtRatioBX96) / sqrtRatioAX96;
    }
```

Reference link.

```solidity
    function getAmount1Delta(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity,
        bool roundUp
    ) internal pure returns (uint256 amount1) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        return
            roundUp
                ? FullMath.mulDivRoundingUp(liquidity, sqrtRatioBX96 - sqrtRatioAX96, FixedPoint96.Q96)
                : FullMath.mulDiv(liquidity, sqrtRatioBX96 - sqrtRatioAX96, FixedPoint96.Q96);
    }
```

Reference link.
