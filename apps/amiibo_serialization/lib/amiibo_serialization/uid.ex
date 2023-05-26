defmodule AmiiboSerialization.UID do
  @moduledoc """
  Module for handling Unique IDs (UIDs). Assumes a 7-byte UID. 4-byte and 10-byte
  UIDs are not supported.

  ## References

  * [NTAG-215 docs](https://www.nxp.com/docs/en/data-sheet/NTAG213_215_216.pdf)
  * [UID docs](https://www.nxp.com/docs/en/application-note/AN10927.pdf)
  """

  # The manufacturer code for NXP Semiconductors. 
  # They make the NTAG-215 chip used in amiibo.
  @nxp 0x4

  # Cascade Tag (CT) is used in certain byte locations of the Unique ID (UID)
  # To indicate there's another page for the UID.
  # Amiibo use a 7-byte UID which is two pages.
  @ct 0x88

  # A full 7-byte UID
  @type t() :: <<_::56>>

  # A 6-byte UID (missing the manufacturer byte).
  @type partial_uid() :: <<_::48>>

  # A Block Check Character (BCC) byte.
  @type bcc() :: 0..255

  # A 9-byte sequence interleaving the UID with the BCCs.
  @type bytes() :: <<_::72>>

  @doc """
  Returns true if the given byte sequence is a UID with matching BCCs.
  """
  @spec valid?(bytes()) :: boolean()
  def valid?(bytes = <<@nxp, _uid1, _uid2, bcc0, _uid3, _uid4, _uid5, _uid6, bcc1>>) do

    {expected_bcc0, expected_bcc1} = bytes |> read() |> calculate_bccs()

    bcc0 == expected_bcc0 and bcc1 == expected_bcc1
  end

  def valid?(_bytes) do
    false
  end

  @doc """
  Given a byte string, pull out the UID (ignore the BCCs and don't validate).
  """
  @spec read(bytes()) :: t()
  def read(<<@nxp, uid1, uid2, _bcc0, uid3, uid4, uid5, uid6, _bcc1>>) do
    <<@nxp, uid1, uid2, uid3, uid4, uid5, uid6>>
  end

  @doc """
  Converts the given UID into a byte string with BCCs.
  """
  @spec write(t() | partial_uid()) :: bytes()
  def write(uid = <<@nxp, uid1, uid2, uid3, uid4, uid5, uid6>>) do
    {bcc0, bcc1} = calculate_bccs(uid)
    <<@nxp, uid1, uid2, bcc0, uid3, uid4, uid5, uid6, bcc1>>
  end

  def write(uid = <<_::binary-size(6)>>) do
    write(<<@nxp>> <> uid)
  end

  @doc """
  Creates a new, random, safe UID.
  """
  @spec random() :: t()
  def random() do
    sanitize(:crypto.strong_rand_bytes(6))
  end

  @doc """
  Calculates the two Block Check Character (BCC) bytes for the UID.
  """
  @spec calculate_bccs(t()) :: {bcc(), bcc()}
  def calculate_bccs(<<@nxp, b1, b2, b3, b4, b5, b6>>) do
    bcc0 = Enum.reduce([@nxp, b1, b2, @ct], &Bitwise.bxor/2)
    bcc1 = Enum.reduce([b3, b4, b5, b6], &Bitwise.bxor/2)

    {bcc0, bcc1}
  end

  @doc """
  Ensures the Cascade Tag (CT) is not used in certain byte locations.
  The docs say UID3 can't use the CT which should be the 4th byte here.
  However, AmiiboSN-Changer checks the 5th byte. 
  Ensuring the 4th and 5th bytes aren't the CT just to be safe.

  ## References
  
  * [UID docs](https://www.nxp.com/docs/en/application-note/AN10927.pdf)
  * [AmiiboSN-Changer](https://github.com/DarkIrata/AmiiboSN-Changer/blob/d98cd48b8f09ae17cb9ef6db64a3577ef5dbe87b/AmiiboSNChanger.Libs/AmiiboSNHelper.cs#L92C1-L103)
  """
  @spec sanitize(t() | partial_uid()) :: t()
  def sanitize(<<@nxp, uid1, uid2, @ct, uid4, uid5, uid6>>) do
    sanitize(<<@nxp, uid1, uid2, @ct + 1, uid4, uid5, uid6>>)
  end

  def sanitize(<<@nxp, uid1, uid2, uid3, @ct, uid5, uid6>>) do
    sanitize(<<@nxp, uid1, uid2, uid3, @ct + 1, uid5, uid6>>)
  end

  def sanitize(<<uid::binary-size(7)>>) do
    uid
  end

  def sanitize(<<uid::binary-size(6)>>) do
    sanitize(<<@nxp>> <> uid)
  end
end
