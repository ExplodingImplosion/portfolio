# StreamPeerBitBuffer
An extension of Godot's native StreamPeerBuffer class, which is used to sequentially read/write data from a generic buffer of bytes. The added functionality includes bitpacking individual booleans, as well as encoding/decoding larger data structures that are commonly serialized like Vector3's. Doesn't support bitpacking non-booleans for simplicity sake. The main focus when first developing the GDScript version of this class was to get bandwidth wins from the lowest-hanging fruit in a short timespan.

Tests were run from the in-game console using the "[test_bit_buffer](https://github.com/ExplodingImplosion/portfolio/blob/bfd3fe2b2e2d84926b5f30334dc6d52bdbccf7c4/GDScript%20utilities%20and%20scripts/utils/console/console_commands.gd#L2005)" command.

# TFMoveComponent

Based on Mickeon's awesome [TF2 movement code](https://github.com/Mickeon/team-fortress-jumper/blob/main/player/Player.gd)!
An extension of Godot's native CharacterBody3D class. Translated from a GDScript version for performance, but most of the potential performance wins would come from changing more of the function itself, such as delving deeper into [PhysicsBody3D::_move()](https://github.com/ExplodingImplosion/godot/blob/abdef80828bf2159fa94fc81656ec05eb92076fe/scene/3d/physics/physics_body_3d.cpp#L87), and/or modifying CharacterBody3D directly instead of calling it from a node component. Currently, it's just translated from GDScript it to C++. While it saves a few μs in the best-case scenario (while the player is mid-air), it barely shaves off any time at all while the player is grounded.

# Build Godot with these classes

Build Godot from source with [this branch](https://github.com/ExplodingImplosion/godot/tree/cpp_example). As a hack to get things into the engine quickly, I modified the [Multiplayer module](https://github.com/ExplodingImplosion/godot/tree/cpp_example/modules/multiplayer/miles). Every script started with a script templated I generated with a codegen GDScript script I built to help me migrate files. My apologies for the commit names.