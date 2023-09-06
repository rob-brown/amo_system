defmodule Vision.Native do
  use GenServer

  require Logger

  alias Evision.VideoCapture
  alias Evision.Mat

  # Current position of the video file in milliseconds.
  @cap_prop_pos_msec 0
  # 0-based index of the frame to be decoded/captured next. When the index i is set in RAW mode (CAP_PROP_FORMAT == -1) this will seek to the key frame k, where k <= i.
  @cap_prop_pos_frames 1
  # Relative position of the video file: 0=start of the film, 1=end of the film.
  @cap_prop_pos_avi_ratio 2
  # Width of the frames in the video stream.
  @cap_prop_frame_width 3
  # Height of the frames in the video stream.
  @cap_prop_frame_height 4
  # Frame rate.
  @cap_prop_fps 5
  # 4-character code of codec. see VideoWriter::fourcc.
  @cap_prop_fourcc 6
  # Number of frames in the video file.
  @cap_prop_frame_count 7
  # Format of the %Mat objects (see Mat::type()) returned by VideoCapture::retrieve(). Set value -1 to fetch undecoded RAW video streams (as Mat 8UC1).
  @cap_prop_format 8
  # Backend-specific value indicating the current capture mode.
  @cap_prop_mode 9
  # Brightness of the image (only for those cameras that support).
  @cap_prop_brightness 10
  # Contrast of the image (only for cameras).
  @cap_prop_contrast 11
  # Saturation of the image (only for cameras).
  @cap_prop_saturation 12
  # Hue of the image (only for cameras).
  @cap_prop_hue 13
  # Gain of the image (only for those cameras that support).
  @cap_prop_gain 14
  # Exposure (only for those cameras that support).
  @cap_prop_exposure 15
  # Boolean flags indicating whether images should be converted to RGB. *GStreamer note*: The flag is ignored in case if custom pipeline is used. It's user responsibility to interpret pipeline output.
  @cap_prop_convert_rgb 16
  # Currently unsupported.
  @cap_prop_white_balance_blue_u 17
  # Rectification flag for stereo cameras (note: only supported by DC1394 v 2.x backend currently).
  @cap_prop_rectification 18
  @cap_prop_monochrome 19
  @cap_prop_sharpness 20
  # DC1394: exposure control done by camera, user can adjust reference level using this feature.
  @cap_prop_auto_exposure 21
  @cap_prop_gamma 22
  @cap_prop_temperature 23
  @cap_prop_trigger 24
  @cap_prop_trigger_delay 25
  @cap_prop_white_balance_red_v 26
  @cap_prop_zoom 27
  @cap_prop_focus 28
  @cap_prop_guid 29
  @cap_prop_iso_speed 30
  @cap_prop_backlight 32
  @cap_prop_pan 33
  @cap_prop_tilt 34
  @cap_prop_roll 35
  @cap_prop_iris 36
  # Pop up video/camera filter dialog (note: only supported by DSHOW backend currently. The property value is ignored)
  @cap_prop_settings 37
  @cap_prop_buffersize 38
  @cap_prop_autofocus 39
  # Sample aspect ratio: num/den (num)
  @cap_prop_sar_num 40
  # Sample aspect ratio: num/den (den)
  @cap_prop_sar_den 41
  # Current backend (enum VideoCaptureAPIs). Read-only property
  @cap_prop_backend 42
  # Video input or Channel Number (only for those cameras that support)
  @cap_prop_channel 43
  # enable/ disable auto white-balance
  @cap_prop_auto_wb 44
  # white-balance color temperature
  @cap_prop_wb_temperature 45
  # (read-only) codec's pixel format. 4-character code - see VideoWriter::fourcc . Subset of [AV_PIX_FMT_*](https://github.com/FFmpeg/FFmpeg/blob/master/libavcodec/raw.c) or -1 if unknown
  @cap_prop_codec_pixel_format 46
  # (read-only) Video bitrate in kbits/s
  @cap_prop_bitrate 47
  # (read-only) Frame rotation defined by stream meta (applicable for FFmpeg and AVFoundation back-ends only)
  @cap_prop_orientation_meta 48
  # if true - rotates output frames of CvCapture considering video file's metadata  (applicable for FFmpeg and AVFoundation back-ends only) (https://github.com/opencv/opencv/issues/15499)
  @cap_prop_orientation_auto 49
  # (**open-only**) Hardware acceleration type (see #VideoAccelerationType). Setting supported only via `params` parameter in cv::VideoCapture constructor / .open() method. Default value is backend-specific.
  @cap_prop_hw_acceleration 50
  # (**open-only**) Hardware device index (select GPU if multiple available). Device enumeration is acceleration type specific.
  @cap_prop_hw_device 51
  # (**open-only**) If non-zero, create new OpenCL context and bind it to current thread. The OpenCL context created with Video Acceleration context attached it (if not attached yet) for optimized GPU data copy between HW accelerated decoder and cv::UMat.
  @cap_prop_hw_acceleration_use_opencl 52
  # (**open-only**) timeout in milliseconds for opening a video capture (applicable for FFmpeg and GStreamer back-ends only)
  @cap_prop_open_timeout_msec 53
  # (**open-only**) timeout in milliseconds for reading from a video capture (applicable for FFmpeg and GStreamer back-ends only)
  @cap_prop_read_timeout_msec 54
  # (read-only) time in microseconds since Jan 1 1970 when stream was opened. Applicable for FFmpeg backend only. Useful for RTSP and other live streams
  @cap_prop_stream_open_time_usec 55
  # (read-only) Number of video channels
  @cap_prop_video_total_channels 56
  # (**open-only**) Specify video stream, 0-based index. Use -1 to disable video stream from file or IP cameras. Default value is 0.
  @cap_prop_video_stream 57
  # (**open-only**) Specify stream in multi-language media files, -1 - disable audio processing or microphone. Default value is -1.
  @cap_prop_audio_stream 58
  # (read-only) Audio position is measured in samples. Accurate audio sample timestamp of previous grabbed fragment. See CAP_PROP_AUDIO_SAMPLES_PER_SECOND and CAP_PROP_AUDIO_SHIFT_NSEC.
  @cap_prop_audio_pos 59
  # (read only) Contains the time difference between the start of the audio stream and the video stream in nanoseconds. Positive value means that audio is started after the first video frame. Negative value means that audio is started before the first video frame.
  @cap_prop_audio_shift_nsec 60
  # (open, read) Alternative definition to bits-per-sample, but with clear handling of 32F / 32S
  @cap_prop_audio_data_depth 61
  # (open, read) determined from file/codec input. If not specified, then selected audio sample rate is 44100
  @cap_prop_audio_samples_per_second 62
  # (read-only) Index of the first audio channel for .retrieve() calls. That audio channel number continues enumeration after video channels.
  @cap_prop_audio_base_index 63
  # (read-only) Number of audio channels in the selected audio stream (mono, stereo, etc)
  @cap_prop_audio_total_channels 64
  # (read-only) Number of audio streams.
  @cap_prop_audio_total_streams 65
  # (open, read) Enables audio synchronization.
  @cap_prop_audio_synchronize 66
  # FFmpeg back-end only - Indicates whether the Last Raw Frame (LRF), output from VideoCapture::read() when VideoCapture is initialized with VideoCapture::open(CAP_FFMPEG, {CAP_PROP_FORMAT, -1}) or VideoCapture::set(CAP_PROP_FORMAT,-1) is called before the first call to VideoCapture::read(), contains encoded data for a key frame.
  @cap_prop_lrf_has_key_frame 67
  # Positive index indicates that returning extra data is supported by the video back end.  This can be retrieved as cap.retrieve(data, <returned index>).  E.g. When reading from a h264 encoded RTSP stream, the FFmpeg backend could return the SPS and/or PPS if available (if sent in reply to a DESCRIBE request), from calls to cap.retrieve(data, <returned index>).
  @cap_prop_codec_extradata_index 68
  # (read-only) FFmpeg back-end only - Frame type ascii code (73 = 'I', 80 = 'P', 66 = 'B' or 63 = '?' if unknown) of the most recently read frame.
  @cap_prop_frame_type 69
  # (**open-only**) Set the maximum number of threads to use. Use 0 to use as many threads as CPU cores (applicable for FFmpeg back-end only).
  @cap_prop_n_threads 70

  @enforce_keys [:capture]
  defstruct [:capture]

  @name __MODULE__

  def capture(save_file) when is_binary(save_file) do
    path = Path.expand(save_file)
    GenServer.cast(@name, {:capture, path})
  end

  def capture_crop(save_file, {top, left}, {bottom, right})
      when is_binary(save_file) do
    path = Path.expand(save_file)
    box = %{top: top, left: left, bottom: bottom, right: right}
    GenServer.cast(@name, {:capture_crop, path, box})
  end

  def visible(image_file, options \\ []) when is_binary(image_file) do
    timeout = Keyword.get(options, :timeout, 5000)
    path = Path.expand(image_file)
    confidence = Keyword.get(options, :confidence, 0.8)
    GenServer.call(@name, {:visble, path, confidence}, timeout)
  end

  def count(image_file, options \\ []) do
    timeout = Keyword.get(options, :timeout, 5000)
    path = Path.expand(image_file)
    confidence = Keyword.get(options, :confidence, 0.89)
    GenServer.call(@name, {:count, path, confidence}, timeout)
  end

  def count_crop(image_file, crop, options \\ []) when is_binary(image_file) and is_map(crop) do
    timeout = Keyword.get(options, :timeout, 5000)
    path = Path.expand(image_file)
    top = Map.get(crop, :top, 0.0)
    left = Map.get(crop, :left, 0.0)
    bottom = Map.get(crop, :bottom, 1.0)
    right = Map.get(crop, :right, 1.0)
    confidence = Keyword.get(options, :confidence, 0.89)
    box = %{top: top, left: left, bottom: bottom, right: right}
    GenServer.call(@name, {:count_crop, path, box, confidence}, timeout)
  end

  def wait_until_found(image_file, duration, options \\ [])
      when is_binary(image_file) and is_number(duration) do
    timeout = Keyword.get(options, :timeout, :infinity)
    path = Path.expand(image_file)
    timeout = timeout || duration + 5000
    GenServer.call(@name, {:wait_until_found, path, duration}, timeout)
  end

  def wait_until_gone(image_file, duration, options \\ [])
      when is_binary(image_file) and is_number(duration) do
    timeout = Keyword.get(options, :timeout, :infinity)
    path = Path.expand(image_file)
    timeout = timeout || duration + 5000
    GenServer.call(@name, {:wait_until_gone, path, duration}, timeout)
  end

  def pixels(coordinates, options \\ []) do
    timeout = Keyword.get(options, :timeout, 5000)

    args =
      coordinates
      |> Enum.map(fn {x, y} -> "#{x},#{y}" end)
      |> Enum.join("\t")

    GenServer.call(@name, {:pixels, args}, timeout)
  end

  ## GenServer

  def start_link(index \\ 0) do
    GenServer.start_link(__MODULE__, [index], name: @name)
  end

  def init(index) do
    capture = VideoCapture.videoCapture(index)

    if VideoCapture.isOpened(capture) do
      VideoCapture.set(capture, @cap_prop_frame_width, 640)
      VideoCapture.set(capture, @cap_prop_frame_height, 480)
      VideoCapture.set(capture, @cap_prop_fps, 30)
      VideoCapture.set(capture, @cap_prop_buffersize, 1)

      {:ok, %__MODULE__{capture: capture}}
    else
      {:stop, :already_open}
    end
  end

  def child_spec(index) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [index]}
    }
  end

  def handle_cast({:capture, path}, state = %__MODULE__{capture: c}) do
    if VideoCapture.isOpened(c) do
      VideoCapture.grab(c)
      VideoCapture.grab(c)

      case VideoCapture.retrieve(c) do
        img = %Mat{} ->
          Evision.imwrite(path, img)

        {:error, reason} ->
          Logger.error("Failed to capture image: #{inspect(reason)}")

        false ->
          Logger.error("Failed to capture image: no frame")
      end
    end

    {:noreply, state}
  end

  def handle_cast({:capture_crop, _path, _box}, _from, state) do
    {:noreply, state}
  end

  def handle_call({:visble, _path, _confidence}, _from, state) do
    {:noreply, state}
  end

  def handle_call({:count, _path, _confidence}, _from, state) do
    {:noreply, state}
  end

  def handle_call({:count_crop, _path, _box, _confidence}, _from, state) do
    {:noreply, state}
  end

  def handle_call({:wait_until_found, _path, _duration}, _from, state) do
    {:noreply, state}
  end

  def handle_call({:wait_until_gone, _path, _duration}, _from, state) do
    {:noreply, state}
  end

  def handle_call({:pixels, _args}, _from, state) do
    {:noreply, state}
  end

  def handle_info({_port, {:exit_status, 0}}, state) do
    _ = Logger.debug("Vision exited normally")
    {:stop, :normal, state}
  end

  def handle_info({_port, {:exit_status, code}}, state) do
    _ = Logger.error("Vision exited: #{code}")
    {:stop, code, state}
  end

  def terminate(reason, state) do
    _ = Logger.warn("Vision terminating because #{inspect(reason)}")
    Port.close(state.port)
  end
end
