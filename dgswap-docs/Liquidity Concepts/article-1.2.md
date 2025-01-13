

In Uniswap V3, precision is critical to avoid issues like overflow and rounding errors. Variables requiring high accuracy are represented using 256-bit integers, ensuring they can handle large values without overflow. For example, if arithmetic operations are performed on smaller bit-sized variables, such as 8-bit or 16-bit integers, the risk of overflow increases when calculations exceed their maximum representable values.

Rounding Challenges: Even with 256-bit variables, rounding issues can occur in division operations due to Solidity's inherent limitations with decimal precision. For instance, dividing 5 by 2 in Solidity will yield 2, as it truncates the decimal part, leading to loss of precision.

To address this, Uniswap V3 uses fixed-point arithmetic, which represents fractional numbers as integers. This approach ensures precise calculations by eliminating rounding errors. For example, instead of directly handling decimals, a fractional value like 0.5 might be represented as 500,000 with a defined scaling factor, allowing accurate computation across operations.

By combining 256-bit precision and fixed-point arithmetic, Uniswap V3 ensures reliable and accurate handling of financial computations critical for its operations.

Basics of Fixed-Point Arithmetic

Fixed-point arithmetic is a method for representing fractional numbers as integers by using a fixed number of digits for both the integer and fractional parts. This is achieved through decimal scaling, which converts decimal numbers into integers by multiplying them by a scaling factor (e.g., (10^n), where (n) is the number of fractional digits).

For example:





(1.5 \times 10^2 = 150)



(3.14 \times 10^2 = 314)

These scaled numbers can be stored as integers, ensuring precision by avoiding truncation of decimal parts. When applied to blockchain calculations, this approach eliminates rounding errors commonly associated with division operations that discard fractional components. By scaling numbers to fit within a fixed bit-size (e.g., 256 bits), both the integer and fractional parts are preserved, ensuring accuracy and compatibility with Solidity's computational constraints.

Q Notation and Its Use in Uniswap V3

Uniswap V3 employs Q notation, a fixed-point representation method, to maintain high precision using binary scaling instead of decimal scaling. Q notation allocates a specific number of bits for the integer and fractional parts of a number, enabling precise and efficient computations.

An example in Uniswap V3 is the slot0 struct, which includes the variable sqrtPriceX96. 

    struct Slot0 {
        // the current price
        uint160 sqrtPriceX96;
        // the current tick
        int24 tick;
        // the most-recently updated index of the observations array
        uint16 observationIndex;
        // the current maximum number of observations that are being stored
        uint16 observationCardinality;
        // the next maximum number of observations to store, triggered in observations.write
        uint16 observationCardinalityNext;
        // the current protocol fee as a percentage of the swap fee taken on withdrawal
        // represented as an integer denominator (1/x)%
        uint8 feeProtocol;
        // whether the pool is locked
        bool unlocked;
    }

This variable represents the square root of the price ratio scaled using Q notation (specifically, Q96), where 96 bits are allocated to the fractional part. To ensure compactness and efficiency, sqrtPriceX96 is stored as a 160-bit variable, allowing the entire slot0 structure—along with other critical pool parameters—to fit within 32 bytes.

By leveraging Q notation and fixed-point arithmetic, Uniswap V3 achieves:





Granular control over decimal precision, preserving accuracy in mathematical operations.



Efficient bit usage, optimizing storage and computational overhead.

This design highlights Uniswap’s commitment to precision and performance, particularly in handling complex calculations for liquidity provision and trading operations.

Q Notation  Further Explanation

In Q notation, numbers are represented as fixed-point values by allocating specific bits to the integer and fractional parts:





n: Number of bits for the integer part.



m: Number of bits for the fractional part.

For example, in Q8.8, 8 bits are used for the integer part, and 8 bits for the fractional part, resulting in a total of 16 bits to represent the number.

Example: Representing 1.5 in Q8.8





Integer Part:
(1 ) in 8 bits: (0000_0001) = (256) (scaled by (2^8)).



Fractional Part:
(0.5 \times 2^8 = 128).
(128) in 8 bits: (1000_0000).



Combined Representation:
(256 + 128 = 384) in Q notation.

Alternatively, you can calculate it directly:
[1.5 \times 2^8 = 384.]

Q96 in Uniswap V3

In Uniswap V3, sqrtPriceX96 uses Q96 notation, where the fractional part is scaled by 96 bits, effectively shifting the decimal point far to the right. The total 256-bit representation is split as follows:





96 bits: Fractional part.



160 bits: Integer part ((256 - 96 = 160)).

This ensures that the entire fixed-point value fits within 256 bits, avoiding overflow and maintaining precision. It also optimizes storage in the slot0 struct by compacting pool parameters into a single 32-byte slot.