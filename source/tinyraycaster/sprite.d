module tinyraycaster.sprite;

struct Sprite
{
    float x, y; // Position
    size_t textureId;
    float playerDistance; // Why does this belong to the Sprite?

    float opCmp()(auto ref const Sprite rhs) const
    {
        return playerDistance - rhs.playerDistance;
    }
}

unittest
{
    // Ignore that there could not exist a position where this player distance would physically be
    assert(Sprite(0, 0, 0, 1.5) > Sprite(0, 0, 0, 0.5));
    assert(Sprite(0, 0, 0, 1.5) == Sprite(0, 0, 0, 1.5));
    assert(Sprite(0, 0, 0, 1.5) < Sprite(0, 0, 0, 4.5));
}
