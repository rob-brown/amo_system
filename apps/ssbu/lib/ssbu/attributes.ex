defmodule SSBU.Attributes do
  defstruct [
    :near,
    :offensive,
    :grounded,
    :attack_out_cliff,
    :dash,
    :return_to_cliff,
    :air_offensive,
    :cliffer,
    :feint_master,
    :feint_counter,
    :feint_shooter,
    :catcher,
    :"100_attacker",
    :"100_keeper",
    :attack_cancel,
    :smash_holder,
    :dash_attacker,
    :critical_hitter,
    :meteor_master,
    :shield_master,
    :just_shield_master,
    :shield_catch_master,
    :item_collector,
    :item_throw_to_target,
    :dragoon_collector,
    :smash_ball_collector,
    :hammer_collector,
    :special_flagger,
    :item_swinger,
    :homerun_batter,
    :club_swinger,
    :death_swinger,
    :item_shooter,
    :carrier_broker,
    :charger,
    :appeal,
    :fighter_1,
    :fighter_2,
    :fighter_3,
    :fighter_4,
    :fighter_5,
    :advantageous_fighter,
    :weaken_fighter,
    :revenge,
    :stage_enemy,
    :jab,
    :forward_tilt,
    :up_tilt,
    :down_tilt,
    :forward_smash,
    :up_smash,
    :down_smash,
    :neutral_special,
    :side_special,
    :up_special,
    :down_special,
    :neutral_air,
    :forward_air,
    :back_air,
    :up_air,
    :down_air,
    :neutral_special_air,
    :side_special_air,
    :up_special_air,
    :down_special_air,
    :front_air_dodge,
    :back_air_dodge,
    :neutral_air_dodge,
    :up_taunt,
    :down_taunt,
    :side_taunt
  ]

  alias __MODULE__.Serializer
  alias AmiiboSerialization.Amiibo

  def parse(amiibo = %Amiibo{}) do
    amiibo
    |> Serializer.parse_amiibo()
    |> Serializer.add_implicit_attributes()
    |> from_raw_attributes()
  end

  def write(attributes = %__MODULE__{}, amiibo = %Amiibo{}) do
    attributes
    |> Serializer.build_binary()
    |> then(&SSBU.set_training_data(amiibo, &1))
  end

  def from_raw_attributes(attributes) do
    attributes
    |> Enum.map(fn {key, {_value, _size, float}} -> {Serializer.string_to_key(key), float} end)
    |> then(&struct!(__MODULE__, &1))
  end
end
