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
            if (cx >= imageWidth || cy >= imageHeight)
                continue;
            image[cx + cy * imageWidth] = colour;
        }
    }
}

void main()
{
    // Create frame buffer
    const size_t windowWidth = 1024; // Image Width
    const size_t windowHeight = 512; // Image Height

    uint[] frameBuffer = new uint[](windowHeight * windowWidth);
    frameBuffer[] = packColour(255, 255, 255); // Initialize to white

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

    // TODO: Add some graceful exception handling

    const size_t rectangleWidth = windowWidth / (mapWidth * 2); // Only first half for map rendering
    const size_t rectangleHeight = windowHeight / mapHeight;

    foreach (size_t j; 0 .. mapHeight) {
        foreach (size_t i; 0 .. mapWidth) {
            if (map[j][i] == ' ')
                continue; // i.e., skip empty
            size_t rectangleX = i * rectangleWidth;
            size_t rectangleY = j * rectangleHeight;
            drawRectangle(frameBuffer, windowWidth, windowHeight, rectangleX,
                rectangleY, rectangleWidth, rectangleHeight, packColour(0, 255, 255));
        }
    }

    // Get colours for walls
    import std.random : uniform;

    const size_t numColours = 10;
    uint[numColours] colours;
    foreach (ref colour; colours) {
        colour = packColour(uniform(cast(ubyte) 0, cast(ubyte) 255),
            uniform(cast(ubyte) 0, cast(ubyte) 255), uniform(cast(ubyte) 0, cast(ubyte) 255));
    }

    // Overlay with player's position
    import std.conv : to, roundTo;
    import std.math : cos, sin;
    import std.math.constants : PI;

    float playerX = 3.456;
    float playerY = 2.345;
    float playerViewDirection = 1.523; // Angle from global x-axis in radians
    const float playerFov = 0.333 * PI; // Horizontal FOV in radians

    // Cast a ray from the player
    foreach (size_t i; 0 .. windowWidth / 2) { // Remember we're only using half of the window width now
        float angle = playerViewDirection - (playerFov / 2) + playerFov * i / float(windowWidth / 2);

        for (float c = 0.0; c < 20; c += 0.01) {
            // Get points on map
            float cx = playerX + c * cos(angle);
            float cy = playerY + c * sin(angle);

            // Draw line if keeping on searching
            size_t lineX = (cx * rectangleWidth).roundTo!int;
            size_t lineY = (cy * rectangleHeight).roundTo!int;
            frameBuffer[lineX + lineY * windowWidth] = packColour(160, 160, 160);

            // If we've hit a wall, then draw it in that specific line
            if (map[cy.to!size_t][cx.to!size_t] != ' ') {
                size_t columnHeight = (windowHeight / (c * cos(angle - playerViewDirection)))
                    .to!size_t;
                size_t colourIdx = map[cy.to!size_t][cx.to!size_t] - '0'; // Color idx
                assert(colourIdx < colours.length);
                uint colour = colours[colourIdx];
                drawRectangle(frameBuffer, windowWidth, windowHeight, windowWidth / 2 + i,
                    windowHeight / 2 - columnHeight / 2, 1, columnHeight, colour);
                break;
            }

        }
    }

    // Save framebuffer to image file
    writeP6Image("out.ppm", frameBuffer, windowWidth, windowHeight);
}
