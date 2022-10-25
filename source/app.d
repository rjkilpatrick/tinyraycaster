import std.stdio;

import tinyraycaster;

void main() {
	import std.conv : to;

	const size_t windowWidth = 512; // Image Width
	const size_t windowHeight = 512; // Image Height

	uint[] frameBuffer = new uint[](windowHeight * windowWidth);
	frameBuffer[] = 0xffu; // Initialize to red

	// Create colour gradients
	foreach (size_t j; 0 .. windowHeight) {
		foreach (size_t i; 0 .. windowWidth) {
			ubyte r = (255u * j / float(windowHeight)).to!ubyte;
			ubyte g = (255u * i / float(windowWidth)).to!ubyte;
			ubyte b = 0u;
			frameBuffer[i + j * windowWidth] = packColour(r, g, b);
		}
	}

	writeP6Image("out.ppm", frameBuffer, windowWidth, windowHeight);
}
