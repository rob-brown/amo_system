defmodule SSBU.Personality.Branch do
  @moduledoc """
  Generated from `personality.toml` by generate_personality_code.exs
  """

  defstruct [:name, :criteria, :tiers]

  def data() do
    [
      %__MODULE__{
        name: "agl",
        tiers: [
          %{personality: "Light", target_score: 100},
          %{personality: "Quick", target_score: 170},
          %{personality: "Lightning Fast", target_score: 225}
        ],
        criteria: [
          %{
            desirable: true,
            param_name: :offensive,
            rank1: %{points: 11, threshold: 0.25},
            rank2: %{points: 24, threshold: 0.51},
            required: false
          },
          %{
            desirable: true,
            param_name: :dash,
            rank1: %{points: 16, threshold: 0.25},
            rank2: %{points: 40, threshold: 0.76},
            required: true
          },
          %{
            desirable: false,
            param_name: :air_offensive,
            rank1: %{points: 5, threshold: 0.26},
            rank2: %{points: 15, threshold: 0.76},
            required: false
          },
          %{
            desirable: false,
            param_name: :smash_holder,
            rank1: %{points: 11, threshold: 0.26},
            rank2: %{points: 22, threshold: 0.51},
            required: false
          },
          %{
            desirable: true,
            param_name: :dash_attacker,
            rank1: %{points: 13, threshold: 0.25},
            rank2: %{points: 22, threshold: 0.51},
            required: false
          },
          %{
            desirable: false,
            param_name: :critical_hitter,
            rank1: %{points: 8, threshold: 0.26},
            rank2: %{points: 15, threshold: 0.76},
            required: false
          },
          %{
            desirable: false,
            param_name: :shield_master,
            rank1: %{points: 13, threshold: 0.26},
            rank2: %{points: 30, threshold: 0.76},
            required: false
          },
          %{
            desirable: true,
            param_name: :item_collector,
            rank1: %{points: 11, threshold: 0.22},
            rank2: %{points: 15, threshold: 0.48},
            required: false
          },
          %{
            desirable: false,
            param_name: :hammer_collector,
            rank1: %{points: 2, threshold: 0.26},
            rank2: %{points: 3, threshold: 0.51},
            required: false
          },
          %{
            desirable: false,
            param_name: :special_flagger,
            rank1: %{points: 2, threshold: 0.26},
            rank2: %{points: 3, threshold: 0.51},
            required: false
          },
          %{
            desirable: false,
            param_name: :homerun_batter,
            rank1: %{points: 2, threshold: 0.26},
            rank2: %{points: 3, threshold: 0.51},
            required: false
          },
          %{
            desirable: false,
            param_name: :club_swinger,
            rank1: %{points: 2, threshold: 0.26},
            rank2: %{points: 3, threshold: 0.51},
            required: false
          },
          %{
            desirable: true,
            param_name: :carrier_broker,
            rank1: %{points: 2, threshold: 0.22},
            rank2: %{points: 3, threshold: 0.48},
            required: false
          },
          %{
            desirable: false,
            param_name: :charger,
            rank1: %{points: 2, threshold: 0.26},
            rank2: %{points: 2, threshold: 0.51},
            required: false
          }
        ]
      },
      %__MODULE__{
        name: "cau",
        tiers: [
          %{personality: "Cool", target_score: 80},
          %{personality: "Logical", target_score: 160},
          %{personality: "Sly", target_score: 215}
        ],
        criteria: [
          %{
            desirable: false,
            param_name: :near,
            rank1: %{points: 5, threshold: 0.26},
            rank2: %{points: 10, threshold: 0.51},
            required: false
          },
          %{
            desirable: false,
            param_name: :offensive,
            rank1: %{points: 6, threshold: 0.26},
            rank2: %{points: 12, threshold: 0.51},
            required: false
          },
          %{
            desirable: true,
            param_name: :grounded,
            rank1: %{points: 7, threshold: 0.25},
            rank2: %{points: 12, threshold: 0.51},
            required: false
          },
          %{
            desirable: false,
            param_name: :attack_out_cliff,
            rank1: %{points: 7, threshold: 0.26},
            rank2: %{points: 12, threshold: 0.51},
            required: false
          },
          %{
            desirable: false,
            param_name: :dash,
            rank1: %{points: 7, threshold: 0.26},
            rank2: %{points: 12, threshold: 0.51},
            required: false
          },
          %{
            desirable: false,
            param_name: :air_offensive,
            rank1: %{points: 3, threshold: 0.26},
            rank2: %{points: 6, threshold: 0.76},
            required: false
          },
          %{
            desirable: false,
            param_name: :cliffer,
            rank1: %{points: 8, threshold: 0.26},
            rank2: %{points: 10, threshold: 0.76},
            required: false
          },
          %{
            desirable: true,
            param_name: :feint_master,
            rank1: %{points: 3, threshold: 0.25},
            rank2: %{points: 4, threshold: 0.76},
            required: false
          },
          %{
            desirable: false,
            param_name: :feint_counter,
            rank1: %{points: 3, threshold: 0.26},
            rank2: %{points: 5, threshold: 0.51},
            required: false
          },
          %{
            desirable: true,
            param_name: :feint_shooter,
            rank1: %{points: 3, threshold: 0.25},
            rank2: %{points: 6, threshold: 0.76},
            required: false
          },
          %{
            desirable: false,
            param_name: :smash_holder,
            rank1: %{points: 3, threshold: 0.51},
            rank2: %{points: 6, threshold: 0.76},
            required: false
          },
          %{
            desirable: false,
            param_name: :dash_attacker,
            rank1: %{points: 4, threshold: 0.51},
            rank2: %{points: 6, threshold: 0.76},
            required: false
          },
          %{
            desirable: false,
            param_name: :critical_hitter,
            rank1: %{points: 4, threshold: 0.26},
            rank2: %{points: 6, threshold: 0.76},
            required: false
          },
          %{
            desirable: false,
            param_name: :meteor_master,
            rank1: %{points: 4, threshold: 0.26},
            rank2: %{points: 5, threshold: 0.76},
            required: false
          },
          %{
            desirable: false,
            param_name: :shield_master,
            rank1: %{points: 29, threshold: 0.26},
            rank2: %{points: 42, threshold: 0.76},
            required: true
          },
          %{
            desirable: false,
            param_name: :just_shield_master,
            rank1: %{points: 5, threshold: 0.26},
            rank2: %{points: 5, threshold: 0.76},
            required: false
          },
          %{
            desirable: false,
            param_name: :hammer_collector,
            rank1: %{points: 4, threshold: 0.26},
            rank2: %{points: 10, threshold: 0.51},
            required: false
          },
          %{
            desirable: false,
            param_name: :special_flagger,
            rank1: %{points: 6, threshold: 0.26},
            rank2: %{points: 12, threshold: 0.51},
            required: false
          },
          %{
            desirable: false,
            param_name: :charger,
            rank1: %{points: 3, threshold: 0.26},
            rank2: %{points: 5, threshold: 0.76},
            required: false
          }
        ]
      },
      %__MODULE__{
        name: "def",
        tiers: [
          %{personality: "Cautious", target_score: 100},
          %{personality: "Realistic", target_score: 180},
          %{personality: "Unflappable", target_score: 240}
        ],
        criteria: [
          %{
            desirable: false,
            param_name: :offensive,
            rank1: %{points: 18, threshold: 0.26},
            rank2: %{points: 20, threshold: 0.76},
            required: true
          },
          %{
            desirable: true,
            param_name: :grounded,
            rank1: %{points: 18, threshold: 0.25},
            rank2: %{points: 18, threshold: 0.76},
            required: false
          },
          %{
            desirable: false,
            param_name: :attack_out_cliff,
            rank1: %{points: 10, threshold: 0.26},
            rank2: %{points: 15, threshold: 0.51},
            required: false
          },
          %{
            desirable: false,
            param_name: :dash,
            rank1: %{points: 18, threshold: 0.51},
            rank2: %{points: 25, threshold: 0.76},
            required: false
          },
          %{
            desirable: false,
            param_name: :cliffer,
            rank1: %{points: 15, threshold: 0.26},
            rank2: %{points: 20, threshold: 0.51},
            required: false
          },
          %{
            desirable: true,
            param_name: :shield_master,
            rank1: %{points: 38, threshold: 0.25},
            rank2: %{points: 42, threshold: 0.76},
            required: false
          },
          %{
            desirable: true,
            param_name: :shield_catch_master,
            rank1: %{points: 3, threshold: 0.26},
            rank2: %{points: 5, threshold: 0.51},
            required: false
          },
          %{
            desirable: false,
            param_name: :item_throw_to_target,
            rank1: %{points: 3, threshold: 0.26},
            rank2: %{points: 4, threshold: 0.51},
            required: false
          },
          %{
            desirable: false,
            param_name: :dragoon_collector,
            rank1: %{points: 3, threshold: 0.26},
            rank2: %{points: 4, threshold: 0.51},
            required: false
          },
          %{
            desirable: false,
            param_name: :smash_ball_collector,
            rank1: %{points: 3, threshold: 0.26},
            rank2: %{points: 4, threshold: 0.51},
            required: false
          },
          %{
            desirable: false,
            param_name: :hammer_collector,
            rank1: %{points: 3, threshold: 0.26},
            rank2: %{points: 4, threshold: 0.51},
            required: false
          },
          %{
            desirable: false,
            param_name: :special_flagger,
            rank1: %{points: 3, threshold: 0.26},
            rank2: %{points: 4, threshold: 0.51},
            required: false
          }
        ]
      },
      %__MODULE__{
        name: "dyn",
        tiers: [
          %{personality: "Laid Back", target_score: 80},
          %{personality: "Wild", target_score: 160},
          %{personality: "Lively", target_score: 210}
        ],
        criteria: [
          %{
            desirable: true,
            param_name: :offensive,
            rank1: %{points: 5, threshold: 0.25},
            rank2: %{points: 7, threshold: 0.76},
            required: false
          },
          %{
            desirable: true,
            param_name: :attack_out_cliff,
            rank1: %{points: 3, threshold: 0.26},
            rank2: %{points: 5, threshold: 0.51},
            required: false
          },
          %{
            desirable: true,
            param_name: :air_offensive,
            rank1: %{points: 7, threshold: 0.26},
            rank2: %{points: 10, threshold: 0.76},
            required: false
          },
          %{
            desirable: false,
            param_name: :catcher,
            rank1: %{points: 3, threshold: 0.26},
            rank2: %{points: 3, threshold: 0.51},
            required: false
          },
          %{
            desirable: false,
            param_name: :attack_cancel,
            rank1: %{points: 2, threshold: 0.26},
            rank2: %{points: 2, threshold: 0.51},
            required: false
          },
          %{
            desirable: true,
            param_name: :smash_holder,
            rank1: %{points: 7, threshold: 0.25},
            rank2: %{points: 9, threshold: 0.76},
            required: false
          },
          %{
            desirable: true,
            param_name: :dash_attacker,
            rank1: %{points: 6, threshold: 0.25},
            rank2: %{points: 7, threshold: 0.76},
            required: false
          },
          %{
            desirable: true,
            param_name: :critical_hitter,
            rank1: %{points: 12, threshold: 0.26},
            rank2: %{points: 15, threshold: 0.76},
            required: false
          },
          %{
            desirable: true,
            param_name: :meteor_master,
            rank1: %{points: 11, threshold: 0.26},
            rank2: %{points: 12, threshold: 0.51},
            required: false
          },
          %{
            desirable: true,
            param_name: :shield_master,
            rank1: %{points: 11, threshold: 0.25},
            rank2: %{points: 12, threshold: 0.76},
            required: false
          },
          %{
            desirable: false,
            param_name: :just_shield_master,
            rank1: %{points: 7, threshold: 0.26},
            rank2: %{points: 8, threshold: 0.76},
            required: false
          },
          %{
            desirable: false,
            param_name: :item_throw_to_target,
            rank1: %{points: 2, threshold: 0.26},
            rank2: %{points: 3, threshold: 0.76},
            required: false
          },
          %{
            desirable: true,
            param_name: :dragoon_collector,
            rank1: %{points: 3, threshold: 0.2},
            rank2: %{points: 5, threshold: 0.46},
            required: false
          },
          %{
            desirable: true,
            param_name: :smash_ball_collector,
            rank1: %{points: 3, threshold: 0.2},
            rank2: %{points: 7, threshold: 0.46},
            required: false
          },
          %{
            desirable: true,
            param_name: :hammer_collector,
            rank1: %{points: 3, threshold: 0.2},
            rank2: %{points: 7, threshold: 0.46},
            required: false
          },
          %{
            desirable: true,
            param_name: :special_flagger,
            rank1: %{points: 5, threshold: 0.2},
            rank2: %{points: 10, threshold: 0.46},
            required: false
          },
          %{
            desirable: false,
            param_name: :item_swinger,
            rank1: %{points: 6, threshold: 0.26},
            rank2: %{points: 8, threshold: 0.51},
            required: false
          },
          %{
            desirable: true,
            param_name: :homerun_batter,
            rank1: %{points: 9, threshold: 0.46},
            rank2: %{points: 10, threshold: 0.71},
            required: false
          },
          %{
            desirable: true,
            param_name: :club_swinger,
            rank1: %{points: 9, threshold: 0.46},
            rank2: %{points: 10, threshold: 0.71},
            required: false
          },
          %{
            desirable: true,
            param_name: :death_swinger,
            rank1: %{points: 9, threshold: 0.46},
            rank2: %{points: 10, threshold: 0.71},
            required: false
          },
          %{
            desirable: false,
            param_name: :item_shooter,
            rank1: %{points: 2, threshold: 0.51},
            rank2: %{points: 1, threshold: 0.74},
            required: false
          },
          %{
            desirable: true,
            param_name: :carrier_broker,
            rank1: %{points: 2, threshold: 0.48},
            rank2: %{points: 1, threshold: 0.71},
            required: false
          },
          %{
            desirable: true,
            param_name: :charger,
            rank1: %{points: 5, threshold: 0.22},
            rank2: %{points: 6, threshold: 0.74},
            required: false
          }
        ]
      },
      %__MODULE__{
        name: "ent",
        tiers: [
          %{personality: "Show-Off", target_score: 90},
          %{personality: "Flashy", target_score: 170},
          %{personality: "Entertainer", target_score: 230}
        ],
        criteria: [
          %{
            desirable: true,
            param_name: :attack_out_cliff,
            rank1: %{points: 8, threshold: 0.26},
            rank2: %{points: 12, threshold: 0.76},
            required: false
          },
          %{
            desirable: false,
            param_name: :"100_keeper",
            rank1: %{points: 2, threshold: 0.26},
            rank2: %{points: 4, threshold: 0.51},
            required: false
          },
          %{
            desirable: true,
            param_name: :smash_holder,
            rank1: %{points: 2, threshold: 0.25},
            rank2: %{points: 3, threshold: 0.51},
            required: false
          },
          %{
            desirable: true,
            param_name: :critical_hitter,
            rank1: %{points: 2, threshold: 0.26},
            rank2: %{points: 3, threshold: 0.76},
            required: false
          },
          %{
            desirable: true,
            param_name: :meteor_master,
            rank1: %{points: 7, threshold: 0.26},
            rank2: %{points: 11, threshold: 0.76},
            required: false
          },
          %{
            desirable: true,
            param_name: :just_shield_master,
            rank1: %{points: 8, threshold: 0.26},
            rank2: %{points: 12, threshold: 0.76},
            required: false
          },
          %{
            desirable: false,
            param_name: :item_throw_to_target,
            rank1: %{points: 5, threshold: 0.26},
            rank2: %{points: 13, threshold: 0.51},
            required: false
          },
          %{
            desirable: true,
            param_name: :dragoon_collector,
            rank1: %{points: 8, threshold: 0.2},
            rank2: %{points: 13, threshold: 0.46},
            required: false
          },
          %{
            desirable: true,
            param_name: :smash_ball_collector,
            rank1: %{points: 8, threshold: 0.2},
            rank2: %{points: 13, threshold: 0.46},
            required: false
          },
          %{
            desirable: true,
            param_name: :hammer_collector,
            rank1: %{points: 8, threshold: 0.2},
            rank2: %{points: 14, threshold: 0.46},
            required: false
          },
          %{
            desirable: true,
            param_name: :special_flagger,
            rank1: %{points: 13, threshold: 0.2},
            rank2: %{points: 17, threshold: 0.73},
            required: false
          },
          %{
            desirable: true,
            param_name: :homerun_batter,
            rank1: %{points: 8, threshold: 0.2},
            rank2: %{points: 12, threshold: 0.73},
            required: false
          },
          %{
            desirable: true,
            param_name: :club_swinger,
            rank1: %{points: 5, threshold: 0.2},
            rank2: %{points: 13, threshold: 0.46},
            required: false
          },
          %{
            desirable: true,
            param_name: :death_swinger,
            rank1: %{points: 5, threshold: 0.2},
            rank2: %{points: 14, threshold: 0.46},
            required: false
          },
          %{
            desirable: true,
            param_name: :charger,
            rank1: %{points: 2, threshold: 0.22},
            rank2: %{points: 3, threshold: 0.48},
            required: false
          },
          %{
            desirable: true,
            param_name: :appeal,
            rank1: %{points: 18, threshold: 0.25},
            rank2: %{points: 34, threshold: 0.76},
            required: true
          }
        ]
      },
      %__MODULE__{
        name: "gen",
        tiers: [
          %{personality: "Versatile", target_score: 80},
          %{personality: "Tricky", target_score: 120},
          %{personality: "Technician", target_score: 150}
        ],
        criteria: [
          %{
            desirable: true,
            param_name: :attack_out_cliff,
            rank1: %{points: 7, threshold: 0.26},
            rank2: %{points: 7, threshold: 0.76},
            required: false
          },
          %{
            desirable: false,
            param_name: :air_offensive,
            rank1: %{points: 5, threshold: 0.26},
            rank2: %{points: 7, threshold: 0.76},
            required: false
          },
          %{
            desirable: true,
            param_name: :feint_master,
            rank1: %{points: 8, threshold: 0.25},
            rank2: %{points: 13, threshold: 0.76},
            required: false
          },
          %{
            desirable: true,
            param_name: :feint_counter,
            rank1: %{points: 8, threshold: 0.25},
            rank2: %{points: 13, threshold: 0.76},
            required: false
          },
          %{
            desirable: true,
            param_name: :feint_shooter,
            rank1: %{points: 8, threshold: 0.25},
            rank2: %{points: 13, threshold: 0.76},
            required: false
          },
          %{
            desirable: true,
            param_name: :catcher,
            rank1: %{points: 7, threshold: 0.25},
            rank2: %{points: 9, threshold: 0.76},
            required: false
          },
          %{
            desirable: true,
            param_name: :attack_cancel,
            rank1: %{points: 5, threshold: 0.26},
            rank2: %{points: 5, threshold: 0.76},
            required: false
          },
          %{
            desirable: true,
            param_name: :meteor_master,
            rank1: %{points: 4, threshold: 0.26},
            rank2: %{points: 15, threshold: 0.76},
            required: false
          },
          %{
            desirable: true,
            param_name: :shield_master,
            rank1: %{points: 4, threshold: 0.25},
            rank2: %{points: 10, threshold: 0.76},
            required: false
          },
          %{
            desirable: true,
            param_name: :just_shield_master,
            rank1: %{points: 23, threshold: 0.26},
            rank2: %{points: 35, threshold: 0.76},
            required: true
          },
          %{
            desirable: true,
            param_name: :shield_catch_master,
            rank1: %{points: 5, threshold: 0.26},
            rank2: %{points: 9, threshold: 0.46},
            required: false
          },
          %{
            desirable: true,
            param_name: :item_collector,
            rank1: %{points: 3, threshold: 0.22},
            rank2: %{points: 8, threshold: 0.76},
            required: false
          },
          %{
            desirable: true,
            param_name: :item_throw_to_target,
            rank1: %{points: 3, threshold: 0.22},
            rank2: %{points: 4, threshold: 0.48},
            required: false
          },
          %{
            desirable: true,
            param_name: :dragoon_collector,
            rank1: %{points: 3, threshold: 0.2},
            rank2: %{points: 7, threshold: 0.46},
            required: false
          },
          %{
            desirable: true,
            param_name: :smash_ball_collector,
            rank1: %{points: 3, threshold: 0.2},
            rank2: %{points: 5, threshold: 0.76},
            required: false
          },
          %{
            desirable: true,
            param_name: :item_swinger,
            rank1: %{points: 2, threshold: 0.22},
            rank2: %{points: 3, threshold: 0.46},
            required: false
          },
          %{
            desirable: true,
            param_name: :homerun_batter,
            rank1: %{points: 4, threshold: 0.2},
            rank2: %{points: 4, threshold: 0.76},
            required: false
          },
          %{
            desirable: true,
            param_name: :club_swinger,
            rank1: %{points: 4, threshold: 0.2},
            rank2: %{points: 4, threshold: 0.76},
            required: false
          },
          %{
            desirable: true,
            param_name: :death_swinger,
            rank1: %{points: 4, threshold: 0.2},
            rank2: %{points: 4, threshold: 0.46},
            required: false
          },
          %{
            desirable: true,
            param_name: :item_shooter,
            rank1: %{points: 3, threshold: 0.22},
            rank2: %{points: 4, threshold: 0.76},
            required: false
          },
          %{
            desirable: false,
            param_name: :carrier_broker,
            rank1: %{points: 4, threshold: 0.26},
            rank2: %{points: 4, threshold: 0.76},
            required: false
          }
        ]
      },
      %__MODULE__{
        name: "ofn",
        tiers: [
          %{personality: "Enthusiastic", target_score: 100},
          %{personality: "Aggressive", target_score: 180},
          %{personality: "Offensive", target_score: 235}
        ],
        criteria: [
          %{
            desirable: true,
            param_name: :near,
            rank1: %{points: 15, threshold: 0.25},
            rank2: %{points: 22, threshold: 0.76},
            required: true
          },
          %{
            desirable: true,
            param_name: :offensive,
            rank1: %{points: 21, threshold: 0.25},
            rank2: %{points: 30, threshold: 0.76},
            required: false
          },
          %{
            desirable: true,
            param_name: :attack_out_cliff,
            rank1: %{points: 13, threshold: 0.26},
            rank2: %{points: 20, threshold: 0.51},
            required: false
          },
          %{
            desirable: true,
            param_name: :dash,
            rank1: %{points: 11, threshold: 0.25},
            rank2: %{points: 13, threshold: 0.51},
            required: false
          },
          %{
            desirable: true,
            param_name: :air_offensive,
            rank1: %{points: 10, threshold: 0.26},
            rank2: %{points: 18, threshold: 0.76},
            required: false
          },
          %{
            desirable: false,
            param_name: :feint_shooter,
            rank1: %{points: 7, threshold: 0.26},
            rank2: %{points: 8, threshold: 0.76},
            required: false
          },
          %{
            desirable: true,
            param_name: :dash_attacker,
            rank1: %{points: 10, threshold: 0.25},
            rank2: %{points: 18, threshold: 0.51},
            required: false
          },
          %{
            desirable: true,
            param_name: :meteor_master,
            rank1: %{points: 10, threshold: 0.26},
            rank2: %{points: 28, threshold: 0.51},
            required: false
          },
          %{
            desirable: false,
            param_name: :item_collector,
            rank1: %{points: 2, threshold: 0.26},
            rank2: %{points: 4, threshold: 0.51},
            required: false
          },
          %{
            desirable: true,
            param_name: :item_throw_to_target,
            rank1: %{points: 4, threshold: 0.48},
            rank2: %{points: 8, threshold: 0.74},
            required: false
          },
          %{
            desirable: false,
            param_name: :dragoon_collector,
            rank1: %{points: 3, threshold: 0.26},
            rank2: %{points: 4, threshold: 0.51},
            required: false
          },
          %{
            desirable: false,
            param_name: :smash_ball_collector,
            rank1: %{points: 3, threshold: 0.26},
            rank2: %{points: 4, threshold: 0.51},
            required: false
          },
          %{
            desirable: false,
            param_name: :hammer_collector,
            rank1: %{points: 3, threshold: 0.26},
            rank2: %{points: 4, threshold: 0.51},
            required: false
          },
          %{
            desirable: false,
            param_name: :special_flagger,
            rank1: %{points: 3, threshold: 0.26},
            rank2: %{points: 4, threshold: 0.76},
            required: false
          }
        ]
      },
      %__MODULE__{
        name: "rsk",
        tiers: [
          %{personality: "Reckless", target_score: 80},
          %{personality: "Thrill Seeker", target_score: 160},
          %{personality: "Daredevil", target_score: 220}
        ],
        criteria: [
          %{
            desirable: true,
            param_name: :near,
            rank1: %{points: 15, threshold: 0.25},
            rank2: %{points: 22, threshold: 0.51},
            required: false
          },
          %{
            desirable: true,
            param_name: :offensive,
            rank1: %{points: 11, threshold: 0.25},
            rank2: %{points: 16, threshold: 0.76},
            required: false
          },
          %{
            desirable: false,
            param_name: :grounded,
            rank1: %{points: 5, threshold: 0.26},
            rank2: %{points: 10, threshold: 0.51},
            required: false
          },
          %{
            desirable: true,
            param_name: :attack_out_cliff,
            rank1: %{points: 24, threshold: 0.26},
            rank2: %{points: 28, threshold: 0.76},
            required: true
          },
          %{
            desirable: true,
            param_name: :air_offensive,
            rank1: %{points: 8, threshold: 0.26},
            rank2: %{points: 13, threshold: 0.76},
            required: false
          },
          %{
            desirable: true,
            param_name: :cliffer,
            rank1: %{points: 5, threshold: 0.51},
            rank2: %{points: 8, threshold: 0.76},
            required: false
          },
          %{
            desirable: true,
            param_name: :feint_master,
            rank1: %{points: 3, threshold: 0.25},
            rank2: %{points: 5, threshold: 0.76},
            required: false
          },
          %{
            desirable: true,
            param_name: :feint_counter,
            rank1: %{points: 3, threshold: 0.25},
            rank2: %{points: 5, threshold: 0.51},
            required: false
          },
          %{
            desirable: false,
            param_name: :feint_shooter,
            rank1: %{points: 2, threshold: 0.26},
            rank2: %{points: 3, threshold: 0.51},
            required: false
          },
          %{
            desirable: true,
            param_name: :dash_attacker,
            rank1: %{points: 10, threshold: 0.25},
            rank2: %{points: 16, threshold: 0.51},
            required: false
          },
          %{
            desirable: true,
            param_name: :critical_hitter,
            rank1: %{points: 4, threshold: 0.26},
            rank2: %{points: 8, threshold: 0.51},
            required: false
          },
          %{
            desirable: true,
            param_name: :meteor_master,
            rank1: %{points: 12, threshold: 0.26},
            rank2: %{points: 30, threshold: 0.51},
            required: false
          },
          %{
            desirable: true,
            param_name: :just_shield_master,
            rank1: %{points: 3, threshold: 0.26},
            rank2: %{points: 6, threshold: 0.51},
            required: false
          },
          %{
            desirable: true,
            param_name: :hammer_collector,
            rank1: %{points: 5, threshold: 0.2},
            rank2: %{points: 8, threshold: 0.73},
            required: false
          },
          %{
            desirable: true,
            param_name: :special_flagger,
            rank1: %{points: 2, threshold: 0.2},
            rank2: %{points: 5, threshold: 0.46},
            required: false
          },
          %{
            desirable: true,
            param_name: :carrier_broker,
            rank1: %{points: 2, threshold: 0.22},
            rank2: %{points: 3, threshold: 0.74},
            required: false
          }
        ]
      }
    ]
  end
end