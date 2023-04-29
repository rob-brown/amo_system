defmodule CharacterTest do
  use ExUnit.Case
  alias SSBU.Character

  test "lookup character" do
    assert Character.lookup("00000000", "00000002").name == "Mario"
    assert Character.lookup("00000300", "03A60102").name == "Mario"
    assert Character.lookup("00020000", "00010002").name == "Peach"
    assert Character.lookup("00020100", "03A70102").name == "Peach"
    assert Character.lookup("00030000", "00020002").name == "Yoshi"
    assert Character.lookup("00080000", "00030002").name == "Donkey Kong"
    assert Character.lookup("01000000", "00040002").name == "Link"
    assert Character.lookup("01000000", "034B0902").name == "Link"
    assert Character.lookup("01000000", "034D0902").name == "Link"
    assert Character.lookup("01000000", "034E0902").name == "Link"
    assert Character.lookup("01000000", "034F0902").name == "Link"
    assert Character.lookup("01000000", "03530902").name == "Link"
    assert Character.lookup("01000000", "03540902").name == "Link"
    assert Character.lookup("01000000", "03990902").name == "Link"
    assert Character.lookup("05800000", "00050002").name == "Fox"
    assert Character.lookup("05c00000", "00060002").name == "Samus"
    assert Character.lookup("07000000", "00070002").name == "Wii Fit Trainer"
    assert Character.lookup("01800000", "00080002").name == "Villager"
    assert Character.lookup("19190000", "00090002").name == "Pikachu"
    assert Character.lookup("1f000000", "000a0002").name == "Kirby"
    assert Character.lookup("21000000", "000b0002").name == "Marth"
    assert Character.lookup("01010000", "000e0002").name == "Zelda"
    assert Character.lookup("00090000", "000d0002").name == "Diddy Kong"
    assert Character.lookup("00010000", "000c0002").name == "Luigi"
    assert Character.lookup("06c00000", "000f0002").name == "Little Mac"
    assert Character.lookup("07400000", "00100002").name == "Pit"
    assert Character.lookup("06000000", "00120002").name == "Captain Falcon"
    assert Character.lookup("00040100", "00130002").name == "Rosalina & Luma"
    assert Character.lookup("00050000", "00140002").name == "Bowser"
    assert Character.lookup("1ac00000", "00110002").name == "Lucario"
    assert Character.lookup("01000100", "00160002").name == "Toon Link"
    assert Character.lookup("01010100", "00170002").name == "Sheik"
    assert Character.lookup("21010000", "00180002").name == "Ike"
    assert Character.lookup("22400000", "002b0002").name == "Shulk"
    assert Character.lookup("32000000", "00300002").name == "Sonic"
    assert Character.lookup("34800000", "00310002").name == "Mega Man"
    assert Character.lookup("1f020000", "00280002").name == "King Dedede"
    assert Character.lookup("1f010000", "00270002").name == "Meta Knight"
    assert Character.lookup("21030000", "002a0002").name == "Robin"
    assert Character.lookup("21020000", "00290002").name == "Lucina"
    assert Character.lookup("00070000", "001a0002").name == "Wario"
    assert Character.lookup("19060000", "00240002").name == "Pokemon Trainer"
    assert Character.lookup("22800000", "002c0002").name == "Ness"
    assert Character.lookup("33400000", "00320002").name == "Pac-Man"
    assert Character.lookup("1b920000", "00250002").name == "Greninja"
    assert Character.lookup("19270000", "00260002").name == "Jigglypuff"
    assert Character.lookup("07420000", "001f0002").name == "Palutena"
    assert Character.lookup("07410000", "00200002").name == "Dark Pit"
    assert Character.lookup("05c00100", "001d0002").name == "Zero Suit Samus"
    assert Character.lookup("01020100", "001b0002").name == "Ganondorf"
    assert Character.lookup("00000100", "00190002").name == "Dr. Mario"
    assert Character.lookup("00060000", "00150002").name == "Koopaling"
    assert Character.lookup("06400100", "001e0002").name == "Olimar"
    assert Character.lookup("07800000", "002d0002").name == "Mr. Game & Watch"
    assert Character.lookup("07810000", "00330002").name == "R.O.B."
    assert Character.lookup("07820000", "002f0002").name == "Duck Hunt"
    assert Character.lookup("07c00000", "00210002").name == "Mii Brawler"
    assert Character.lookup("07c00100", "00220002").name == "Mii Swordfighter"
    assert Character.lookup("07c00200", "00230002").name == "Mii Gunner"
    assert Character.lookup("19960000", "023d0002").name == "Mewtwo"
    assert Character.lookup("05810000", "001c0002").name == "Falco"
    assert Character.lookup("22810000", "02510002").name == "Lucas"
    assert Character.lookup("07810000", "002e0002").name == "R.O.B."
    assert Character.lookup("21040000", "02520002").name == "Roy"
    assert Character.lookup("34c00000", "02530002").name == "Ryu"
    assert Character.lookup("36000000", "02590002").name == "Cloud"
    assert Character.lookup("36000100", "03620002").name == "Cloud"
    assert Character.lookup("21050000", "025a0002").name == "Corrin"
    assert Character.lookup("21050100", "03630002").name == "Corrin"
    assert Character.lookup("32400000", "025b0002").name == "Bayonetta"
    assert Character.lookup("32400100", "03640002").name == "Bayonetta"
    assert Character.lookup("08000100", "03820002").name == "Inkling"
    assert Character.lookup("05c20000", "037f0002").name == "Ridley"
    assert Character.lookup("05840000", "037e0002").name == "Wolf"
    assert Character.lookup("00c00000", "037b0002").name == "King K. Rool"
    assert Character.lookup("078f0000", "03810002").name == "Ice Climbers"
    assert Character.lookup("00240000", "038d0002").name == "Piranha Plant"
    assert Character.lookup("00130000", "037a0002").name == "Daisy"
    assert Character.lookup("01810000", "037d0002").name == "Isabelle"
    assert Character.lookup("19ac0000", "03850002").name == "Pichu"
    assert Character.lookup("34c10000", "03890002").name == "Ken"
    assert Character.lookup("01000000", "037c0002").name == "Young Link"
    assert Character.lookup("01000000", "034C0902").name == "Young Link"
    assert Character.lookup("1d400000", "03870002").name == "Pokemon Trainer"
    assert Character.lookup("37800000", "038a0002").name == "Snake"
    assert Character.lookup("19020000", "03830002").name == "Pokemon Trainer"
    assert Character.lookup("19070000", "03840002").name == "Pokemon Trainer"
    assert Character.lookup("37c00000", "038b0002").name == "Simon"
    assert Character.lookup("1bd70000", "03860002").name == "Incineroar"
    assert Character.lookup("21080000", "03880002").name == "Chrom"
    assert Character.lookup("05c30000", "03800002").name == "Dark Samus"
    assert Character.lookup("37c10000", "038c0002").name == "Richter"
    assert Character.lookup("3a000000", "03a10002").name == "Joker"
    assert Character.lookup("36400000", "03a20002").name == "Hero"
    # Detective Pikachu
    assert Character.lookup("1d010000", "03750d02").name == nil
  end
end

