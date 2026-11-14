name = "Choke-o-Bons"
description = "A rare bag of chocolate bonbons, found sparingly across the world. Each bag holds a secret number of treats (1 to 8). Eat one and feel better... until the bag runs dry, and then it bites back."
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
        name = "world_density",
        label = "Map density",
        hover = "How often Choke-o-Bons are placed during world generation",
        options =
        {
            {description = "Very rare", data = 0.0005},
            {description = "Rare", data = 0.001},
            {description = "Less rare", data = 0.003},
        },
        default = 0.001,
    },
    {
        name = "drop_chance",
        label = "Random drop chance",
        hover = "Chance that any creature or object that drops loot also drops a Choke-o-Bon",
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
            {description = "Off", data = 0},
            {description = "0.5%", data = 0.005},
            {description = "1%", data = 0.01},
            {description = "3%", data = 0.03},
        },
        default = 0.005,
    },
}
