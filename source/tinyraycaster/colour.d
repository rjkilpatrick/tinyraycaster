module tinyraycaster.colour;

import std.stdio;

static uint white() {
    return packColour(255, 255, 255);
}

static uint black() {
    return packColour(0, 0, 0);
}

uint packColour(const ubyte r, const ubyte g, ubyte b, ubyte a = 255u) {
    return (a << 24) + (b << 16) + (g << 8) + r;
}

/++ 
 + Splits uint of colour into four ubytes of each part of the colour separately
 + Params:
 +   colour = Colour
 +   r = (returns) red value of colour
 +   g = (returns) green value of colour
 +   b = (returns) blue value of colour
 +   a = (returns) alpha value of colour
 +/
void unpackColour(const uint colour, ref ubyte r, ref ubyte g, ref ubyte b, ref ubyte a) {
    r = (colour >>> 0) & 0xff;
    g = (colour >>> 8) & 0xff;
    b = (colour >>> 16) & 0xff;
    a = (colour >>> 24) & 0xff;
}

/++ 
 + Creates a P6 formatted image file from the image data
 + Params:
 +   filename = Name of file to write to
 +   image = uint of the image (with a, b, g, r bit-shifting)
 +   width = width of the image (needed to un-linearize the array)
 +   height = height of the image (needed to un-linearize the array)
 +/
void writeP6Image(const string filename, const uint[] image, const int width, const int height) {
    import std.file;
    import std.conv : to;

    auto f = File(filename, "w+");
    scope (exit)
        f.close();
    f.write("P6\n" ~ width.to!string ~ " " ~ height.to!string ~ "\n255\n");

    foreach (uint pixel; image) {
        ubyte r, g, b, a;
        unpackColour(pixel, r, g, b, a);
        f.rawWrite([r, g, b]); // TODO: Surely there's a better way of doing this...
    }
}

/++ 
 + Creates a P3 formatted image file from the image data
 + Params:
 +   filename = Name of file to write to
 +   image = uint of the image (with a, b, g, r bit-shifting)
 +   width = width of the image (needed to un-linearize the array)
 +   height = height of the image (needed to un-linearize the array)
 +/
void writeP3Image(const string filename, const uint[] image, const int width, const int height) {
    import std.file;
    import std.conv : to;

    auto f = File(filename, "w+");
    scope (exit)
        f.close();
    f.write("P3\n" ~ width.to!string ~ " " ~ height.to!string ~ "\n255\n\n");

    foreach (uint pixel; image) {
        ubyte r, g, b, a;
        unpackColour(pixel, r, g, b, a);
        f.write(r, " ", g, " ", b, "\n");
    }
}
