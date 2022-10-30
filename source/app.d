import std.stdio;

import tinyraycaster;

int wall_x_texcoord(const float x, const float y, ref Texture tex_walls) {
    import std.math : abs, floor;
    import std.conv : to;

    float hitX = x - (x + 0.5).floor;
    float hitY = y - (y + 0.5).floor;
    int textureX = (hitX * tex_walls.size).to!int;
    if (hitY.abs > hitX.abs) {
        textureX = (hitY * tex_walls.size).to!int;
    }
    if (textureX < 0)
        textureX += tex_walls.size; // Allow for python style negative indexing
    assert(textureX >= 0 && textureX < cast(int) tex_walls.size);

    return textureX;
}

void mapShowSprite(ref Sprite sprite, ref FrameBuffer frameBuffer, ref Map map) {
    import std.conv : to;

    const size_t rectangleWidth = frameBuffer.width / (map.width * 2); // Size of a  single map 'cell' on screen
    const size_t rectangleHeight = frameBuffer.height / map.height;
    frameBuffer.drawRectangle((sprite.x * rectangleWidth - 3).to!size_t,
            (sprite.y * rectangleHeight - 3).to!size_t, 6, 6, packColour(255, 0, 0));
}

void drawSprite(ref Sprite sprite, ref float[] depthBuffer,
        ref FrameBuffer frameBuffer, ref Player player, ref Texture spriteTexture) {
    import std.math : atan2, sqrt;
    import std.algorithm.comparison : min;
    import std.math.constants : PI;
    import std.conv : to;

    // Global co-ords direction from the player to the sprite
    float spriteDirection = atan2(sprite.y - player.y, sprite.x - player.x);

    size_t spriteScreenSize = min(1_000, (frameBuffer.height / sprite.playerDistance).to!int);
    int offsetH = (((spriteDirection - player.viewDirection) % (2 * PI)) / player.fov * (
            frameBuffer.width / 2) + (frameBuffer.width / 2) / 2 - spriteTexture.size / 2).to!int;
    int offsetV = (frameBuffer.height.to!float / 2 - spriteScreenSize / 2).to!int;

    foreach (size_t i; 0 .. spriteScreenSize) {
        if ((offsetH + i) < 0 || (offsetH + i) >= frameBuffer.width / 2)
            continue;
        if (depthBuffer[offsetH + i] < sprite.playerDistance)
            continue;
        foreach (size_t j; 0 .. spriteScreenSize) {
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
        ref Sprite[] sprites, ref Texture wallTexture, ref Texture monsterTexture) {
    frameBuffer.clear(white);

    const size_t rectangleWidth = frameBuffer.width / (map.width * 2);
    const size_t rectangleHeight = frameBuffer.height / map.height;

    // Draw map on left-hand side of the screen
    foreach (size_t j; 0 .. map.height) {
        foreach (size_t i; 0 .. map.width) {
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

    // Draw '3D' view, for each pixel across the width of the viewport
    foreach (size_t i; 0 .. frameBuffer.width / 2) {
        // Get angle for each element in the view vector
        float angle = player.viewDirection - player.fov / 2 + player.fov * (
                2.0 * i / frameBuffer.width);
        // Scan forward until we hit something, TODO: Optimize this raycasting a bit more
        for (float t = 0.; t < 20; t += 0.01) {
            float x = player.x + t * cos(angle);
            float y = player.y + t * sin(angle);

            // Draw visibility cone on map viewport
            frameBuffer.setPixel((x * rectangleWidth).to!size_t,
                    (y * rectangleHeight).to!size_t, packColour(160, 160, 160));

            if (map.isEmpty(x.to!size_t, y.to!size_t))
                continue;

            // Draw walls on '3D' viewport
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
            for (size_t j = 0; j < columnHeight; j++) {
                auto pix_y = j + frameBuffer.height / 2 - columnHeight / 2;
                if (pix_y >= 0 && pix_y < frameBuffer.height) {
                    frameBuffer.setPixel(pix_x, pix_y, column[j]);
                }
            }
            break;
        }
    }

    // Update sprite distances to player/camera
    import std.math : sqrt;

    foreach (ref sprite; sprites) {
        sprite.playerDistance = sqrt((sprite.x - player.x) ^^ 2 + (sprite.y - player.y) ^^ 2);
    }

    // Sort from furthest to closest
    import std.algorithm : sort;

    sort!("a > b")(sprites);

    // Draw sprites
    foreach (sprite; sprites) {
        mapShowSprite(sprite, frameBuffer, map);
        drawSprite(sprite, depthBuffer, frameBuffer, player, monsterTexture);
    }
}

import bindbc.sdl;

bool initSDL(ref SDL_Window* window, ref SDL_Renderer* renderer,
        ref SDL_Surface* surface, int windowWidth = 640, int windowHeight = 480) {
    // Load the SDL shared library using well-known variations of the library name for the host system.
    SDLSupport ret = loadSDL();
    version (Windows)
        ret = loadSDL("libs/sdl2.dll");

    if (ret != sdlSupport) {
        if (ret == SDLSupport.noLibrary) {
            stderr.writeln("The SDL shared library failed to load");
        } else if (SDLSupport.badLibrary) {
            stderr.writeln("One or more symbols failed to load. The likely cause is that the shared library is for a lower version than bindbc-sdl was configured to load (via SDL_204, GLFW_2010 etc.)");
        } else {
            stderr.writeln("SDL not supported, but I don't know why, sorry x");
        }
        return false;
    }

    // Initialize SDL
    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        stderr.writeln("SDL could not initialize! SDL_Error: %s\n", SDL_GetError());
        return false;
    }

    window = SDL_CreateWindow("tinyraycaster", SDL_WINDOWPOS_UNDEFINED,
            SDL_WINDOWPOS_UNDEFINED, windowWidth, windowHeight, SDL_WINDOW_SHOWN);
    if (window == null) {
        printf("Window could not be created! SDL_Error: %s\n", SDL_GetError());
        return false;
    }

    //Create renderer for window
    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
    if (renderer == null) {
        printf("Renderer could not be created! SDL Error: %s\n", SDL_GetError());
        return false;
    }
    SDL_SetRenderDrawColor(renderer, 0xFF, 0xFF, 0xFF, 0xFF);

    surface = SDL_GetWindowSurface(window);
    return true;
}

bool loadImage(string filename, ref SDL_Surface* surface) {
    import std.file;

    // Check it could be a valid filename
    if (!filename.exists) {
        stderr.writefln("Filename %s does not exist", filename);
        return false;
    } else if (!filename.isFile) {
        stderr.writefln("Filename %s is not a file");
        return false;
    }

    // Try and load it and see what happens
    import std.conv : to;
    import std.string : toStringz;

    surface = SDL_LoadBMP(filename.to!string.toStringz()); // TODO: Should be a better way of doing this conversion
    if (surface == null) {
        stderr.writefln("Unable to read %s: %s", filename, SDL_GetError());
        return false;
    }

    return true;
}

int run() {
    // Set-up window things
    const windowWidth = 1024;
    const windowHeight = 512;

    // The window we'll be rendering to
    SDL_Window* window;
    // The surface contained by the window
    scope (exit) {
        if (window != null)
            SDL_DestroyWindow(window);
        window = null;
    }

    SDL_Renderer* renderer = null;
    // Destroy renderer on close
    scope (exit) {
        if (renderer != null)
            SDL_DestroyRenderer(renderer);
        renderer = null;
    }

    SDL_Surface* screenSurface;
    // Destroy surface on close
    scope (exit) {
        if (screenSurface != null)
            SDL_FreeSurface(screenSurface);
        screenSurface = null;
    }

    if (!initSDL(window, renderer, screenSurface, windowWidth, windowHeight)) {
        return -1;
    }

    // Do rendering
    import std.math : PI;
    import std.conv : to;

    // Create frame buffer
    FrameBuffer frameBuffer = FrameBuffer(windowWidth, windowHeight,
            new uint[](windowWidth * windowHeight));

    Player player = Player(3.456, 2.345, 1.523, PI / 3, 0, 0);
    Map map;

    // Load texture atlases
    Texture wallTexture = Texture("./source/walltext.png");
    Texture monsterTexture = Texture("./source/monsters.png");
    if (!monsterTexture.count || !wallTexture.count) {
        stderr.writeln("Could not load textures");
        return -1;
    }

    // Monster sprites
    Sprite[] monsterSprites = [
        Sprite(3.523, 3.812, 2, float.infinity),
        Sprite(3.523, 8.765, 0, float.infinity),
        Sprite(1.834, 8.765, 0, float.infinity),
        Sprite(5.323, 5.365, 1, float.infinity),
        Sprite(4.123, 10.265, 1, float.infinity)
    ];

    SDL_Texture* frameBufferTexture = SDL_CreateTexture(renderer,
            SDL_PIXELFORMAT_ABGR8888, SDL_TEXTUREACCESS_STREAMING, windowWidth, windowHeight);

    // Update window now we've updated the surface
    SDL_UpdateWindowSurface(window);

    // Hack the screen to stay open
    SDL_Event event;
    bool quit = false;
    while (quit == false) {
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_QUIT)
                quit = true;
            if (event.type == SDL_KEYDOWN) {
                switch (event.key.keysym.sym) {
                case 'a'.to!SDL_Keycode:
                    player.turn = -1.0;
                    break;
                case 'd'.to!SDL_Keycode:
                    player.turn = 1.0;
                    break;
                case 'w'.to!SDL_Keycode:
                    player.walk = 1.0;
                    break;
                case 's'.to!SDL_Keycode:
                    player.walk = -1.0;
                    break;
                default:
                    break;
                }
            }
            if (event.type == SDL_KEYUP) {
                switch (event.key.keysym.sym) {
                case 'a'.to!SDL_Keycode:
                    player.turn = 0.0;
                    break;
                case 'd'.to!SDL_Keycode:
                    player.turn = 0.0;
                    break;
                case 'w'.to!SDL_Keycode:
                    player.walk = 0.0;
                    break;
                case 's'.to!SDL_Keycode:
                    player.walk = 0.0;
                    break;
                default:
                    break;
                }
            }

            // Move player
            import std.math;

            player.viewDirection += 0.05 * player.turn; // TODO: Change to sensitivity
            float desiredX = player.x + 0.1 * player.walk * cos(player.viewDirection);
            float desiredY = player.y + 0.1 * player.walk * sin(player.viewDirection);

            if (desiredX >= 0.0 && desiredX < map.width.to!float
                    && map.isEmpty(desiredX.to!size_t, desiredY.to!size_t)) {
                player.x = desiredX;
            }
            if (desiredY >= 0.0 && desiredY < map.height.to!float
                    && map.isEmpty(desiredX.to!size_t, desiredY.to!size_t)) {
                player.y = desiredY;
            }

            // Render to frambuffer
            render(frameBuffer, map, player, monsterSprites, wallTexture, monsterTexture);
            SDL_UpdateTexture(frameBufferTexture, null, frameBuffer.image.ptr,
                    (frameBuffer.width * 4).to!int);

            // Clear screen
            SDL_RenderClear(renderer);

            // Render texture to screen
            SDL_RenderCopy(renderer, frameBufferTexture, null, null);

            // Update screen
            SDL_RenderPresent(renderer);
        }
    }
    return 0;
}

int main() {
    // Required to use d's nice scope guards to free before SDL_Quit is run
    int returnVal = run();

    // Quit SDL subsystems
    SDL_Quit();

    return returnVal;
}
