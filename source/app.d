import std.stdio;

import tinyraycaster;

int wall_x_texcoord(const float x, const float y, ref Texture tex_walls)
{
    import std.math : abs, floor;
    import std.conv : to;

    float hitX = x - (x + 0.5).floor;
    float hitY = y - (y + 0.5).floor;
    int textureX = (hitX * tex_walls.size).to!int;
    if (hitY.abs > hitX.abs)
    {
        textureX = (hitY * tex_walls.size).to!int;
    }
    if (textureX < 0)
        textureX += tex_walls.size; // Allow for python style negative indexing
    assert(textureX >= 0 && textureX < cast(int) tex_walls.size);

    return textureX;
}

void render(ref FrameBuffer frameBuffer, ref Map map, ref Player player, ref Texture wallTexture)
{
    frameBuffer.clear(white);

    const size_t rectangleWidth = frameBuffer.width / (map.width * 2);
    const size_t rectangleHeight = frameBuffer.height / map.height;

    // Draw map on left-hand side of the screen
    foreach (size_t j; 0 .. map.height)
    {
        foreach (size_t i; 0 .. map.width)
        {
            if (map.isEmpty(i, j))
                continue;

            const size_t rectangleX = i * rectangleWidth;
            const size_t rectangleY = j * rectangleHeight;
            const size_t textureId = map.get(i, j);

            assert(textureId < wallTexture.count);
            const colour = wallTexture.get(0, 0, textureId);

            frameBuffer.drawRectangle(rectangleX, rectangleY, rectangleWidth,
                    rectangleHeight, colour);
        }
    }

    // Draw visility cone and raycasted view
    import std.math : cos, sin;
    import std.conv : to;

    foreach (size_t i; 0 .. frameBuffer.width / 2)
    {
        float angle = player.viewDirection - player.fov / 2 + player.fov * (
                2.0 * i / frameBuffer.width);
        for (float t = 0.; t < 20; t += 0.01)
        {
            float x = player.x + t * cos(angle);
            float y = player.y + t * sin(angle);

            // Draw visibility cone
            frameBuffer.setPixel((x * rectangleWidth).to!size_t,
                    (y * rectangleHeight).to!size_t, packColour(160, 160, 160));

            if (map.isEmpty(x.to!size_t, y.to!size_t))
                continue;

            size_t textureId = map.get(x.to!size_t, y.to!size_t); // our ray touches a wall, so draw the vertical column to create an illusion of 3D
            assert(textureId < wallTexture.count);

            size_t columnHeight = (frameBuffer.height / (t * cos(angle - player.viewDirection)))
                .to!size_t;
            int x_texcoord = wall_x_texcoord(x, y, wallTexture);
            uint[] column = wallTexture.getScaledColumn(textureId, x_texcoord, columnHeight);

            // we are drawing at the right half of the screen, thus +frameBuffer.w/2
            auto pix_x = i + frameBuffer.width / 2;

            // Copy texture column to framebuffer
            for (size_t j = 0; j < columnHeight; j++)
            {
                auto pix_y = j + frameBuffer.height / 2 - columnHeight / 2;
                if (pix_y >= 0 && pix_y < frameBuffer.height)
                {
                    frameBuffer.setPixel(pix_x, pix_y, column[j]);
                }
            }
            break;
        }
    }
}

int main()
{
    import std.math : PI;
    import std.conv : to;

    // Create frame buffer
    const windowWidth = 1024;
    const windowHeight = 512;
    FrameBuffer frameBuffer = FrameBuffer(windowWidth, windowHeight,
            new uint[](windowWidth * windowHeight));

    Player player = Player(3.456, 2.345, 1.523, PI / 3);
    Map map;
    Texture wallTexture = Texture("./source/walltext.png");
    if (!wallTexture.count)
    {
        stderr.writeln("Could not load textures of walls");
        return -1;
    }

    int frameCount = 50;
    foreach (size_t frame; 0 .. frameCount)
    {
        render(frameBuffer, map, player, wallTexture);
        // Save frame buffer to image file
        writeP6Image("out" ~ frame.to!string ~ ".ppm", frameBuffer.image, windowWidth, windowHeight);
        player.viewDirection += 2.0 * PI / frameCount;
    }

    return 0;
}
