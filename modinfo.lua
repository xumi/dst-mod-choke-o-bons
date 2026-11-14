name = "Choke-o-Bons"
description = "A rare bag of chocolate bonbons, found sparingly across the world. Each bag holds a secret number of treats (1 to 8). Eat one and feel better... until the bag runs dry. Use an empty one and it bites back, then falls apart."
author = "xumi"
version = "0.1.0"
api_version = 10
dst_compatible = true
all_clients_require_mod = true
client_only_mod = false
icon_atlas = "modicon.xml"
icon = "modicon.tex"
forge_compatible = false
server_filter_tags = {}

configuration_options =
{
    {
        name = "",
        label = "Build @BUILD@",
        options = {{description = "", data = 0}},
        default = 0,
    },
    {
        name = "model_variant",
        label = "Model variant (debug)",
        hover = "Click-box experiment: 1 = bigger anim box, 2 = bigger build box, 3 = both bigger",
        options =
        {
            {description = "1 (anim box)", data = 1},
            {description = "2 (build box)", data = 2},
            {description = "3 (both)", data = 3},
        },
        default = 2,
    },
    {
        name = "map_amount",
        label = "Items on the map",
        hover = "How many Choke-o-Bons are scattered across the surface world when it first loads",
        options =
        {
            {description = "A few (3)", data = 3},
            {description = "Some (6)", data = 6},
            {description = "Many (12)", data = 12},
        },
        default = 3,
    },
    {
        name = "drop_chance",
        label = "Mob drop chance",
        hover = "Chance that a pig, a merm or a bunnyman drops a Choke-o-Bon when killed",
        options =
        {
            {description = "0.1%", data = 0.001},
            {description = "0.5%", data = 0.005},
            {description = "1%", data = 0.01},
        },
        default = 0.005,
    },
    {
        name = "pigking_chance",
        label = "Pig King chance",
        hover = "Chance that the Pig King hands out a Choke-o-Bon when you trade him an item",
        options =
        {
            {description = "1%", data = 0.01},
            {description = "3%", data = 0.03},
            {description = "5%", data = 0.05},
        },
        default = 0.01,
    },
}
