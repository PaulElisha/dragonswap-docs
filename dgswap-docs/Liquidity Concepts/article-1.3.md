

In Dragonswap V2, the price of a token is determined by the quotient of token reserves in a liquidity pool.

Example: Calculating Price

Consider a liquidity pool with the following reserves:





Reserve of Token A (X): 1000



Reserve of Token B (Y): 500

Price of Token A in terms of Token B:
[ \text{Price} = \frac{Y}{X} = \frac{500}{1000} = 0.5 ]

sqrtPrice and sqrtPriceX96 in Dragonswap V2

Dragonswap V2 uses the square root of the price (sqrtPrice) for efficient and precise computation.





Calculate sqrtPrice:
[ \text{sqrtPrice} = \sqrt{\text{Price}} = \sqrt{0.5} \approx 0.707 ]



Convert sqrtPrice to sqrtPriceX96:
[ \text{sqrtPriceX96} = \text{sqrtPrice} \times 2^{96}
]

Reference link to Dragonswap Q96

	uint256 public constant Q96 = 0x100000000000000000000000000000000; // binary representation of Q96    

This scaled representation ensures high precision and fits within 256 bits.

Converting sqrtPriceX96 Back to Price

To calculate the price from sqrtPriceX96:
[ \text{Price} = \left( \frac{\text{sqrtPriceX96}}{2^{96}} \right)^2 ]


// Calculate the price using the formula
price = (uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) / Q96;

Adjusting for Token Decimals

To display the price as it would appear on an exchange, factor in the decimals of the tokens:
[ \text{Adjusted Price} = \frac{\text{Price}}{10^{(\text{decimal token0} - \text{decimal token1})}} ]

For example, if token A has 18 decimals and token B has 6 decimals:
[ \text{Adjusted Price} = \frac{\text{Price}}{10^{(18 - 6)}} = \frac{\text{Price}}{10^{12}} ]

uint256 scaleFactor = uint256(10 ** (decimal1 - decimal0));
// price0 calculation (using logPrice and scaleFactor)
price0 = price / scaleFactor;

Inverse Price

To calculate the inverse price (price of Token B in terms of Token A):
[ \text{Actual Price} = \frac{1}{\text{Price}} ]

This gives the amount of Token B required to buy 1 unit of Token A.

price1 = uint256(1e18) / price0;