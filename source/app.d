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

void mapShowSprite(ref Sprite sprite, ref FrameBuffer frameBuffer, ref Map map)
{
    import std.conv : to;

    const size_t rectangleWidth = frameBuffer.width / (map.width * 2); // Size of a  single map 'cell' on screen
    const size_t rectangleHeight = frameBuffer.height / map.height;
    frameBuffer.drawRectangle((sprite.x * rectangleWidth - 3).to!size_t,
            (sprite.y * rectangleHeight - 3).to!size_t, 6, 6, packColour(255, 0, 0));
}

void drawSprite(ref Sprite sprite, ref float[] depthBuffer,
        ref FrameBuffer frameBuffer, ref Player player, ref Texture spriteTexture)
{
    import std.math : atan2, sqrt;
    import std.algorithm.comparison : min;
    import std.math.constants : PI;
    import std.conv : to;

    // Global co-ords direction from the player to the sprite
    float spriteDirection = atan2(sprite.y - player.y, sprite.x - player.x);
    float spriteDistance = sqrt((sprite.x - player.x) ^^ 2 + (sprite.y - player.y) ^^ 2);

    size_t spriteScreenSize = min(1_000, (frameBuffer.height / spriteDistance).to!int);
    int offsetH = (((spriteDirection - player.viewDirection) % (2 * PI)) / player.fov * (
            frameBuffer.width / 2) + (frameBuffer.width / 2) / 2 - spriteTexture.size / 2).to!int;
    int offsetV = (frameBuffer.height / 2 - spriteScreenSize / 2).to!int;

    foreach (size_t i; 0 .. spriteScreenSize)
    {
        if ((offsetH + i) < 0 || (offsetH + i) >= frameBuffer.width / 2)
            continue;
        if (depthBuffer[offsetH + i] < spriteDistance)
            continue;
        foreach (size_t j; 0 .. spriteScreenSize)
        {
            if ((offsetV + j) < 0 || (offsetV + j) >= frameBuffer.height)
                continue;
            uint colour = spriteTexture.get(i * spriteTexture.size / spriteScreenSize,
                    j * spriteTexture.size / spriteScreenSize, sprite.textureId);
            ubyte r, g, b, a;
            unpackColour(colour, r, g, b, a);
            if (a > 128)
                frameBuffer.setPixel(frameBuffer.width / 2 + offsetH + i, offsetV + j, colour);
        }
    }
}

void render(ref FrameBuffer frameBuffer, ref Map map, ref Player player,
        ref Sprite[] sprites, ref Texture wallTexture, ref Texture monsterTexture)
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

    // Set up depth buffer
    float[] depthBuffer = new float[](frameBuffer.width / 2);
    depthBuffer[] = float.infinity;

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

            float distance = (t * cos(angle - player.viewDirection));
            depthBuffer[i] = distance;

            size_t columnHeight = (frameBuffer.height / distance).to!size_t;
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

    foreach (sprite; sprites)
    {
        mapShowSprite(sprite, frameBuffer, map);
        drawSprite(sprite, depthBuffer, frameBuffer, player, monsterTexture);
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

    // Load texture atlases
    Texture wallTexture = Texture("./source/walltext.png");
    Texture monsterTexture = Texture("./source/monsters.png");
    if (!monsterTexture.count || !wallTexture.count)
    {
        stderr.writeln("Could not load textures");
        return -1;
    }

    // Monster sprites
    Sprite[] monsterSprites = [
        Sprite(1.834, 8.765, 0), Sprite(5.323, 5.365, 1), Sprite(4.123, 10.265, 1)
    ];

    // Render to frambuffer
    render(frameBuffer, map, player, monsterSprites, wallTexture, monsterTexture);

    // Save frame buffer to image file
    writeP6Image("out.ppm", frameBuffer.image, windowWidth, windowHeight);

    return 0;
}
