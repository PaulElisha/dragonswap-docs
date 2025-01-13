# Adding Liquidity

Unlike in Dragonswap V1, there is no router contract to interact with the pool. Dragonswap V2 is a composable code, modularized for different purposes. Similar to the V1, the periphery contains code for different interaction purposes.

```solidity
struct AddLiquidityParams {
    address token0;
    address token1;
    uint24 fee;
    address recipient;
    int24 tickLower;
    int24 tickUpper;
    uint256 amount0Desired;
    uint256 amount1Desired;
    uint256 amount0Min;
    uint256 amount1Min;
}

function addLiquidity(AddLiquidityParams memory params)
    internal
    returns (
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1,
        IDragonswapV2Pool pool
    )
{
    PoolAddress.PoolKey memory poolKey =
        PoolAddress.PoolKey({token0: params.token0, token1: params.token1, fee: params.fee});

    pool = IDragonswapV2Pool(PoolAddress.computeAddress(factory, poolKey));

    // compute the liquidity amount
    {
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(params.tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(params.tickUpper);

        liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtRatioAX96,
            sqrtRatioBX96,
            params.amount0Desired,
            params.amount1Desired
        );
    }

    (amount0, amount1) = pool.mint(
        params.recipient,
        params.tickLower,
        params.tickUpper,
        liquidity,
        abi.encode(MintCallbackData({poolKey: poolKey, payer: msg.sender}))
    );

    require(amount0 >= params.amount0Min && amount1 >= params.amount1Min, 'Price slippage check');
}
```

For reference, see LiquidityManagement.sol.

- It gets the pool address using the pool parameter or pool key and computed using create2.

- The current pool price is used to sepcify where liqudity wants to provided to and to check if the pool is in the specified price range.

- The liquidity when adding an amount of either tokens is returned and the minimum is minted as the liquidity using the function below. It is the same as liquidityDelta in the `mint()` function.

```solidity
function getLiquidityForAmounts(
    uint160 sqrtRatioX96,
    uint160 sqrtRatioAX96,
    uint160 sqrtRatioBX96,
    uint256 amount0,
    uint256 amount1
) internal pure returns (uint128 liquidity) {
    if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

    if (sqrtRatioX96 <= sqrtRatioAX96) {
        liquidity = getLiquidityForAmount0(sqrtRatioAX96, sqrtRatioBX96, amount0);
    } else if (sqrtRatioX96 < sqrtRatioBX96) {
        uint128 liquidity0 = getLiquidityForAmount0(sqrtRatioX96, sqrtRatioBX96, amount0);
        uint128 liquidity1 = getLiquidityForAmount1(sqrtRatioAX96, sqrtRatioX96, amount1);

        liquidity = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
    } else {
        liquidity = getLiquidityForAmount1(sqrtRatioAX96, sqrtRatioBX96, amount1);
    }
}
```

The mint function calls `modifyPosition()`.

It also returns the amountDelta, which is the amount equivalent to add the liquidityDelta specified, of both tokens deposited to confirm that there was actually an increase in the tokens balances.

```solidity
function mint(
    address recipient,
    int24 tickLower,
    int24 tickUpper,
    uint128 amount,
    bytes calldata data
) external override lock returns (uint256 amount0, uint256 amount1) {
    require(amount > 0);
    (, int256 amount0Int, int256 amount1Int) =
        _modifyPosition(
            ModifyPositionParams({
                owner: recipient,
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityDelta: int256(amount).toInt128()
            })
        );

    amount0 = uint256(amount0Int);
    amount1 = uint256(amount1Int);

    uint256 balance0Before;
    uint256 balance1Before;
    if (amount0 > 0) balance0Before = balance0();
    if (amount1 > 0) balance1Before = balance1();
    IDragonswapV2MintCallback(msg.sender).DragonswapV2MintCallback(amount0, amount1, data);
    if (amount0 > 0) require(balance0Before.add(amount0) <= balance0(), 'M0');
    if (amount1 > 0) require(balance1Before.add(amount1) <= balance1(), 'M1');

    emit Mint(msg.sender, recipient, tickLower, tickUpper, amount, amount0, amount1);
}
```

The `modifyPosition()` function also calls `updatePosition()` function.

In Dragonswap V2, when liquidity is provided, a position is created which can later be modified or updated.

The checkTick function checks the tick to determine valid tick.

Checks if the liquidity computed which is the liquidityDelta, the liquidity to add, is not zero and if the current pool's tick is in the extreme range. Then it returns the amount0 equivalent for the liquidityDelta to add since the other token have been swapped out.

Then it checks if current pool's tick is in range by comparing against the upper bound tick.

If it is, the computed liquidity (liquidityDelta) is added to the current pool's liquidity ; that is what it means to modify a position.

