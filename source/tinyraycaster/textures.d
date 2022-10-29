module tinyraycaster.textures;

import std.stdio;

import tinyraycaster;

struct Texture {
    size_t imageWidth, imageHeight;
    size_t count, size;
    uint[] textureBuffer;

    this(const string filename) {
        import gamut;

        Image image;
        image.loadFromFile(filename);
        if (image.errored) {
            import std.conv : to;

            stderr.writeln(image.errorMessage.to!string);
            return;
        }

        if (!image.hasData) {
            stderr.writeln("Error: Texture file has no data");
            return;
        }

        if (image.type != PixelType.rgba8) {
            stderr.writeln("Error: Texture file must be a rgba8 file");
            return;
        }

        imageHeight = image.height;
        imageWidth = image.width;
        count = image.width / image.height;
        size = image.width / count;

        if (image.width != image.height * count) {
            stderr.writeln(
                    "Error: Texture file must contain N square textures packed horizontally");
            return;
        }

        textureBuffer = new uint[](image.height * image.width);
        for (int y = 0; y < image.height(); y++) {
            ubyte* scanline = image.scanline(y);
            for (int x = 0; x < image.width(); x++) {
                ubyte r = scanline[4 * x + 0];
                ubyte g = scanline[4 * x + 1];
                ubyte b = scanline[4 * x + 2];
                ubyte a = scanline[4 * x + 3];
                textureBuffer[y * image.width + x] = packColour(r, g, b, a);
            }
        }
    }

    uint get(const size_t i, const size_t j, const size_t idx)
    in (i < size)
    in (j < size)
    in (idx < count) {
        return textureBuffer[idx * size + j * imageWidth + i];
    }

    uint[] getScaledColumn(const size_t textureId, const size_t textureCoordinate,
            const size_t columnHeight)
    in (textureCoordinate < size)
    in (textureId < count) {

        uint[] column = new uint[](columnHeight);
        foreach (size_t y; 0 .. columnHeight) {
            size_t pixelX = textureId * size + textureCoordinate;
            size_t pixelY = (y * size) / columnHeight;
            column[y] = textureBuffer[pixelX + pixelY * imageWidth];
        }
        return column;
    }
}
