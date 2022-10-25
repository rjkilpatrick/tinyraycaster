import std.stdio;

import tinyraycaster;

void drawRectangle(ref uint[] image, const size_t imageWidth, const size_t imageHeight,
        const size_t x, const size_t y, const size_t width, const size_t height, const uint colour)
{
    foreach (size_t i; 0 .. width)
    {
        foreach (size_t j; 0 .. height)
        {
            size_t cx = x + i;
            size_t cy = y + j;
            assert(cx < imageWidth && cy < imageHeight);
            image[cx + cy * imageWidth] = colour;
        }
    }
}

void main()
{
    import std.conv : to;

    const size_t windowWidth = 512; // Image Width
    const size_t windowHeight = 512; // Image Height

    uint[] frameBuffer = new uint[](windowHeight * windowWidth);
    frameBuffer[] = 0xffu; // Initialize to red

    // Create colour gradients
    foreach (size_t j; 0 .. windowHeight)
    {
        foreach (size_t i; 0 .. windowWidth)
        {
            ubyte r = (255u * j / float(windowHeight)).to!ubyte;
            ubyte g = (255u * i / float(windowWidth)).to!ubyte;
            ubyte b = 0u;
            frameBuffer[i + j * windowWidth] = packColour(r, g, b);
        }
    }

    // Overlay game map
    const size_t mapWidth = 16; // map width
    const size_t mapHeight = 16; // map height
    const string[] map = [
        // dfmt off
        "0000222222220000",
		"1              0",
		"1      11111   0",
        "1     0        0",
		"0     0  1110000",
		"0     3        0",
        "0   10000      0",
		"0   0   11100  0",
		"0   0   0      0",
        "0   0   1  00000",
		"0       1      0",
		"2       1      0",
        "0       0      0",
		"0 0000000      0",
		"0              0",
        "0002222222200000",
		// dfmt on
    ];

    assert(map.length == mapHeight);
    assert(map[0].length == mapWidth);

    // TODO: Add some graceful handling

    const size_t rectangleWidth = windowWidth / mapWidth;
    const size_t rectangleHeight = windowWidth / mapHeight;
    foreach (size_t j; 0 .. mapHeight)
    {
        foreach (size_t i; 0 .. mapWidth)
        {
            if (map[j][i] == ' ')
                continue; // i.e., skip empty
            size_t rectangleX = i * rectangleWidth;
            size_t rectangleY = j * rectangleHeight;
            drawRectangle(frameBuffer, windowWidth, windowHeight, rectangleX,
                    rectangleY, rectangleWidth, rectangleHeight, packColour(0, 255, 255));
        }
    }

    // Overlay with player's position
    import std.conv : to;
    import std.math : cos, sin;

    float playerX = 3.456;
    float playerY = 2.345;
    float playerViewDirection = 1.523; // Angle from global x-axis in radians

    drawRectangle(frameBuffer, windowWidth, windowWidth, (playerX * rectangleWidth)
            .to!size_t, (playerY * rectangleHeight).to!size_t, 5, 5, packColour(255, 255, 255));

    // Cast a ray from the player
    float c = 0.0;
    for (; c < 20; c += 0.05)
    {
        // Get points on map
        float cx = playerX + c * cos(playerViewDirection);
        float cy = playerY + c * sin(playerViewDirection);

        // If no hit, keep searching
        if (map[cy.to!size_t][cx.to!size_t] != ' ')
            break; // Hit found

        // Draw line if keeping on searching
        size_t lineX = (cx * rectangleWidth).to!size_t;
        size_t lineY = (cy * rectangleHeight).to!size_t;
        frameBuffer[lineX + lineY * windowWidth] = packColour(255, 255, 255);
    }

    // Save framebuffer to image file
    writeP6Image("out.ppm", frameBuffer, windowWidth, windowHeight);
}
