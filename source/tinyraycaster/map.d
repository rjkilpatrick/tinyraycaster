module tinyraycaster.map;

struct Map
{
    // size_t width, height;
    // // this(size_t width=16, size_t height=16)
    // // {
    // //     this.width = width;
    // //     this.height = height;

    // //     assert(map.length == mapHeight);
    // //     assert(map[0].length == mapWidth);
    // // }

    @property size_t height()
    {
        return map.length;
    }

    @property size_t width()
    {
        return map[0].length;
    }

    int get(const size_t i, const size_t j)
    in (i < width)
    in (j < height)
    {
        return map[j][i] - '0';
    }

    bool isEmpty(const size_t i, const size_t j)
    in (i < width)
    in (j < height)
    {
        return map[j][i] == ' ';
    }
}

// dfmt off
private static const string[] map = [
    "0000222222220000",
    "1              0",
    "1      11111   0",
    "1     0        0",
    "0     0  1110000",
    "0     3        0",
    "0   10000      0",
    "0   3   11100  0",
    "5   4   0      0",
    "5   4   1  00000",
    "0       1      0",
    "2       1      0",
    "0       0      0",
    "0 0000000      0",
    "0              0",
    "0002222222200000",
];
// dfmt on
