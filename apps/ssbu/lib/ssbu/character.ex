defmodule SSBU.Character do
  @enforce_keys [:name, :icon]
  defstruct [:name, :icon]

  @names [
    "Banjo & Kazooie",
    "Bayonetta",
    "Bowser",
    "Byleth",
    "Captain Falcon",
    "Chrom",
    "Cloud",
    "Corrin",
    "Daisy",
    "Dark Pit",
    "Dark Samus",
    "Diddy Kong",
    "Donkey Kong",
    "Dr. Mario",
    "Duck Hunt",
    "Falco",
    "Fox",
    "Ganondorf",
    "Greninja",
    "Hero",
    "Ice Climbers",
    "Ike",
    "Incineroar",
    "Inkling",
    "Isabelle",
    "Jigglypuff",
    "Joker",
    "Kazuya",
    "Ken",
    "King Dedede",
    "King K. Rool",
    "Kirby",
    "Koopaling",
    "Link",
    "Little Mac",
    "Lucario",
    "Lucas",
    "Lucina",
    "Luigi",
    "Mario",
    "Marth",
    "Mega Man",
    "Meta Knight",
    "Mewtwo",
    "Mii Brawler",
    "Mii Gunner",
    "Mii Swordfighter",
    "Min Min",
    "Mr. Game & Watch",
    "Ness",
    "Olimar",
    "Pac-Man",
    "Palutena",
    "Peach",
    "Pichu",
    "Pikachu",
    "Piranha Plant",
    "Pit",
    "Pokemon Trainer",
    "Pyra & Mythra",
    "R.O.B.",
    "Richter",
    "Ridley",
    "Robin",
    "Rosalina & Luma",
    "Roy",
    "Ryu",
    "Samus",
    "Sephiroth",
    "Sheik",
    "Shulk",
    "Simon",
    "Snake",
    "Sonic",
    "Sora",
    "Steve",
    "Terry",
    "Toon Link",
    "Villager",
    "Wario",
    "Wii Fit Trainer",
    "Wolf",
    "Yoshi",
    "Young Link",
    "Zelda",
    "Zero Suit Samus"
  ]

  def names(), do: @names

  def lookup({head, tail}) do
    lookup(head, tail)
  end

  def lookup(head, tail) do
    internal_lookup(String.downcase(head), String.downcase(tail))
  end

  defp internal_lookup("000001" <> _, _),
    do: %__MODULE__{
      name: "Dr. Mario",
      icon: "https://www.ssbwiki.com/images/7/78/DrMarioHeadSSBU.png"
    }

  # Mario and Cat Mario
  defp internal_lookup("0000" <> _, _),
    do: %__MODULE__{name: "Mario", icon: "https://www.ssbwiki.com/images/0/0d/MarioHeadSSBU.png"}

  defp internal_lookup("0001" <> _, _),
    do: %__MODULE__{name: "Luigi", icon: "https://www.ssbwiki.com/images/c/c6/LuigiHeadSSBU.png"}

  # Peach and Cat Peach
  defp internal_lookup("0002" <> _, _),
    do: %__MODULE__{name: "Peach", icon: "https://www.ssbwiki.com/images/d/d2/PeachHeadSSBU.png"}

  defp internal_lookup("0003" <> _, _),
    do: %__MODULE__{name: "Yoshi", icon: "https://www.ssbwiki.com/images/0/03/YoshiHeadSSBU.png"}

  defp internal_lookup("0004" <> _, _),
    do: %__MODULE__{
      name: "Rosalina & Luma",
      icon: "https://www.ssbwiki.com/images/e/e8/RosalinaHeadSSBU.png"
    }

  defp internal_lookup("0005" <> _, _),
    do: %__MODULE__{
      name: "Bowser",
      icon: "https://www.ssbwiki.com/images/b/b5/BowserHeadSSBU.png"
    }

  defp internal_lookup("0006" <> _, _),
    do: %__MODULE__{
      name: "Koopaling",
      icon: "https://www.ssbwiki.com/images/0/07/BowserJrHeadSSBU.png"
    }

  defp internal_lookup("0007" <> _, _),
    do: %__MODULE__{name: "Wario", icon: "https://www.ssbwiki.com/images/0/05/WarioHeadSSBU.png"}

  defp internal_lookup("0008" <> _, _),
    do: %__MODULE__{
      name: "Donkey Kong",
      icon: "https://www.ssbwiki.com/images/b/ba/DonkeyKongHeadSSBU.png"
    }

  defp internal_lookup("0009" <> _, _),
    do: %__MODULE__{
      name: "Diddy Kong",
      icon: "https://www.ssbwiki.com/images/3/36/DiddyKongHeadSSBU.png"
    }

  defp internal_lookup("0013" <> _, _),
    do: %__MODULE__{name: "Daisy", icon: "https://www.ssbwiki.com/images/9/96/DaisyHeadSSBU.png"}

  defp internal_lookup("0024" <> _, _),
    do: %__MODULE__{
      name: "Piranha Plant",
      icon: "https://www.ssbwiki.com/images/3/38/PiranhaPlantHeadSSBU.png"
    }

  defp internal_lookup("00c0" <> _, _),
    do: %__MODULE__{
      name: "King K. Rool",
      icon: "https://www.ssbwiki.com/images/d/de/KingKRoolHeadSSBU.png"
    }

  defp internal_lookup("0580" <> _, _),
    do: %__MODULE__{name: "Fox", icon: "https://www.ssbwiki.com/images/0/04/FoxHeadSSBU.png"}

  defp internal_lookup("0581" <> _, _),
    do: %__MODULE__{name: "Falco", icon: "https://www.ssbwiki.com/images/2/2f/FalcoHeadSSBU.png"}

  defp internal_lookup("0584" <> _, _),
    do: %__MODULE__{name: "Wolf", icon: "https://www.ssbwiki.com/images/e/e8/WolfHeadSSBU.png"}

  defp internal_lookup("05c001" <> _, _),
    do: %__MODULE__{
      name: "Zero Suit Samus",
      icon: "https://www.ssbwiki.com/images/7/71/ZeroSuitSamusHeadSSBU.png"
    }

  defp internal_lookup("05c0" <> _, _),
    do: %__MODULE__{name: "Samus", icon: "https://www.ssbwiki.com/images/7/7f/SamusHeadSSBU.png"}

  defp internal_lookup("05c2" <> _, _),
    do: %__MODULE__{
      name: "Ridley",
      icon: "https://www.ssbwiki.com/images/5/5b/RidleyHeadSSBU.png"
    }

  defp internal_lookup("05c3" <> _, _),
    do: %__MODULE__{
      name: "Dark Samus",
      icon: "https://www.ssbwiki.com/images/9/96/DarkSamusHeadSSBU.png"
    }

  defp internal_lookup("0180" <> _, _),
    do: %__MODULE__{
      name: "Villager",
      icon: "https://www.ssbwiki.com/images/b/b9/VillagerHeadSSBU.png"
    }

  defp internal_lookup("0181" <> _, _),
    do: %__MODULE__{
      name: "Isabelle",
      icon: "https://www.ssbwiki.com/images/2/2f/IsabelleHeadSSBU.png"
    }

  defp internal_lookup("0600" <> _, _),
    do: %__MODULE__{
      name: "Captain Falcon",
      icon: "https://www.ssbwiki.com/images/3/35/CaptainFalconHeadSSBU.png"
    }

  defp internal_lookup("0640" <> _, _),
    do: %__MODULE__{
      name: "Olimar",
      icon: "https://www.ssbwiki.com/images/9/91/OlimarHeadSSBU.png"
    }

  defp internal_lookup("06c0" <> _, _),
    do: %__MODULE__{
      name: "Little Mac",
      icon: "https://www.ssbwiki.com/images/1/10/LittleMacHeadSSBU.png"
    }

  defp internal_lookup("0700" <> _, _),
    do: %__MODULE__{
      name: "Wii Fit Trainer",
      icon: "https://www.ssbwiki.com/images/8/87/WiiFitTrainerHeadSSBU.png"
    }

  defp internal_lookup("0740" <> _, _),
    do: %__MODULE__{name: "Pit", icon: "https://www.ssbwiki.com/images/a/aa/PitHeadSSBU.png"}

  defp internal_lookup("0741" <> _, _),
    do: %__MODULE__{
      name: "Dark Pit",
      icon: "https://www.ssbwiki.com/images/e/ed/DarkPitHeadSSBU.png"
    }

  defp internal_lookup("0742" <> _, _),
    do: %__MODULE__{
      name: "Palutena",
      icon: "https://www.ssbwiki.com/images/a/a9/PalutenaHeadSSBU.png"
    }

  defp internal_lookup("0780" <> _, _),
    do: %__MODULE__{
      name: "Mr. Game & Watch",
      icon: "https://www.ssbwiki.com/images/6/6b/MrGame%26WatchHeadSSBU.png"
    }

  defp internal_lookup("0781" <> _, _),
    do: %__MODULE__{name: "R.O.B.", icon: "https://www.ssbwiki.com/images/b/b3/ROBHeadSSBU.png"}

  defp internal_lookup("0782" <> _, _),
    do: %__MODULE__{
      name: "Duck Hunt",
      icon: "https://www.ssbwiki.com/images/a/a1/DuckHuntHeadSSBU.png"
    }

  defp internal_lookup("078f" <> _, _),
    do: %__MODULE__{
      name: "Ice Climbers",
      icon: "https://www.ssbwiki.com/images/8/8b/IceClimbersHeadSSBU.png"
    }

  defp internal_lookup("07c000" <> _, _),
    do: %__MODULE__{
      name: "Mii Brawler",
      icon: "https://www.ssbwiki.com/images/d/d8/MiiBrawlerHeadSSBU.png"
    }

  defp internal_lookup("07c001" <> _, _),
    do: %__MODULE__{
      name: "Mii Swordfighter",
      icon: "https://www.ssbwiki.com/images/e/ef/MiiSwordfighterHeadSSBU.png"
    }

  defp internal_lookup("07c002" <> _, _),
    do: %__MODULE__{
      name: "Mii Gunner",
      icon: "https://www.ssbwiki.com/images/3/3d/MiiGunnerHeadSSBU.png"
    }

  defp internal_lookup("0800" <> _, _),
    do: %__MODULE__{
      name: "Inkling",
      icon: "https://www.ssbwiki.com/images/f/f1/InklingHeadSSBU.png"
    }

  defp internal_lookup("0a40" <> _, _),
    do: %__MODULE__{
      name: "Min Min",
      icon: "https://www.ssbwiki.com/images/d/de/MinMinHeadSSBU.png"
    }

  # Easter egg: The hex number converted to decimal matches the nation Pokédex number.
  # Ivysaur 0x02 = 2
  defp internal_lookup("1902" <> _, _),
    do: %__MODULE__{
      name: "Pokemon Trainer",
      icon: "https://www.ssbwiki.com/images/b/b4/IvysaurHeadSSBU.png"
    }

  # Charizard 0x06 = 6
  defp internal_lookup("1906" <> _, _),
    do: %__MODULE__{
      name: "Pokemon Trainer",
      icon: "https://www.ssbwiki.com/images/c/c9/CharizardHeadSSBU.png"
    }

  # Squirtle 0x07 = 7
  defp internal_lookup("1907" <> _, _),
    do: %__MODULE__{
      name: "Pokemon Trainer",
      icon: "https://www.ssbwiki.com/images/4/40/SquirtleHeadSSBU.png"
    }

  # 0x19 = 25
  defp internal_lookup("1919" <> _, _),
    do: %__MODULE__{
      name: "Pikachu",
      icon: "https://www.ssbwiki.com/images/f/fa/PikachuHeadSSBU.png"
    }

  # 0x27 = 39
  defp internal_lookup("1927" <> _, _),
    do: %__MODULE__{
      name: "Jigglypuff",
      icon: "https://www.ssbwiki.com/images/9/95/JigglypuffHeadSSBU.png"
    }

  # 0x96 = 150 Also, Pokémon was released in 1996.
  defp internal_lookup("1996" <> _, _),
    do: %__MODULE__{
      name: "Mewtwo",
      icon: "https://www.ssbwiki.com/images/9/96/MewtwoHeadSSBU.png"
    }

  # 0xAC = 172
  defp internal_lookup("19ac" <> _, _),
    do: %__MODULE__{name: "Pichu", icon: "https://www.ssbwiki.com/images/d/d6/PichuHeadSSBU.png"}

  # 0x1C0 = 448
  defp internal_lookup("1ac0" <> _, _),
    do: %__MODULE__{
      name: "Lucario",
      icon: "https://www.ssbwiki.com/images/c/cd/LucarioHeadSSBU.png"
    }

  # 0x292 = 658
  defp internal_lookup("1b92" <> _, _),
    do: %__MODULE__{
      name: "Greninja",
      icon: "https://www.ssbwiki.com/images/6/65/GreninjaHeadSSBU.png"
    }

  # 0x2D7 = 727
  defp internal_lookup("1bd7" <> _, _),
    do: %__MODULE__{
      name: "Incineroar",
      icon: "https://www.ssbwiki.com/images/5/50/IncineroarHeadSSBU.png"
    }

  # Pokemon Trainer
  defp internal_lookup("1d40" <> _, _),
    do: %__MODULE__{
      name: "Pokemon Trainer",
      icon: "https://www.ssbwiki.com/images/0/09/PokémonTrainerHeadSSBU.png"
    }

  defp internal_lookup("1f00" <> _, _),
    do: %__MODULE__{name: "Kirby", icon: "https://www.ssbwiki.com/images/9/91/KirbyHeadSSBU.png"}

  defp internal_lookup("1f01" <> _, _),
    do: %__MODULE__{
      name: "Meta Knight",
      icon: "https://www.ssbwiki.com/images/d/de/MetaKnightHeadSSBU.png"
    }

  defp internal_lookup("1f02" <> _, _),
    do: %__MODULE__{
      name: "King Dedede",
      icon: "https://www.ssbwiki.com/images/b/bb/KingDededeHeadSSBU.png"
    }

  defp internal_lookup("2100" <> _, _),
    do: %__MODULE__{name: "Marth", icon: "https://www.ssbwiki.com/images/b/bd/MarthHeadSSBU.png"}

  defp internal_lookup("2101" <> _, _),
    do: %__MODULE__{name: "Ike", icon: "https://www.ssbwiki.com/images/b/b2/IkeHeadSSBU.png"}

  defp internal_lookup("2102" <> _, _),
    do: %__MODULE__{
      name: "Lucina",
      icon: "https://www.ssbwiki.com/images/0/04/LucinaHeadSSBU.png"
    }

  defp internal_lookup("2103" <> _, _),
    do: %__MODULE__{name: "Robin", icon: "https://www.ssbwiki.com/images/2/25/RobinHeadSSBU.png"}

  defp internal_lookup("2104" <> _, _),
    do: %__MODULE__{name: "Roy", icon: "https://www.ssbwiki.com/images/e/ed/RoyHeadSSBU.png"}

  defp internal_lookup("2105" <> _, _),
    do: %__MODULE__{
      name: "Corrin",
      icon: "https://www.ssbwiki.com/images/c/cf/CorrinHeadSSBU.png"
    }

  defp internal_lookup("2108" <> _, _),
    do: %__MODULE__{name: "Chrom", icon: "https://www.ssbwiki.com/images/2/25/ChromHeadSSBU.png"}

  defp internal_lookup("210b" <> _, _),
    do: %__MODULE__{
      name: "Byleth",
      icon: "https://www.ssbwiki.com/images/a/a2/BylethHeadSSBU.png"
    }

  defp internal_lookup("2240" <> _, _),
    do: %__MODULE__{name: "Shulk", icon: "https://www.ssbwiki.com/images/c/c1/ShulkHeadSSBU.png"}

  defp internal_lookup("2241" <> _, _),
    do: %__MODULE__{
      name: "Pyra & Mythra",
      icon: "https://ssb.wiki.gallery/images/7/79/PyraHeadSSBU.png"
    }

  defp internal_lookup("2242" <> _, _),
    do: %__MODULE__{
      name: "Pyra & Mythra",
      icon: "https://ssb.wiki.gallery/images/3/32/MythraHeadSSBU.png"
    }

  defp internal_lookup("2280" <> _, _),
    do: %__MODULE__{name: "Ness", icon: "https://www.ssbwiki.com/images/0/0f/NessHeadSSBU.png"}

  defp internal_lookup("2281" <> _, _),
    do: %__MODULE__{name: "Lucas", icon: "https://www.ssbwiki.com/images/f/ff/LucasHeadSSBU.png"}

  defp internal_lookup("3200" <> _, _),
    do: %__MODULE__{name: "Sonic", icon: "https://www.ssbwiki.com/images/7/76/SonicHeadSSBU.png"}

  defp internal_lookup("3240" <> _, _),
    do: %__MODULE__{
      name: "Bayonetta",
      icon: "https://www.ssbwiki.com/images/6/6c/BayonettaHeadSSBU.png"
    }

  defp internal_lookup("3340" <> _, _),
    do: %__MODULE__{
      name: "Pac-Man",
      icon: "https://www.ssbwiki.com/images/4/45/Pac-ManHeadSSBU.png"
    }

  defp internal_lookup("33c0" <> _, _),
    do: %__MODULE__{
      name: "Kazuya",
      icon: "https://ssb.wiki.gallery/images/6/67/KazuyaHeadSSBU.png"
    }

  defp internal_lookup("3480" <> _, _),
    do: %__MODULE__{
      name: "Mega Man",
      icon: "https://www.ssbwiki.com/images/5/55/MegaManHeadSSBU.png"
    }

  defp internal_lookup("34c0" <> _, _),
    do: %__MODULE__{name: "Ryu", icon: "https://www.ssbwiki.com/images/f/fb/RyuHeadSSBU.png"}

  defp internal_lookup("34c1" <> _, _),
    do: %__MODULE__{name: "Ken", icon: "https://www.ssbwiki.com/images/7/72/KenHeadSSBU.png"}

  defp internal_lookup("3600" <> _, _),
    do: %__MODULE__{name: "Cloud", icon: "https://www.ssbwiki.com/images/3/3b/CloudHeadSSBU.png"}

  defp internal_lookup("3601" <> _, _),
    do: %__MODULE__{
      name: "Sephiroth",
      icon: "https://ssb.wiki.gallery/images/5/5e/SephirothHeadSSBU.png"
    }

  defp internal_lookup("3640" <> _, _),
    do: %__MODULE__{name: "Hero", icon: "https://www.ssbwiki.com/images/3/3d/HeroHeadSSBU.png"}

  defp internal_lookup("3780" <> _, _),
    do: %__MODULE__{name: "Snake", icon: "https://www.ssbwiki.com/images/9/9a/SnakeHeadSSBU.png"}

  defp internal_lookup("37c0" <> _, _),
    do: %__MODULE__{name: "Simon", icon: "https://www.ssbwiki.com/images/d/df/SimonHeadSSBU.png"}

  defp internal_lookup("37c1" <> _, _),
    do: %__MODULE__{
      name: "Richter",
      icon: "https://www.ssbwiki.com/images/0/07/RichterHeadSSBU.png"
    }

  defp internal_lookup("3a00" <> _, _),
    do: %__MODULE__{name: "Joker", icon: "https://www.ssbwiki.com/images/2/25/JokerHeadSSBU.png"}

  defp internal_lookup("3b40" <> _, _),
    do: %__MODULE__{
      name: "Banjo & Kazooie",
      icon: "https://www.ssbwiki.com/images/6/60/Banjo%26KazooieHeadSSBU.png"
    }

  defp internal_lookup("3c80" <> _, _),
    do: %__MODULE__{name: "Terry", icon: "https://www.ssbwiki.com/images/f/f9/TerryHeadSSBU.png"}

  defp internal_lookup("3dc0" <> _, _),
    do: %__MODULE__{name: "Steve", icon: "https://ssb.wiki.gallery/images/1/11/SteveHeadSSBU.png"}

  defp internal_lookup("3dc1" <> _, _),
    do: %__MODULE__{name: "Steve", icon: "https://ssb.wiki.gallery/images/1/11/SteveHeadSSBU.png"}

  defp internal_lookup("3f00" <> _, _),
    do: %__MODULE__{name: "Sora", icon: "https://ssb.wiki.gallery/images/0/0e/SoraHeadSSBU.png"}

  defp internal_lookup("010101" <> _, _),
    do: %__MODULE__{name: "Sheik", icon: "https://www.ssbwiki.com/images/3/37/SheikHeadSSBU.png"}

  # Zelda and Zelda & Loftwing
  defp internal_lookup("0101" <> _, _),
    do: %__MODULE__{name: "Zelda", icon: "https://www.ssbwiki.com/images/c/c1/ZeldaHeadSSBU.png"}

  defp internal_lookup("0102" <> _, _),
    do: %__MODULE__{
      name: "Ganondorf",
      icon: "https://www.ssbwiki.com/images/7/78/GanondorfHeadSSBU.png"
    }

  defp internal_lookup("010001" <> _, _),
    do: %__MODULE__{
      name: "Toon Link",
      icon: "https://www.ssbwiki.com/images/e/e6/ToonLinkHeadSSBU.png"
    }

  # Super Smash Bros. Young Link
  defp internal_lookup("01000000", "037c0002"),
    do: %__MODULE__{
      name: "Young Link",
      icon: "https://www.ssbwiki.com/images/c/cd/YoungLinkHeadSSBU.png"
    }

  # Majora's Mask Link
  defp internal_lookup("01000000", "034c0902"),
    do: %__MODULE__{
      name: "Young Link",
      icon: "https://www.ssbwiki.com/images/c/cd/YoungLinkHeadSSBU.png"
    }

  # Catch all for future Links
  defp internal_lookup("010000" <> _, _),
    do: %__MODULE__{name: "Link", icon: "https://www.ssbwiki.com/images/a/aa/LinkHeadSSBU.png"}

  # Future Amiibo:
  # Sora https://ssb.wiki.gallery/images/thumb/6/61/SoraHeadSSBUWebsite.png/64px-SoraHeadSSBUWebsite.png

  # No match
  defp internal_lookup(_, _), do: %__MODULE__{name: nil, icon: nil}
end