Before adding liquidityDelta to the current pool's liquidity, we could also make a conditional check like this:

```solidity
liquidity = params.liquidityDelta < 0
                    ? liquidity - uint128(-params.liquidityDelta)
                    : liquidity + uint128(params.liquidityDelta);
```

```solidity
function _modifyPosition(ModifyPositionParams memory params)
    private
    noDelegateCall
    returns (
        Position.Info storage position,
        int256 amount0,
        int256 amount1
    )
{
    checkTicks(params.tickLower, params.tickUpper);

    Slot0 memory _slot0 = slot0; // SLOAD for gas optimization

    position = _updatePosition(
        params.owner,
        params.tickLower,
        params.tickUpper,
        params.liquidityDelta,
        _slot0.tick
    );

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
    }
}
```

The `updatePosition()` function updates the user's position first before updating the tick where liquidity was added.

In Dragonswap V2, when liqudity is provided, a position is created for thee user which can be updated and modified.

So, first we get the position we want to update. A position ID is the hash of the owner, tickLower and tickUpper. If need be to update position, the tickLower and tickUpper would change but while adding liquidity the tickLower and tickUpper specified make up the position. It returns the position info which contains the liquidityDelta added, fees and other info.

Reference link.

Then we check if the liquidity we want to add, the liquidityDelta is not zero then we update the tick.

Tick update is necessary because liquidity is in ticks, and if we would later modify the position, we would get the previous ticks to remove or burn liqudity. The tick update returns a boolean 'flipped' which is true when the total liquidity gets activated from 0 to liquidityDelta or false when the total liquidity is deactivated from liquidityDelta to 0.

Then the position info is updated with the liquidityDelta, fees etc.

- checks if the liquidityDelta to add is zero, it ensures that the previous liquidity is returned as the liquidityNext. Otherwise, the liquidityNext is the addition of the previous liquidity and the current liquidityDelta.

```solidity
        uint128 liquidityNext;
        if (liquidityDelta == 0) {
            require(_self.liquidity > 0, 'NP'); // disallow pokes for 0 liquidity positions
            liquidityNext = _self.liquidity;
        } else {
            liquidityNext = LiquidityMath.addDelta(_self.liquidity, liquidityDelta);
        }
```

- if liquidityDelta is not zero, let's update the liquidityNext (_self.liquidity + liquidityDelta) as the current position liquidity.
```solidity
// update the position
        if (liquidityDelta != 0) self.liquidity = liquidityNext;
```

Reference link

```solidity
function _updatePosition(
        address owner,
        int24 tickLower,
        int24 tickUpper,
        int128 liquidityDelta,
        int24 tick
    ) private returns (Position.Info storage position) {
        position = positions.get(owner, tickLower, tickUpper);

        uint256 _feeGrowthGlobal0X128 = feeGrowthGlobal0X128; // SLOAD for gas optimization
        uint256 _feeGrowthGlobal1X128 = feeGrowthGlobal1X128; // SLOAD for gas optimization

        // if we need to update the ticks, do it
        bool flippedLower;
        bool flippedUpper;
        if (liquidityDelta != 0) {
            uint32 time = _blockTimestamp();
            (int56 tickCumulative, uint160 secondsPerLiquidityCumulativeX128) =
                observations.observeSingle(
                    time,
                    0,
                    slot0.tick,
                    slot0.observationIndex,
                    liquidity,
                    slot0.observationCardinality
                );

            flippedLower = ticks.update(
                tickLower,
                tick,
                liquidityDelta,
                _feeGrowthGlobal0X128,
                _feeGrowthGlobal1X128,
                secondsPerLiquidityCumulativeX128,
                tickCumulative,
                time,
                false,
                maxLiquidityPerTick
            );
            flippedUpper = ticks.update(
                tickUpper,
                tick,
                liquidityDelta,
                _feeGrowthGlobal0X128,
                _feeGrowthGlobal1X128,
                secondsPerLiquidityCumulativeX128,
                tickCumulative,
                time,
                true,
                maxLiquidityPerTick
            );

            if (flippedLower) {
                tickBitmap.flipTick(tickLower, tickSpacing);
            }
            if (flippedUpper) {
                tickBitmap.flipTick(tickUpper, tickSpacing);
            }
        }

        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) =
            ticks.getFeeGrowthInside(tickLower, tickUpper, tick, _feeGrowthGlobal0X128, _feeGrowthGlobal1X128);

        position.update(liquidityDelta, feeGrowthInside0X128, feeGrowthInside1X128);

        // clear any tick data that is no longer needed
        if (liquidityDelta < 0) {
            if (flippedLower) {
                ticks.clear(tickLower);
            }
            if (flippedUpper) {
                ticks.clear(tickUpper);
            }
        }
    }
```