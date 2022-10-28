module tinyraycaster.framebuffer;

struct FrameBuffer
{
    size_t width, height;
    uint[] image;

    void clear(const uint colour)
    {
        image[] = colour;
    }

    void setPixel(const size_t x, const size_t y, const uint colour)
    in (image.length == width * height)
    {
        image[x + y * width] = colour;
    }

    void drawRectangle(const size_t rectangleX, const size_t rectangleY,
            const size_t rectangleWidth, const size_t rectangleHeight, const uint colour)
    in (image.length == width * height)
    {
        foreach (size_t i; 0 .. rectangleWidth)
        {
            foreach (size_t j; 0 .. rectangleHeight)
            {
                size_t cx = rectangleX + i;
                size_t cy = rectangleY + j;
                if (cx < width && cy < height)
                {
                    setPixel(cx, cy, colour);
                }
            }
        }
    }
}
